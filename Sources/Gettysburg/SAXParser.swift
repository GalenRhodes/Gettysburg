/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: SAXParser.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 1/14/21
 *
 * Copyright © 2021 Galen Rhodes. All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *//************************************************************************/

import Foundation
import CoreFoundation
import Rubicon
#if os(Windows)
    import WinSDK
#endif

/*===============================================================================================================================================================================*/
/// An implementation of a SAX parser.
///
open class SAXParser<H: SAXHandler> {

    @usableFromInline typealias XMLDecl = (version: String, versionSpecified: Bool, encoding: String, encodingSpecified: Bool, endianBom: Endian, standalone: Bool, standaloneSpecified: Bool)

    public internal(set) var url:          String
    public internal(set) var handler:      H?      = nil
    public internal(set) var xmlVersion:   String? = nil
    public internal(set) var xmlEncoding:  String? = nil
    public internal(set) var isStandalone: Bool?   = nil

    @inlinable final public var lineNumber:   Int { charStream.lineNumber }
    @inlinable final public var columnNumber: Int { charStream.columnNumber }

    public var allowedURIPrefixes: [String] = []
    public var willValidate:       Bool     = false

    @usableFromInline let inputStream:       MarkInputStream
    @usableFromInline var charStream:        CharInputStream!      = nil
    @usableFromInline var lock:              RecursiveLock         = RecursiveLock()
    @usableFromInline var foundRootElement:  Bool                  = false
    @usableFromInline var foundDTD:          Bool                  = false
    @usableFromInline var namespaceMappings: [NamespaceURIMapping] = []

    /*===========================================================================================================================================================================*/
    /// Create an instance of this parser from the given input stream.
    /// 
    /// - Parameters:
    ///   - inputStream: the <code>[InputStream](https://developer.apple.com/documentation/foundation/InputStream)</code>
    ///   - url: the URL where this document is located. If none is provided then a generic one will be generated.
    ///   - handler: an instance of a class that implements the `SAXHandler` protocol that will handle the messages sent from this parser.
    ///
    public init(inputStream: InputStream, url: String = "uuid:\(UUID().uuidString).xml", handler: H? = nil) {
        self.handler = handler
        self.inputStream = MarkInputStream(inputStream: inputStream)
        self.url = url
    }

    /*===========================================================================================================================================================================*/
    /// Set the instance of the class that implements `SAXHandler` that will handle the parsing messages sent from this parser.
    /// 
    /// - Parameter handler: the handler.
    /// - Returns: this parser.
    /// - Throws: if the handler had already been set previously.
    ///
    @discardableResult public final func set(handler: H) throws -> SAXParser<H> {
        guard self.handler == nil else { throw getSAXError_HandlerAlreadySet() }
        self.handler = handler
        return self
    }

    /*===========================================================================================================================================================================*/
    /// Set the willValidate flag.
    /// 
    /// - Parameter flag: if `true` this parser will perform validation based on the DTD provided in the document. If `false` no validation will be performed.
    /// - Returns: this parser.
    ///
    @discardableResult open func set(willValidate flag: Bool) -> SAXParser<H> {
        willValidate = flag
        return self
    }

    /*===========================================================================================================================================================================*/
    /// Set the list of allowed URI prefixes for resolving external entities and DocTypes.
    /// 
    /// - Parameters:
    ///   - uris: the list of URI prefixes.
    ///   - append: if `true` the list will be added to any already set. If `false` (the default) the list provided here will completely replace what is already there.
    /// - Returns: this parser.
    ///
    @discardableResult open func set(allowedUriPrefixes uris: [String], append: Bool = false) -> SAXParser<H> {
        if append { allowedURIPrefixes.append(contentsOf: uris) }
        else { allowedURIPrefixes = uris }
        return self
    }

    /*===========================================================================================================================================================================*/
    /// Parse the XML document.
    /// 
    /// - Returns: The handler used to parse the document.
    /// - Throws: if an I/O error occurs or if the XML document is malformed.
    ///
    @discardableResult open func parse() throws -> H {
        try lock.withLock { () -> H in
            guard let handler = handler else { throw getSAXError_MissingHandler() }

            do {
                var xmlDecl: XMLDecl = ("1.0", false, "UTF-8", false, .None, true, false)

                if inputStream.streamStatus == .notOpen { inputStream.open() }

                //------------------------------------------------
                // Try to determine the encoding of the XML file.
                //------------------------------------------------
                charStream = try setupXMLFileEncoding(xmlDecl: &xmlDecl)
                defer { charStream.close() }
                // FIXME: If the char stream didn't change then we still have a mark on it at this point.
                xmlVersion = xmlDecl.version
                xmlEncoding = xmlDecl.encoding
                isStandalone = xmlDecl.standalone

                handler.documentBegin(parser: self,
                                      version: (xmlDecl.versionSpecified ? xmlDecl.version : nil),
                                      encoding: (xmlDecl.encodingSpecified ? xmlDecl.encoding : nil),
                                      standAlone: (xmlDecl.standaloneSpecified ? xmlDecl.standalone : nil))
                try parseDocumentRoot(handler)
                handler.documentEnd(parser: self)
            }
            catch let e {
                handler.parseErrorOccurred(parser: self, error: e)
                throw e
            }

            return handler
        }
    }

    /*===========================================================================================================================================================================*/
    /// Parse out the main body of the XML Document that includes the root element and DOCTYPES as well as any processing instructions, whitespace, and comments that might exist
    /// at the root level.
    /// 
    /// - Throws: `SAXError` or any I/O errors.
    ///
    func parseDocumentRoot(_ handler: H) throws {
        markSet()
        defer { markDelete() }

        while let ch = try charStream.read() {
            if ch == "<" {
                try parseDelimitedNode(handler, noDTD: (foundDTD || foundRootElement), noElement: foundRootElement)
            }
            else if ch.isXmlWhitespace {
                try parseWhitespaceNode(handler)
            }
            else {
                markReset()
                throw getSAXError_InvalidCharacter("Character \"\(ch)\" not expected here.")
            }

            markUpdate()
        }
    }

    /*===========================================================================================================================================================================*/
    /// Parse a delimited node such as an element, comment, processing instruction, or DTD.
    /// 
    /// - Parameters:
    ///   - handler: the handler.
    ///   - noDTD: if set to `true` then DTD nodes are not allowed. DTD nodes are only allowed before the root element is encountered.
    ///   - noElement: if set to `true` then no element nodes are allowed. This might be the case at the document root where only one root element is allowed.
    /// - Throws: if an I/O error occurs, if the node is malformed, or if a DTD was encountered when `noDTD` was set to `true`.
    ///
    func parseDelimitedNode(_ handler: H, noDTD: Bool = true, noElement: Bool = false) throws {
        let ch = try readChar()
        switch ch {
            case "!": try parseDocTypeOrComment(handler, noDTD: noDTD)
            case "?": try parseProcessingInstruction(handler)
            default:
                //------------------------------------------------------
                // It should be an element then in which case the first
                // character should be a valid starting character.
                //------------------------------------------------------
                markBackup()
                guard ch.isXmlNameStartChar else { throw getSAXError_InvalidCharacter("Invalid element name starting character: \"\(ch)\"") }
                guard !noElement else { throw getSAXError_UnexpectedElement("An element is not expected here.") }
                try parseElement(handler)
        }
    }

    /*===========================================================================================================================================================================*/
    /// Parse and handle an element.
    /// 
    /// - Parameters:
    ///   - handler: the SAXHandler
    ///   - firstChar: the first <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> of the element name.
    /// - Throws: if there is an I/O error or the element is malformed.
    ///
    final func parseElement(_ handler: H) throws {
        let name              = try readXmlName()
        let (isClosed, attrs) = try readElementInfo()

        if !isClosed {
            // TODO: Parse Element...
        }
    }

    /*===========================================================================================================================================================================*/
    /// Parse the element opening tag.
    /// 
    /// - Returns: a tuple containing the boolean indicating if this is an open or close element and any attributes contained in the element tag.
    /// - Throws: if there is an I/O error or the element is malformed.
    ///
    final func readElementInfo() throws -> (Bool, [SAXParsedAttribute]) {
        var rawAttrs: [String: String] = [:]

        while let ch = try charStream.read() {
            if ch == "/" {
                try readCharAnd(expected: ">")
                return (true, try processAttributes(attributes: rawAttrs))
            }
            else if ch == ">" {
                return (false, try processAttributes(attributes: rawAttrs))
            }
            else if ch.isXmlNameStartChar {
                markBackup()
                let attr = try readAttribute()
            }
            else if !ch.isXmlWhitespace {
                throw getSAXError_InvalidCharacter("Character not allowed here: \"\(ch)\"")
            }
        }

        throw getSAXError_UnexpectedEndOfInput()
    }

    /*===========================================================================================================================================================================*/
    /// Process the elements attributes.
    /// 
    /// - Parameter rawAttrs: the raw attribute data.
    /// - Returns: an <code>[Array](https://developer.apple.com/documentation/swift/Array)</code> of `SAXParsedAttribute`.
    /// - Throws: if an I/O error occurs or if the attributes are malformed.
    ///
    final func processAttributes(attributes rawAttrs: [String: String]) throws -> [SAXParsedAttribute] {
        func foo01(_ ns: (prefix: String?, localName: String), _ uri: String, _ value: String, _ attrs: inout [SAXParsedAttribute]) {
            namespaceMappings <+ NamespaceURIMapping(namespaceURI: value)
            attrs <+ SAXParsedAttribute(localName: ns.localName, prefix: ns.prefix, namespaceURI: uri, defaulted: false, value: value)
        }

        var attrs: [SAXParsedAttribute] = []

        //-----------------------------------------
        // First process and namespace attributes.
        //-----------------------------------------
        for (name, value) in rawAttrs {
            let ns = name.getXmlPrefixAndLocalName()
            let f  = (ns.prefix == "xmlns")

            if f || ns.prefix == "xml" {
                if ns.localName.isEmpty { throw getSAXError_NamespaceError("Missing namespace prefix definition.") }
                foo01(ns, (f ? "http://www.w3.org/2000/xmlns/" : "http://www.w3.org/XML/1998/namespace"), value, &attrs)
            }
            else if ns.prefix == nil && ns.localName == "xmlns" {
                foo01(ns, "http://www.w3.org/2000/xmlns/", value, &attrs)
            }
        }

        //----------------------------------------
        // Then process the remaining attributes.
        //----------------------------------------
        for (name, value) in rawAttrs {
            let ns = name.getXmlPrefixAndLocalName()
            let f  = !(ns.prefix == "xml" || ns.prefix == "xmlns" || (ns.prefix == nil && ns.localName == "xmlns"))

            if f {
                let uri = (getNamespaceURI(prefix: (ns.prefix == nil) ? "" : ns.prefix!) ?? getNamespaceURI(prefix: ""))
                if uri == nil && ns.prefix != nil { throw getSAXError_NamespaceError("Missing namespace URI for prefix: \"\(ns.prefix ?? "")\"") }
                attrs <+ SAXParsedAttribute(localName: ns.localName, prefix: ns.prefix, namespaceURI: uri, defaulted: false, value: value)
            }
        }

        // TODO: Look for duplicate attribute names and throw an error.
        return attrs
    }

    /*===========================================================================================================================================================================*/
    /// Reach and attribute from the element tag body.
    /// 
    /// - Returns: instance of `NSAttribInfo` that contains the attribute information.
    /// - Throws: if an error occurs.
    ///
    final func readAttribute() throws -> NSAttribInfo {
        markSet()
        defer { markDelete() }

        let line        = charStream.lineNumber
        let column      = charStream.columnNumber
        let qName       = try readXmlName()
        let attrName    = qName.getXmlPrefixAndLocalName()
        let lcLocalName = attrName.localName.lowercased()
        let lcPrefix    = attrName.prefix?.lowercased()
        let noPrefix    = (lcPrefix == nil)

        try readCharAnd(expected: "=")
        if !noPrefix && lcLocalName.isEmpty { markReset(); throw getSAXError_NamespaceError("Local name is missing: \"\(qName)\"") }
        if !(noPrefix && lcLocalName == "xmlns") {
            if lcLocalName.hasPrefix("xml") { markReset(); throw getSAXError_NamespaceError("Invalid local name: \"\(qName)\"") }
        }

        markUpdate()
        try readCharAnd(expected: "\"")
        let attrValue = try readAttributeValue()
        let noValue   = attrValue.trimmed.isEmpty

        if ((noPrefix && lcLocalName == "xmlns") || lcPrefix == "xmlns" || lcPrefix == "xml") && noValue { markReset(); throw getSAXError_NamespaceError("Missing namespace URI.") }

        return NSAttribInfo(line: line, column: column, prefix: attrName.prefix, localName: attrName.localName, value: attrValue)
    }

    /*===========================================================================================================================================================================*/
    /// Reads the attributes value from the <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> input stream.
    /// 
    /// - Returns: the attributes value.
    /// - Throws: if an I/O error occurs or if there are illegal <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s in the value.
    ///
    final func readAttributeValue() throws -> String {
        var chars: [Character] = []
        while let ch = try charStream.read() {
            switch ch {
                case "\"": return String(chars)
                case "<":  markBackup(); throw getSAXError_InvalidCharacter("Character not allowed here: \"\(ch)\"")
                case "&":  chars.append(contentsOf: try readEntityReference())
                default:   chars <+ ch
            }
        }
        throw getSAXError_UnexpectedEndOfInput()
    }

    /*===========================================================================================================================================================================*/
    /// Read the entity reference and resolve it.
    /// 
    /// - Returns: the resolved entity reference.
    /// - Throws: if the entity reference is malformed or there is an error during resolution.
    ///
    final func readEntityReference() throws -> String {
        let ch = try readChar()
        return try ((ch == "#") ? String(readCharacterEntityReference()) : readStandardEntityReference(ch))
    }

    /*===========================================================================================================================================================================*/
    /// Read the <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> entity reference.
    /// 
    /// - Returns: the resolved <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> entity reference.
    /// - Throws: if the <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> entity reference is malformed.
    ///
    final func readCharacterEntityReference() throws -> Character {
        var ch  = try readChar()
        let hex = (ch == "x")
        if hex { ch = try readChar() }
        return try readCharacterEntityReference_Dec(ch, hex: hex)
    }

    /*===========================================================================================================================================================================*/
    /// Read the scalar value for the <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> entity reference.
    /// 
    /// - Parameters:
    ///   - ch: the first <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> of the scalar.
    ///   - hex: `true` if the scalar is in hexadecimal format or `false` if it is in decimal format.
    /// - Returns: the resolved <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>.
    /// - Throws: if the scalar is malformed.
    ///
    final func readCharacterEntityReference_Dec(_ ch: Character, hex: Bool) throws -> Character {
        var chars: [Character] = []
        var ch:    Character   = ch

        markSet()
        defer { markDelete() }

        repeat {
            if ch == ";" {
                let str = String(chars)
                if let i = UInt32(str, radix: hex ? 16 : 10) { return Character(scalar: UnicodeScalar(i)) }
                markReset()
                throw getSAXError_MalformedNumber("The \(hex ? "hexadecimal" : "decimal") number \"\(str)\" is too large.")
            }
            else if !(hex ? ch.isXmlHex : ((ch >= "0") && (ch <= "9"))) {
                markBackup()
                throw getSAXError_InvalidCharacter("Character not allowed here: \"\(ch)\"")
            }
            chars <+ ch
            ch = try readChar()
        }
        while true
    }

    /*===========================================================================================================================================================================*/
    /// Read and resolved a standard entity reference.
    /// 
    /// - Parameter ch: the firt <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> of the entity name.
    /// - Returns: the resolved, parsed entity.
    /// - Throws: if an I/O error occurs or the entity name is malformed or there is an error resolving the entity.
    ///
    final func readStandardEntityReference(_ ch: Character) throws -> String {
        if ch.isXmlNameStartChar {
            let entity = try readStandardEntityReference_Loop(ch)
            switch entity {
                case "amp":  return "&"
                case "lt":   return "<"
                case "gt":   return ">"
                case "quot": return "\""
                default:     return try resolveEntityReference(entityName: entity)
            }
        }
        else {
            throw getSAXError_InvalidCharacter("Character not allowed here: \"\(ch)\"")
        }
    }

    /*===========================================================================================================================================================================*/
    /// Read the entity name from the <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> input stream.
    /// 
    /// - Parameter ch: the first <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> of the entity name.
    /// - Returns: the full entity name.
    /// - Throws: if an I/O error occurs, the EOF is encountered before the end of the entity name marker (;), or an illegal
    ///           <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> is encountered.
    ///
    final func readStandardEntityReference_Loop(_ ch: Character) throws -> String {
        var chars: [Character] = [ ch ]
        while let ch = try charStream.read() {
            if ch == ";" { return String(chars) }
            if !ch.isXmlNameChar { markBackup(); throw getSAXError_InvalidCharacter("Character not allowed here: \"\(ch)\"") }
            chars <+ ch
        }
        throw getSAXError_UnexpectedEndOfInput()
    }

    /*===========================================================================================================================================================================*/
    /// TODO: Resolve Entity Reference...
    /// 
    /// - Parameter ent: the entity name.
    /// - Returns: the text of the entity.
    /// - Throws: if an error occurs.
    ///
    final func resolveEntityReference(entityName ent: String) throws -> String {
        "&\(ent);"
    }

    /*===========================================================================================================================================================================*/
    /// Attempt to resolve the namespace URI given the qualified name for an element or attribute.
    /// 
    /// - Parameter name: the fully qualified name.
    /// - Returns: a tuple with the local name, prefix, and namespace URI. The namespace URI may be `nil` if it can't be resolved. The prefix may be `nil` if there isn't one.
    ///
    @inlinable final func getNamespaceInfo(qualifiedName name: String) -> (localName: String, prefix: String?, namespaceURI: String?) {
        let (prefix, localName) = name.getXmlPrefixAndLocalName()
        if prefix == "xml" {
            return (localName, "xml", "http://www.w3.org/XML/1998/namespace")
        }
        else if prefix == "xmlns" || (prefix == nil && localName == "xmlns") {
            return (localName, prefix, "http://www.w3.org/2000/xmlns/")
        }
        else if let pfx = prefix {
            if let uri = getNamespaceURI(prefix: pfx) {
                return (localName, pfx, uri)
            }
        }
        else if let uri = getNamespaceURI(prefix: "") {
            return (localName, nil, uri)
        }
        return (name, nil, nil)
    }

    /*===========================================================================================================================================================================*/
    /// Attempt to resolve the namespace URI given the prefix.
    /// 
    /// - Parameter prefix: the prefix.
    /// - Returns: the namespace URI or `nil` if it can't be found.
    ///
    @inlinable final func getNamespaceURI(prefix: String) -> String? {
        var idx = namespaceMappings.endIndex
        let stx = namespaceMappings.startIndex

        while idx > stx {
            idx = namespaceMappings.index(before: idx)
            let ns = namespaceMappings[idx]
            if prefix == ns.prefix { return ns.namespaceURI }
        }

        return nil
    }

    /*===========================================================================================================================================================================*/
    /// Parse the body of the element. That would be everything between "<tagname>" and "</tagname>".
    /// 
    /// - Parameters:
    ///   - handler: the SAX Handler.
    ///   - elementName: the name of the element.
    ///   - attributes: the attributes of the element.
    /// - Throws: if an I/O error occurs, the EOF is encountered, or something in the body is malformed.
    ///
    final func parseElementBody(_ handler: H, elementName: String, attributes: [SAXParsedAttribute]) throws {
        // TODO: Parse Element Body...
    }

    /*===========================================================================================================================================================================*/
    /// Parse a DocType or Comment.
    /// 
    /// - Parameters:
    ///   - handler: The SAX Handler.
    ///   - noDTD: `true` if the DTD has already been parsed or is not allowed at this point.
    /// - Throws: if an I/O error occurs or there is an invalid <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>.
    ///
    func parseDocTypeOrComment(_ handler: H, noDTD: Bool) throws {
        markSet()
        //
        // Read the next 8 characters and see what we have here.
        //
        let str = try readString(count: 8)

        if str.hasPrefix("DOCTYPE") {
            let lastChar = str[str.index(before: str.endIndex)]

            guard lastChar.isXmlWhitespace else {
                markBackup()
                markDelete()
                throw getSAXError_InvalidCharacter("Unexpected character: \"\(lastChar)")
            }
            guard !noDTD else {
                markReturn()
                markReset()
                throw getSAXError_UnexpectedElement("A DOCTYPE declaration is not expected here.")
            }
            markDelete()
            //
            // This is a doctype node.
            //
            try parseDocType(handler)
        }
        else if str.hasPrefix("--") {
            markBackup(count: 6)
            markDelete()
            //
            // This is a comment node.
            //
            try parseComment(handler)
        }
        else {
            markReturn()
            throw getSAXError_InvalidCharacter("Unexpected characters \"\(str)\".")
        }
    }

    /*===========================================================================================================================================================================*/
    /// Read and parse the processing instruction.
    /// 
    /// - Parameter handler: the handler.
    /// - Throws: if an I/O error occurs or if the EOF was encountered before the end of the processing instruction node.
    ///
    @inlinable final func parseProcessingInstruction(_ handler: H) throws {
        let (target, data) = getPITargetAndData(processingInstruction: try readUntil(marker: "?", ">"))
        handler.processingInstruction(parser: self, target: target, data: data)
    }

    /*===========================================================================================================================================================================*/
    /// Take the string that contains the body of the processing instruction and break out the target and the data.
    /// 
    /// - Parameter pi: the body of the processing instruction.
    /// - Returns: a tuple with the target and the data.
    ///
    @inlinable final func getPITargetAndData(processingInstruction pi: String) -> (String, String) {
        var sIdx = pi.startIndex
        let eIdx = pi.index(pi.endIndex, offsetBy: -2)

        while sIdx < eIdx {
            if pi[sIdx].isXmlWhitespace {
                let target = String(pi[pi.startIndex ..< sIdx]).trimmed
                sIdx = pi.index(after: sIdx)
                while sIdx < eIdx {
                    if !pi[sIdx].isXmlWhitespace { return (target, String(pi[sIdx ..< eIdx]).trimmed) }
                    sIdx = pi.index(after: sIdx)
                }
                return (target, "")
            }
            sIdx = pi.index(after: sIdx)
        }
        return (pi.trimmed, "")
    }

    /*===========================================================================================================================================================================*/
    /// Parse out a text node combrised of nothing but whitespace.
    /// 
    /// - Parameter handler: the handler.
    /// - Throws: if an I/O error occurs.
    ///
    func parseWhitespaceNode(_ handler: H) throws {
        handler.text(parser: self, content: try readWhitespace(), isWhitespace: true)
    }

    /*===========================================================================================================================================================================*/
    /// Parse an encountered comment.
    /// 
    /// - Parameter handler: the handler.
    /// - Throws: if an I/O error occurs or the comment is malformed.
    ///
    func parseComment(_ handler: H) throws {
        let c = try doRead { ch, cm in
            guard cmpSuffix(suffix: [ "-", "-" ], source: cm) else { return ret(false) { cm <+ ch } }
            guard ch == ">" else { throw getSAXError_InvalidCharacter("Expected \">\" but found \"\(ch)\" instead.") }
            return ret(true) { cm.removeLast(2) }
        }
        handler.comment(parser: self, comment: c)
    }

    /*===========================================================================================================================================================================*/
    /// Parse out a DOCTYPE Declaration.
    /// 
    /// - Parameter handler: The handler.
    /// - Throws: if an I/O error occurs or if the DOCTYPE declaration is malformed or incomplete.
    ///
    func parseDocType(_ handler: H) throws {
        // TODO: Parse Doc Type...
    }

    /*===========================================================================================================================================================================*/
    /// Read and return all the <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> up to but not including the first encountered NON-whitespace
    /// <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>.
    /// 
    /// - Parameter noEOF: if `true` then an error is thrown if the EOF is encountered before the first non-whitespace
    ///                    <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> is found. The default is `false`.
    /// - Returns: the <code>[String](https://developer.apple.com/documentation/swift/String)</code> of
    ///            <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s read.
    /// - Throws: if an I/O error occurs or `noEOF` is `true` and the EOF is encountered before the first non-whitespace
    ///           <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> is found.
    ///
    @discardableResult @usableFromInline final func readWhitespace(noEOF: Bool = false) throws -> String {
        var buffer: [Character] = []
        markSet()
        defer { markDelete() }
        while let ch = try charStream.read() {
            if !ch.isXmlWhitespace {
                markBackup()
                return String(buffer)
            }
            buffer <+ ch
        }
        if noEOF { throw getSAXError_UnexpectedEndOfInput() }
        return String(buffer)
    }

    /*===========================================================================================================================================================================*/
    /// Read `count` number of <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s from the [input
    /// stream](http://goober/Rubicon/Protocols/CharInputStream.html) and return them as a string.
    /// 
    /// - Parameter count: the number of <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s to read.
    /// - Returns: the number of <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s read.
    /// - Throws: if there is an I/O error or if there are fewer than `count` <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s left in the
    ///           input stream.
    ///
    @inlinable final func readString(count: Int) throws -> String { ((count > 0) ? try doReadUntil(predicate: { _, cc in (cc < (count - 1)) }) : "") }

    /*===========================================================================================================================================================================*/
    /// Read and return all the <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s up to but not including the first encountered whitespace
    /// <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>.
    /// 
    /// - Returns: The <code>[String](https://developer.apple.com/documentation/swift/String)</code> of
    ///            <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s read.
    /// - Throws: if an I/O error occurs.
    ///
    @usableFromInline final func readUntilWhitespace() throws -> String { try doReadUntil(backup: true) { ch, _ in ch.isXmlWhitespace } }

    /*===========================================================================================================================================================================*/
    /// Read until the given set of <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s is found.
    /// 
    /// - Parameters:
    ///   - marker: the sequence of <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s that will trigger the end of the read.
    ///   - dropMarker: if `true` the marker will not be included in the returned <code>[String](https://developer.apple.com/documentation/swift/String)</code>.
    ///   - leaveFPatMarker: if `true` the file pointer will be left at the first <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> of the
    ///                      located marker.
    /// - Returns: The <code>[String](https://developer.apple.com/documentation/swift/String)</code> of
    ///            <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s read from the input.
    /// - Throws: if an I/O error occurs or the EOF is reached before the marker is located.
    ///
    @usableFromInline final func readUntil(marker mrk: Character...) throws -> String { try doReadUntil { buf in cmpSuffix(suffix: mrk, source: buf) } }

    /*===========================================================================================================================================================================*/
    /// Read <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s from the [input stream](http://goober/Rubicon/Protocols/CharInputStream.html) and
    /// make sure they match the given <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s in the order they're given.
    /// 
    /// - Parameter chars: the list of expected <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s.
    /// - Returns: the string from the <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s.
    /// - Throws: if an I/O error occurs, the EOF is encountered, or the read <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s don't match the
    ///           <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s in the list.
    ///
    @discardableResult @inlinable final func readCharAnd(expected chars: Character...) throws -> String {
        guard !chars.isEmpty else { fatalError() }
        var chars: [Character] = []
        markSet()
        defer { markDelete() }
        for ch1 in chars {
            let ch2 = try readChar()
            guard ch1 == ch2 else {
                markBackup()
                throw getSAXError_InvalidCharacter("Expected \"\(ch1)\" but found \"\(ch2)\" instead.")
            }
            chars <+ ch2
        }
        return String(chars)
    }

    /*===========================================================================================================================================================================*/
    /// Read the next <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> from the [input
    /// stream](http://goober/Rubicon/Protocols/CharInputStream.html) and make sure it matches the any of the expected
    /// <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s.
    /// 
    /// - Parameter chars: the list of expected <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s.
    /// - Returns: the <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> read.
    /// - Throws: if an I/O error occurs, the EOF is encountered, or the read <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> is not any of the
    ///           expected <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s.
    ///
    @discardableResult @inlinable final func readCharOr(expected chars: Character...) throws -> Character {
        guard !chars.isEmpty else { fatalError() }
        markSet()
        defer { markDelete() }
        let ch = try readChar()
        if chars.isAny(predicate: { $0 == ch }) { return ch }
        if chars.count == 1 { throw getSAXError_InvalidCharacter("Expected \"\(chars.first!)\" but found \"\(ch)\" instead.") }
        var str: String = ""
        for c in chars { str += String(c) }
        throw getSAXError_InvalidCharacter("Expected one of \"\(str)\" but found \"\(ch)\" instead.")
    }

    /*===========================================================================================================================================================================*/
    /// Read a single <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> from the input stream.
    /// 
    /// - Returns: the <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> read.
    /// - Throws: if an I/O error occurs or the EOF is encountered.
    ///
    @inlinable final func readChar() throws -> Character { guard let ch = try charStream.read() else { throw getSAXError_UnexpectedEndOfInput() }; return ch }

    /*===========================================================================================================================================================================*/
    /// Read an [XML name](https://www.w3.org/TR/REC-xml/#sec-common-syn) from the input stream.
    /// 
    /// - Returns: the XML name.
    /// - Throws: if an I/O error occurs.
    ///
    @inlinable final func readXmlName() throws -> String { try doReadUntil(backup: true) { ch, cc in !((cc == 0) ? ch.isXmlNameStartChar : ch.isXmlNameChar) } }

    /*===========================================================================================================================================================================*/
    /// Read an [XML NMTOKEN](https://www.w3.org/TR/REC-xml/#sec-common-syn) from the input stream.
    /// 
    /// - Returns: the XML name.
    /// - Throws: if an I/O error occurs.
    ///
    @inlinable final func readXmlNmtoken() throws -> String { try doReadUntil(backup: true) { ch, _ in !ch.isXmlNameChar } }

    /*===========================================================================================================================================================================*/
    /// Read from the [character input stream](http://goober/Rubicon/Protocols/CharInputStream.html) until the given
    /// <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> is found.
    /// 
    /// - Parameter ch: the given <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>.
    /// - Returns: the string of <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s up to, but not including, the given
    ///            <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>.
    /// - Throws: if an I/O error occurs or the EOF is encountered before the <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> is found.
    ///
    @inlinable final func readUntil(character ch: Character) throws -> String { try doReadUntil(backup: true) { c0, _ in ch == c0 } }

    /*===========================================================================================================================================================================*/
    /// Read <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s from the [input stream](http://goober/Rubicon/Protocols/CharInputStream.html)
    /// until the closure returns `true`. The closure is called for each <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> read. When the closure
    /// returns `true` then reading will stop and a string containing the <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s read is returned.
    /// 
    /// - Parameters:
    ///   - backup: if `true` then the last `count` <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s are returned to the [input
    ///             stream](http://goober/Rubicon/Protocols/CharInputStream.html) to be read again.
    ///   - cc: the number of <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s to return to the input stream.
    ///   - body: a closure that receives the last <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> read and the total number of
    ///           <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s read so far. When the closure returns `true` reading will stop.
    /// - Returns: the string of <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s read.
    /// - Throws: if an I/O error occurs or any error thrown by the closure.
    ///
    @inlinable final func doReadUntil(backup: Bool = false, count cc: Int = 1, predicate body: (Character, Int) throws -> Bool) throws -> String {
        try doRead { ch, buffer in
            if try body(ch, buffer.count) {
                if backup { markBackup(count: cc) }
                return true
            }
            buffer <+ ch
            return false
        }
    }

    /*===========================================================================================================================================================================*/
    /// Read <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s from the [input stream](http://goober/Rubicon/Protocols/CharInputStream.html)
    /// until the closure returns `true`. The closure is called for each <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> read. When the closure
    /// returns `true` then reading will stop and a string containing the <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s read is returned.
    /// 
    /// - Parameters:
    ///   - backup: if `true` then the last `count` <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s are returned to the [input
    ///             stream](http://goober/Rubicon/Protocols/CharInputStream.html) to be read again.
    ///   - cc: the number of <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s to return to the input stream.
    ///   - body: a closure that receives the all the <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s read so far. When the closure returns
    ///           `true` reading will stop.
    /// - Returns: the string of <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s read.
    /// - Throws: if an I/O error occurs or any error thrown by the closure.
    ///
    @inlinable final func doReadUntil(backup: Bool = false, count cc: Int = 1, predicate body: ([Character]) throws -> Bool) throws -> String {
        try doRead { ch, buffer in
            buffer <+ ch
            guard try body(buffer) else { return false }
            if backup {
                markBackup(count: cc)
                buffer.removeLast(cc)
            }
            return true
        }
    }

    /*===========================================================================================================================================================================*/
    /// Read <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s from the [character input
    /// stream](http://goober/Rubicon/Protocols/CharInputStream.html) and pass them to the closure along with a
    /// <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> <code>[Array](https://developer.apple.com/documentation/swift/Array)</code>. When the
    /// closure returns `true` then the <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>
    /// <code>[Array](https://developer.apple.com/documentation/swift/Array)</code> will be wrapped in a string and returned.
    /// 
    /// - Parameter body: the closure.
    /// - Returns: a new string made from the contents of the <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>
    ///            <code>[Array](https://developer.apple.com/documentation/swift/Array)</code> passed to the closure.
    /// - Throws: any error thrown by the closure or if an I/O error occurs or the EOF is encountered.
    ///
    @inlinable final func doRead(_ body: (Character, inout [Character]) throws -> Bool) throws -> String { try doRead(charInputStream: charStream, body) }

    /*===========================================================================================================================================================================*/
    /// Read <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s from the [character input
    /// stream](http://goober/Rubicon/Protocols/CharInputStream.html) and pass them to the closure along with a
    /// <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> <code>[Array](https://developer.apple.com/documentation/swift/Array)</code>. When the
    /// closure returns `true` then the <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>
    /// <code>[Array](https://developer.apple.com/documentation/swift/Array)</code> will be wrapped in a string and returned.
    /// 
    /// - Parameters:
    ///   - cString: the [character input stream](http://goober/Rubicon/Protocols/CharInputStream.html) to read from.
    ///   - body: the closure.
    /// - Returns: a new string made from the contents of the <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>
    ///            <code>[Array](https://developer.apple.com/documentation/swift/Array)</code> passed to the closure.
    /// - Throws: any error thrown by the closure or if an I/O error occurs or the EOF is encountered.
    ///
    @inlinable final func doRead(charInputStream cStream: CharInputStream, _ body: (Character, inout [Character]) throws -> Bool) throws -> String {
        do {
            var chars: [Character] = []

            cStream.markSet()
            defer { cStream.markDelete() }

            while let ch = try cStream.read() {
                if try body(ch, &chars) {
                    return String(chars)
                }
            }
        }
        catch let e {
            cStream.markBackup()
            throw e
        }

        throw getSAXError_UnexpectedEndOfInput()
    }

    /*===========================================================================================================================================================================*/
    /// 99.99999% of the time the <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> encoding is going to be UTF-8 - which is the default. But the
    /// XML specification allows for other <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> encodings as well so we have to try to detect what
    /// kind it really is.
    /// 
    /// - Parameter xmlDecl:
    /// - Returns:
    /// - Throws:
    ///
    @usableFromInline final func setupXMLFileEncoding(xmlDecl: inout XMLDecl) throws -> CharInputStream {
        (xmlDecl.encoding, xmlDecl.endianBom) = try detectFileEncoding()
        #if DEBUG
            print("Charset Encoding: \(xmlDecl.encoding); Endian BOM: \(xmlDecl.endianBom)")
        #endif
        //--------------------------------------------------------------------------------
        // So now we will see if there
        // is an XML Declaration telling us that it's something different.
        //--------------------------------------------------------------------------------
        inputStream.markSet()

        var chars:       [Character]          = []
        let tCharStream: IConvCharInputStream = IConvCharInputStream(inputStream: inputStream, autoClose: false, encodingName: xmlDecl.encoding)

        tCharStream.open()
        tCharStream.markSet()

        //-------------------------------------------------------------------------------------------------------
        // If we have an XML Declaration, parse it and see if it says something different than what we detected.
        //-------------------------------------------------------------------------------------------------------
        _ = try tCharStream.read(chars: &chars, maxLength: 5)
        if String(chars) == "<?xml" {
            return try parseXMLDeclaration(try getXMLDecl(tCharStream), chStream: tCharStream, xmlDecl: &xmlDecl)
        }
        //-----------------------------------------------------------------------------------
        // Otherwise there is no XML Declaration so we stick with what we have and continue.
        //-----------------------------------------------------------------------------------
        inputStream.markDelete()
        tCharStream.markReturn()
        return tCharStream
    }

    /*===========================================================================================================================================================================*/
    /// Parse the [XML Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml) read from the document.
    /// 
    /// - Parameters:
    ///   - declString: the [XML Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml) read from the document.
    ///   - chStream: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    ///   - xmlDecl: the current [XML Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml) values.
    /// - Returns: either the current <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code> or a new one if it was determined that
    ///            it needed to change <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> encoding.
    /// - Throws: if an error occurred or if there was a problem with the [XML Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml).
    ///
    @usableFromInline final func parseXMLDeclaration(_ declString: String, chStream: CharInputStream, xmlDecl: inout XMLDecl) throws -> CharInputStream {
        //--------------------------------------------------------------------------------------------------
        // Now, normally the fields "version", "encoding", and "standalone" have to be in that exact order.
        // But we're going to be a little lax and not really care as long as only those three fields are
        // there. However, we are going to stick to the requirement that "version" has to be there. The
        // other two fields are optional. Also, each field can only be there once. In other words, for
        // example, the "standalone" field cannot exist twice.
        //--------------------------------------------------------------------------------------------------
        let sx    = "version|encoding|standalone"
        let sy    = "\\s+(\(sx))=\"([^\"]+)\""
        let regex = try RegularExpression(pattern: "^\\<\\?xml\(sy)(?:\(sy))?(?:\(sy))?\\s*\\?\\>")

        #if DEBUG
            print("XML Decl: \"\(declString)")
        #endif
        //------------------------------------------------------------------
        // We have what looks like a valid XML Declaration. So let's
        // parse it out, validate the data, and populate the xmlDecl tuple.
        //------------------------------------------------------------------
        if let match: RegularExpression.Match = regex.firstMatch(in: declString) {
            return try parseXMLDeclValues(&xmlDecl, match, declString, chStream)
        }
        //---------------------------------------------------------------
        // The XML Declaration we got is malformed and cannot be parsed.
        //---------------------------------------------------------------
        throw getSAXError_InvalidXMLDeclaration("The XML Declaration string is malformed: \"\(declString)\"")
    }

    /*===========================================================================================================================================================================*/
    /// Parse out the [XML Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml) found in the XML Document and populate the fields of our assumed xmlDecl tuple.
    /// 
    /// - Parameters:
    ///   - xmlDecl: the current (assumed) values.
    ///   - match: the RegularExpression.Match object from our RegularExpression test.
    ///   - declString: the full text of the [XML Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml) found in the document.
    ///   - chStream: the current (detected) <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    /// - Returns: the current <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code> or a new one if the
    ///            <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> encoding had to change.
    /// - Throws: if the [XML Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml) found in the document was malformed or the newly declared
    ///           <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> encoding found in it is unsupported.
    ///
    @inlinable final func parseXMLDeclValues(_ xmlDecl: inout XMLDecl, _ match: RegularExpression.Match, _ declString: String, _ chStream: CharInputStream) throws -> CharInputStream {
        //---------------------
        // Isolate the fields.
        //---------------------
        let values = try getXMLDeclFields(match)
        //---------------------------------------------------------------
        // Look for the version. At the very least that should be there.
        //---------------------------------------------------------------
        try parseXMLDeclVersion(&xmlDecl, declString, values)
        //------------------------------------
        // Now look for the "standalone" key.
        //------------------------------------
        try parseXMLDeclStandalone(&xmlDecl, values)
        //---------------------------------------------------------------------------------------
        // Now look for the "encoding" key and change the character stream's encoding if needed.
        //---------------------------------------------------------------------------------------
        return try parseXMLDeclEncoding(&xmlDecl, chStream, values)
    }

    /*===========================================================================================================================================================================*/
    /// Get the declared XML `version` from the [XML Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml) found in the document. If the [XML
    /// Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml) exists in the document then it has to at least have the `version`.
    /// 
    /// - Parameters:
    ///   - xmlDecl: the current [XML Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml) values.
    ///   - declString: the [XML Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml) found in the document.
    ///   - values: the values from that [XML Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml).
    /// - Throws: if the `version` is incorrect.
    ///
    @inlinable final func parseXMLDeclVersion(_ xmlDecl: inout XMLDecl, _ declString: String, _ values: [String: String]) throws {
        guard let declVersion = values["version"] else { throw getSAXError_InvalidXMLDeclaration("The version is missing from the XML Declaration: \"\(declString)\"") }
        guard (declVersion == "1.0") || (declVersion == "1.1") else { throw getSAXError_InvalidXMLVersion("The version stated in the XML Declaration is unsupported: \"\(declVersion)\"") }
        xmlDecl.version = declVersion
        xmlDecl.versionSpecified = true
    }

    /*===========================================================================================================================================================================*/
    /// Get the declared XML `standalone` field, if it exists, from the [XML Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml) found in the document.
    /// 
    /// - Parameters:
    ///   - xmlDecl: the current (assumed) [XML Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml) values.
    ///   - values: the values found in the [XML Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml) in the document.
    /// - Throws: if the value for `standalone` is not `yes` or `no`.
    ///
    @inlinable final func parseXMLDeclStandalone(_ xmlDecl: inout XMLDecl, _ values: [String: String]) throws {
        if let declStandalone = values["standalone"] {
            //--------------------------------------------------------
            // If it is there then it has to be either "yes" or "no".
            //--------------------------------------------------------
            guard value(declStandalone, isOneOf: "yes", "no") else { throw getSAXError_InvalidXMLDeclaration("Invalid argument for standalone: \"\(declStandalone)\"") }

            xmlDecl.standalone = (declStandalone == "yes")
            xmlDecl.standaloneSpecified = true
        }
    }

    /*===========================================================================================================================================================================*/
    /// Get the declared XML encoding from the [XML Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml) found in the document. If an encoding is found that is
    /// different than the detected encoding then create a new <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code> and return that
    /// one.
    /// 
    /// - Parameters:
    ///   - xmlDecl: the current (assumed) [XML Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml) values.
    ///   - chStream: the current (detected) <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    ///   - values: the values from the [XML Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml) found in the document.
    /// - Returns: the current <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code> unless a different encoding was declared in the
    ///            [XML Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml) in which case a new <code>[character input
    ///            stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code> with that encoding is returned.
    /// - Throws: if the newly declared <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> encoding is not supported.
    ///
    @inlinable final func parseXMLDeclEncoding(_ xmlDecl: inout XMLDecl, _ chStream: CharInputStream, _ values: [String: String]) throws -> CharInputStream {
        if let declEncoding = values["encoding"] {
            if declEncoding.uppercased() != xmlDecl.encoding {
                #if DEBUG
                    print("New Encoding Specified: \"\(declEncoding)\"")
                #endif
                let willChange = try isChangeReal(declEncoding: declEncoding, xmlDecl: xmlDecl)
                xmlDecl.encoding = declEncoding
                xmlDecl.encodingSpecified = true
                if willChange {
                    return try changeEncoding(xmlDecl: xmlDecl, chStream: chStream)
                }
            }

            xmlDecl.encoding = declEncoding
            xmlDecl.encodingSpecified = true
        }

        //--------------------------------------------------------------------------------
        // There is no change to the encoding so we stick with what we have and continue.
        //--------------------------------------------------------------------------------
        inputStream.markDelete()
        chStream.markDelete()
        return chStream
    }

    /*===========================================================================================================================================================================*/
    /// Changes the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code> to match the encoding that we found in the [XML
    /// Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml).
    /// 
    /// - Parameters:
    ///   - xmlDecl: the [XML Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml) values.
    ///   - chStream: the current <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    /// - Returns: the new <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    /// - Throws: if the new encoding is not supported by the installed version of libiconv.
    ///
    @usableFromInline func changeEncoding(xmlDecl decl: XMLDecl, chStream oChStream: CharInputStream) throws -> CharInputStream {
        let nEnc: String = decl.encoding.uppercased()
        //-----------------------------------------------------------------------
        // Close the old [character input stream](http://goober/Rubicon/Protocols/CharInputStream.html) and reset the byte input stream.
        //-----------------------------------------------------------------------
        oChStream.close()
        inputStream.markReturn()
        //--------------------------------------------------------------
        // Now check to make sure we have support for the new encoding.
        //--------------------------------------------------------------
        guard IConv.getEncodingsList().contains(nEnc) else {
            //--------------------------------------------------
            // The encoding found in the XML Declaration is not
            // supported by the installed version of libiconv.
            //--------------------------------------------------
            throw getSAXError_InvalidFileEncoding("The file encoding in the XML Declaration is not supported: \"\(decl.encoding)\"")
        }
        //----------------------------------------------------------------------------
        // We have support for the new encoding so open a new character input stream.
        //----------------------------------------------------------------------------
        let nChStream = IConvCharInputStream(inputStream: inputStream, autoClose: false, encodingName: nEnc)
        nChStream.open()
        //----------------------------------------------------------------------------------
        // Now read past the XML Declaration since we don't need to parse it a second time.
        //----------------------------------------------------------------------------------
        var lc: Character = " "
        while let ch = try nChStream.read() {
            if ch == ">" && lc == "?" { return nChStream }
            lc = ch
        }
        throw getSAXError_UnexpectedEndOfInput()
    }

    /*===========================================================================================================================================================================*/
    /// The declared encoding is different than what we guessed at so now let's see if we really have to change or if it's simply a variation of what we guessed.
    /// 
    /// - Parameters:
    ///   - xmlDecl: the current [XML Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml) values including what we guessed was the encoding.
    ///   - declEncoding: the encoding specified in the [XML Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml).
    /// - Returns: `true` if we really have to change the encoding or `false` if we can continue with what we have.
    /// - Throws: `SAXError.InvalidFileEncoding` if the declared byte order is definitely NOT what we encountered in the file.
    ///
    @inlinable func isChangeReal(declEncoding: String, xmlDecl: XMLDecl) throws -> Bool {
        func foo(_ str: String) -> Bool { (str == "UTF-16" || str == "UTF-32") }

        let dEnc = declEncoding.uppercased()
        let xEnc = xmlDecl.encoding

        if xEnc == "UTF-8" {
            return true
        }
        else if foo(dEnc) {
            return !xEnc.hasPrefix(dEnc)
        }
        else if foo(xEnc) && dEnc.hasPrefix(xEnc) {
            if xmlDecl.endianBom == Endian.getEndianBySuffix(dEnc) { return false }
            let msg = "The byte order detected in the file does not match the byte order in the XML Declaration: \(xmlDecl.endianBom) != \(Endian.getEndianBySuffix(dEnc))"
            throw SAXError.InvalidXMLDeclaration(description: msg)
        }

        return true
    }

    /*===========================================================================================================================================================================*/
    /// The the fields out of a regex match of the [XML Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml).
    /// 
    /// - Parameter match: the match object.
    /// - Returns: The map of fields and values.
    /// - Throws: if there was a duplicate field.
    ///
    @inlinable final func getXMLDeclFields(_ match: RegularExpression.Match) throws -> [String: String] {
        var values: [String: String] = [:]
        for i: Int in stride(from: 1, to: 7, by: 2) {
            if let key = match[i].subString, let val = match[i + 1].subString {
                let k = key.trimmed
                guard values[k] == nil else { throw getSAXError_InvalidXMLDeclaration("The XML Declaration contains duplicate fields. First duplicate field encountered: \"\(k)\"") }
                values[k] = val.trimmed
            }
        }
        return values
    }

    /*===========================================================================================================================================================================*/
    /// Without an [XML Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml) at the beginning of the XML document the only valid
    /// <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> encodings are UTF-8, UTF-16, and UTF-32. But before we can read enough of the document
    /// to tell if we even have an [XML Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml) we first have to try to determine the
    /// <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> width by looking at the first 4 bytes of data. This should tell us if we're looking at
    /// 8-bit (UTF-8), 16-bit (UTF-16), or 32-bit (UTF-32) <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s.
    /// 
    /// - Returns: the name of the detected <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> encoding and the detected endian if it is a
    ///            multi-byte <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> encoding.
    /// - Throws: SAXError or I/O <code>[Error](https://developer.apple.com/documentation/swift/error/)</code>.
    ///
    @usableFromInline final func detectFileEncoding() throws -> (String, Endian) {
        inputStream.markSet()
        defer { inputStream.markReturn() }

        var buf: [UInt8] = []
        let rc:  Int     = try inputStream.read(to: &buf, maxLength: 4)

        //-----------------------------------------------------------------------------------
        // No matter what it has to have at least 4 characters because the smallest possible
        // valid XML document is "<a/>" where "a" is any valid XML starting character. And
        // if it was encoded in UTF-32 we would at least get the "<" character even if the
        // BOM was missing.
        //-----------------------------------------------------------------------------------
        guard rc == 4 else { throw SAXError.UnexpectedEndOfInput(1, 1) }

        //-----------------------------------------
        // Don't change the order of these tests.
        //-----------------------------------------
        // Start by looking for a byte order mark.
        //-----------------------------------------
        if cmpPrefix(prefix: UTF32LEBOM, source: buf) { return ("UTF-32", .LittleEndian) }
        else if cmpPrefix(prefix: UTF32BEBOM, source: buf) { return ("UTF-32", .BigEndian) }
        else if cmpPrefix(prefix: UTF16LEBOM, source: buf) { return ("UTF-16", .LittleEndian) }
        else if cmpPrefix(prefix: UTF16BEBOM, source: buf) { return ("UTF-16", .BigEndian) }
        //-------------------------------------------------
        // There is no BOM so try to guess the byte order.
        //-------------------------------------------------
        else if buf[0] == 0 && buf[1] == 0 && buf[3] != 0 { return ("UTF-32BE", .None) }
        else if buf[0] != 0 && buf[2] == 0 && buf[3] == 0 { return ("UTF-32LE", .None) }
        else if (buf[0] == 0 && buf[1] != 0) || (buf[2] == 0 && buf[3] != 0) { return ("UTF-16BE", .None) }
        else if (buf[0] != 0 && buf[1] == 0) || (buf[2] != 0 && buf[3] == 0) { return ("UTF-16LE", .None) }
        //----------------------------
        // Default to UTF-8 encoding.
        //----------------------------
        return ("UTF-8", .None)
    }

    /*===========================================================================================================================================================================*/
    /// Read the [XML Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml) from the XML document.
    /// 
    /// - Parameter charStream: the <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> stream to read the declaration from.
    /// - Returns: a <code>[String](https://developer.apple.com/documentation/swift/String)</code> containing the [XML
    ///            Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml).
    /// - Throws: if the [XML Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml) is malformed of if the EOF was encountered before the end of the [XML
    ///           Declaration](https://xmlwriter.net/xml_guide/xml_declaration.shtml) was reached.
    ///
    @usableFromInline final func getXMLDecl(_ cStream: IConvCharInputStream) throws -> String {
        let s = try doRead(charInputStream: cStream) { ch, buffer in
            if ch == ">" {
                if let p = buffer.last, p == "?" { return true }
                throw getSAXError_InvalidXMLDeclaration("XML Declaration is invalid: \"<?xml>\"")
            }
            buffer <+ ch
            return false
        }
        return "<?xml\(s)>"
    }

    /*===========================================================================================================================================================================*/
    /// Get a `SAXError.MissingHandler(_:_:description:)` error.
    /// 
    /// - Parameter desc: the description of the error. If none is provided then the default will be used.
    /// - Returns: the error.
    ///
    @inlinable final func getSAXError_MissingHandler(_ desc: String? = nil) -> SAXError {
        if let d = desc { return SAXError.MissingHandler(charStream.lineNumber, charStream.columnNumber, description: d) }
        else { return SAXError.MissingHandler(charStream.lineNumber, charStream.columnNumber) }
    }

    /*===========================================================================================================================================================================*/
    /// Get a `SAXError.HandlerAlreadySet(_:_:description:)` error.
    /// 
    /// - Parameter desc: the description of the error. If none is provided then the default will be used.
    /// - Returns: the error.
    ///
    @inlinable final func getSAXError_HandlerAlreadySet(_ desc: String? = nil) -> SAXError {
        if let d = desc { return SAXError.HandlerAlreadySet(charStream.lineNumber, charStream.columnNumber, description: d) }
        else { return SAXError.HandlerAlreadySet(charStream.lineNumber, charStream.columnNumber) }
    }

    /*===========================================================================================================================================================================*/
    /// Get a `SAXError.InvalidXMLVersion(_:_:description:)` error.
    /// 
    /// - Parameter desc: the description of the error. If none is provided then the default will be used.
    /// - Returns: the error.
    ///
    @inlinable final func getSAXError_InvalidXMLVersion(_ desc: String? = nil) -> SAXError {
        if let d = desc { return SAXError.InvalidXMLVersion(charStream.lineNumber, charStream.columnNumber, description: d) }
        else { return SAXError.InvalidXMLVersion(charStream.lineNumber, charStream.columnNumber) }
    }

    /*===========================================================================================================================================================================*/
    /// Get a `SAXError.InvalidFileEncoding(_:_:description:)` error.
    /// 
    /// - Parameter desc: the description of the error. If none is provided then the default will be used.
    /// - Returns: the error.
    ///
    @inlinable final func getSAXError_InvalidFileEncoding(_ desc: String? = nil) -> SAXError {
        if let d = desc { return SAXError.InvalidFileEncoding(charStream.lineNumber, charStream.columnNumber, description: d) }
        else { return SAXError.InvalidFileEncoding(charStream.lineNumber, charStream.columnNumber) }
    }

    /*===========================================================================================================================================================================*/
    /// Get a `SAXError.InvalidXMLDeclaration(_:_:description:)` error.
    /// 
    /// - Parameter desc: the description of the error. If none is provided then the default will be used.
    /// - Returns: the error.
    ///
    @inlinable final func getSAXError_InvalidXMLDeclaration(_ desc: String? = nil) -> SAXError {
        if let d = desc { return SAXError.InvalidXMLDeclaration(charStream.lineNumber, charStream.columnNumber, description: d) }
        else { return SAXError.InvalidXMLDeclaration(charStream.lineNumber, charStream.columnNumber) }
    }

    /*===========================================================================================================================================================================*/
    /// Get a `SAXError.InvalidCharacter(_:_:description:)` error.
    /// 
    /// - Parameter desc: the description of the error.
    /// - Returns: the error.
    ///
    @inlinable final func getSAXError_InvalidCharacter(_ desc: String) -> SAXError { SAXError.InvalidCharacter(charStream.lineNumber, charStream.columnNumber, description: desc) }

    /*===========================================================================================================================================================================*/
    /// Get a `SAXError.UnexpectedElement(_:_:description:)` error.
    /// 
    /// - Parameter desc: the description of the error.
    /// - Returns: the error.
    ///
    @inlinable final func getSAXError_UnexpectedElement(_ desc: String) -> SAXError { SAXError.UnexpectedElement(charStream.lineNumber, charStream.columnNumber, description: desc) }

    /*===========================================================================================================================================================================*/
    /// Get a `SAXError.MalformedNumber(_:_:description:)` error.
    /// 
    /// - Parameter desc: the description of the error.
    /// - Returns: the error.
    ///
    @inlinable final func getSAXError_MalformedNumber(_ desc: String) -> SAXError { SAXError.MalformedNumber(charStream.lineNumber, charStream.columnNumber, description: desc) }

    /*===========================================================================================================================================================================*/
    /// Get a `SAXError.NamespaceError(_:_:description:)` error.
    /// 
    /// - Parameter desc: the description of the error.
    /// - Returns: the error.
    ///
    @inlinable final func getSAXError_NamespaceError(_ desc: String) -> SAXError { SAXError.NamespaceError(charStream.lineNumber, charStream.columnNumber, description: desc) }

    /*===========================================================================================================================================================================*/
    /// Get a `SAXError.UnexpectedEndOfInput(_:_:description:)` error.
    /// 
    /// - Parameter desc: the description of the error. If none is provided then the default will be used.
    /// - Returns: the error.
    ///
    @inlinable final func getSAXError_UnexpectedEndOfInput(_ desc: String? = nil) -> SAXError {
        if let d = desc { return SAXError.UnexpectedEndOfInput(charStream.lineNumber, charStream.columnNumber, description: d) }
        else { return SAXError.UnexpectedEndOfInput(charStream.lineNumber, charStream.columnNumber) }
    }

    /*===========================================================================================================================================================================*/
    /// Byte-order.
    ///
    public enum Endian {
        /*=======================================================================================================================================================================*/
        /// No byte-order or none detected.
        ///
        case None
        /*=======================================================================================================================================================================*/
        /// Little Endian byte-order.
        ///
        case LittleEndian
        /*=======================================================================================================================================================================*/
        /// Big Endian byte-order.
        ///
        case BigEndian
    }

    /*===========================================================================================================================================================================*/
    /// DTD Entity Types
    ///
    public enum DTDEntityType {
        /*=======================================================================================================================================================================*/
        /// General entity.
        ///
        case General
        /*=======================================================================================================================================================================*/
        /// Parameter entity.
        ///
        case Parameter
    }

    /*===========================================================================================================================================================================*/
    /// The type of external resource.
    ///
    public enum DTDExternalType {
        /*=======================================================================================================================================================================*/
        /// Private resource.
        ///
        case System
        /*=======================================================================================================================================================================*/
        /// Public resource.
        ///
        case Public
    }

    /*===========================================================================================================================================================================*/
    /// The DTD attribute value types.
    ///
    public enum DTDAttrType {
        /*=======================================================================================================================================================================*/
        /// <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> data.
        ///
        case CDATA
        /*=======================================================================================================================================================================*/
        /// ID attribute.
        ///
        case ID
        /*=======================================================================================================================================================================*/
        /// ID reference.
        ///
        case IDREF
        /*=======================================================================================================================================================================*/
        /// ID references.
        ///
        case IDREFS
        /*=======================================================================================================================================================================*/
        /// Entity
        ///
        case ENTITY
        /*=======================================================================================================================================================================*/
        /// Entities
        ///
        case ENTITIES
        /*=======================================================================================================================================================================*/
        /// NMToken
        ///
        case NMTOKEN
        /*=======================================================================================================================================================================*/
        /// NMTokens
        ///
        case NMTOKENS
        /*=======================================================================================================================================================================*/
        /// Notation
        ///
        case NOTATION
        /*=======================================================================================================================================================================*/
        /// Enumerated
        ///
        case ENUMERATED
    }

    /*===========================================================================================================================================================================*/
    /// DTD Attribute Value Requirement Types
    ///
    public enum DTDAttrRequirementType {
        /*=======================================================================================================================================================================*/
        /// The attribute is required.
        ///
        case Required
        /*=======================================================================================================================================================================*/
        /// The attribute is optional.
        ///
        case Optional
        /*=======================================================================================================================================================================*/
        /// The attribute has a fixed value.
        ///
        case Fixed
    }

    /*===========================================================================================================================================================================*/
    /// Holds a prefix and namespace URI combination.
    ///
    @usableFromInline class NamespaceURIMapping {
        /*=======================================================================================================================================================================*/
        /// The prefix.
        ///
        @usableFromInline let prefix:       String
        /*=======================================================================================================================================================================*/
        /// The namespace URI.
        ///
        @usableFromInline let namespaceURI: String

        /*=======================================================================================================================================================================*/
        /// Create a new namespace prefix/URI mapping.
        /// 
        /// - Parameters:
        ///   - prefix: the namespace prefix.
        ///   - namespaceURI: the namespace URI.
        ///
        @usableFromInline init(prefix: String = "", namespaceURI: String) {
            self.prefix = prefix
            self.namespaceURI = namespaceURI
        }
    }

    @inlinable final func markSet() { charStream.markSet() }

    @inlinable final func markDelete() { charStream.markDelete() }

    @inlinable final func markReturn() { charStream.markReturn() }

    @inlinable final func markUpdate() { charStream.markUpdate() }

    @inlinable final func markReset() { charStream.markReset() }

    @inlinable final func markBackup(count: Int = 1) { charStream.markBackup(count: count) }

    /*===========================================================================================================================================================================*/
    /// Holds intermediate attribute information while parsing an element tag.
    ///
    @usableFromInline class NSAttribInfo {
        /*=======================================================================================================================================================================*/
        /// the line number of the start of the attribute.
        ///
        @usableFromInline let line:         Int
        /*=======================================================================================================================================================================*/
        /// the column number of the start of the attribute.
        ///
        @usableFromInline let column:       Int
        /*=======================================================================================================================================================================*/
        /// the namespace prefix for the attribute name.
        ///
        @usableFromInline let prefix:       String?
        /*=======================================================================================================================================================================*/
        /// the localname for the attribute name.
        ///
        @usableFromInline let localName:    String
        /*=======================================================================================================================================================================*/
        /// the namespace URI for the attribute.
        ///
        @usableFromInline var namespaceURI: String? = nil
        /*=======================================================================================================================================================================*/
        /// the value for the attribute.
        ///
        @usableFromInline let value:        String

        /*=======================================================================================================================================================================*/
        /// the fully qualified name for this attribute.
        ///
        @usableFromInline var qName: String { Gettysburg.qName(prefix: prefix, localName: localName) }

        /*=======================================================================================================================================================================*/
        /// Constructs a new namespaced attribute info.
        /// 
        /// - Parameters:
        ///   - line: the line number of the start of the attribute.
        ///   - column: the column number of the start of the attribute.
        ///   - prefix: the namespace prefix for the attribute name.
        ///   - localName: the localname for the attribute name.
        ///   - value: the value for the attribute.
        ///
        @usableFromInline init(line: Int, column: Int, prefix: String?, localName: String, value: String) {
            self.line = line
            self.column = column
            self.prefix = prefix
            self.localName = localName
            self.value = value
        }
    }
}

extension SAXParser.DTDEntityType: CustomStringConvertible {
    /*===========================================================================================================================================================================*/
    /// A description of the entity type.
    ///
    public var description: String {
        switch self {
            case .General:   return "General"
            case .Parameter: return "Parameter"
        }
    }
}

extension SAXParser.DTDAttrType: CustomStringConvertible {
    /*===========================================================================================================================================================================*/
    /// A description of the attribute value type.
    ///
    public var description: String {
        switch self {
            case .CDATA:      return "CDATA"
            case .ID:         return "ID"
            case .IDREF:      return "IDREF"
            case .IDREFS:     return "IDREFS"
            case .ENTITY:     return "ENTITY"
            case .ENTITIES:   return "ENTITIES"
            case .NMTOKEN:    return "NMTOKEN"
            case .NMTOKENS:   return "NMTOKENS"
            case .NOTATION:   return "NOTATION"
            case .ENUMERATED: return "ENUMERATED"
        }
    }
}

extension SAXParser.DTDAttrRequirementType: CustomStringConvertible {
    /*===========================================================================================================================================================================*/
    /// A description of the attribute requirement type.
    ///
    public var description: String {
        switch self {
            case .Required: return "Required"
            case .Optional: return "Optional"
            case .Fixed:    return "Fixed"
        }
    }
}

extension SAXParser.Endian: CustomStringConvertible {
    /*===========================================================================================================================================================================*/
    /// A description of the byte-order.
    ///
    public var description: String {
        switch self {
            case .None:         return "N/A"
            case .LittleEndian: return "Little Endian"
            case .BigEndian:    return "Big Endian"
        }
    }

    /*===========================================================================================================================================================================*/
    /// Get the byte-order for it's description. Big endian values are `BE`, `BIG`, `BIGENDIAN`, `BIG ENDIAN`. Little endian values are `LE`, `LITTLE`, `LITTLEENDIAN`, `LITTLE
    /// ENDIAN`. Anything else returns `SAXParser.Endian.None`.
    ///
    @inlinable static func getEndianBOM(_ str: String?) -> Self {
        guard let str = str else { return .None }
        switch str.uppercased() {
            case "BE", "BIG", "BIGENDIAN", "BIG ENDIAN": return .BigEndian
            case "LE", "LITTLE", "LITTLEENDIAN", "LITTLE ENDIAN": return .LittleEndian
            default: return .None
        }
    }

    /*===========================================================================================================================================================================*/
    /// Get the endian by the encoding name's suffix. `LE` returns little endian, `BE` returns big endian, and anything else returns `SAXParser.Endian.None`.
    /// 
    /// - Parameter str: the suffix.
    /// - Returns: the endian.
    ///
    @inlinable static func getEndianBySuffix(_ str: String?) -> Self {
        guard let str = str else { return .None }
        let s = str.uppercased()
        return (s.hasSuffix("BE") ? .BigEndian : (s.hasSuffix("LE") ? .LittleEndian : .None))
    }
}

extension SAXParser.DTDExternalType: CustomStringConvertible {
    /*===========================================================================================================================================================================*/
    /// A description of the external type.
    ///
    public var description: String {
        switch self {
            case .System: return "System"
            case .Public: return "Public"
        }
    }
}
