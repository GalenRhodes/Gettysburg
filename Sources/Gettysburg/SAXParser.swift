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

    @usableFromInline let inputStream: MarkInputStream
    @usableFromInline var charStream:  CharInputStream! = nil
    @usableFromInline lazy var lock: RecursiveLock = RecursiveLock()

    @usableFromInline var foundRootElement: Bool = false

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
        charStream.markSet()
        defer { charStream.markDelete() }

        while let ch = try charStream.read() {
            if ch == "<" {
                try parseDelimitedNode(handler)
            }
            else if ch.isWhitespace {
                try parseWhitespaceNode(handler)
            }
            else {
                charStream.markReset()
                throw getSAXError_InvalidCharacter("Character \"\(ch)\" not expected here.")
            }

            charStream.markUpdate()
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
        charStream.markSet()
        defer { charStream.markDelete() }

        if let ch = try charStream.read() {
            switch ch {
                case "!":
                    charStream.markSet()
                    //
                    // Read the next 8 characters and see what we have here.
                    //
                    let str = try readString(count: 8)

                    if str.hasPrefix("DOCTYPE") && str[str.index(before: str.endIndex)].isWhitespace {
                        guard !noDTD else {
                            charStream.markReturn()
                            charStream.markReset()
                            throw getSAXError_UnexpectedElement("A DOCTYPE declaration is not expected here.")
                        }
                        charStream.markDelete()
                        //
                        // This is a doctype node.
                        //
                        try parseDocType(handler)
                    }
                    else if str.hasPrefix("--") {
                        charStream.markBackup(count: 6)
                        charStream.markDelete()
                        //
                        // This is a comment node.
                        //
                        try parseComment(handler)
                    }
                    else {
                        charStream.markReturn()
                        throw getSAXError_InvalidCharacter("Unexpected characters \"\(str)\".")
                    }
                case "?": try parseProcessingInstruction(handler: handler)
                default: break
            }
        }
        else {
            throw getSAXError_UnexpectedEndOfInput()
        }
    }

    /*===========================================================================================================================================================================*/
    /// Read and parse the processing instruction.
    /// 
    /// - Parameter handler: the handler.
    /// - Throws: if an I/O error occurs or if the EOF was found before the end of the processing instruction node.
    ///
    @inlinable final func parseProcessingInstruction(handler: H) throws {
        let (target, data) = getPITargetAndData(processingInstruction: try readUntil(marker: "?>"))
        handler.processingInstruction(parser: self, target: target, data: data)
    }

    /*===========================================================================================================================================================================*/
    /// Take the string that contains the body of the processing instruction and break out the target and the data.
    /// 
    /// - Parameter pi: the body of the processing instruction.
    /// - Returns: a tuple with the target and the data.
    ///
    @inlinable final func getPITargetAndData(processingInstruction pi: String) -> (String, String) {
        var idx = pi.startIndex
        while idx < pi.endIndex {
            if pi[idx].isWhitespace {
                let target = String(pi[pi.startIndex ..< idx]).trimmed
                idx = pi.index(after: idx)
                while idx < pi.endIndex {
                    if !pi[idx].isWhitespace { return (target, String(pi[idx ..< pi.endIndex]).trimmed) }
                    idx = pi.index(after: idx)
                }
                return (target, "")
            }
            idx = pi.index(after: idx)
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
        charStream.markReset()
        let str = try readWhitespace()
        handler.text(parser: self, content: str, isWhitespace: true)
    }

    /*===========================================================================================================================================================================*/
    /// Parse an encountered comment.
    /// 
    /// - Parameter handler: the handler.
    /// - Throws: if an I/O error occurs or the comment is malformed.
    ///
    func parseComment(_ handler: H) throws {
        var comment: [Character] = []

        charStream.markSet()
        defer { charStream.markDelete() }

        while comment.count < 2 {
            guard let ch = try charStream.read() else { throw getSAXError_UnexpectedEndOfInput() }
            comment <+ ch
        }

        while let ch = try charStream.read() {
            let cc = comment.count

            if comment[cc - 1] == "-" && comment[cc - 2] == "-" {
                guard ch == ">" else {
                    charStream.markBackup(count: 2)
                    throw getSAXError_InvalidCharacter("Comments cannot contain double dashes.")
                }
                comment.removeLast(2)
                handler.comment(parser: self, comment: String(comment))
                return
            }
            else {
                comment <+ ch
            }
        }

        throw getSAXError_UnexpectedEndOfInput()
    }

    /*===========================================================================================================================================================================*/
    /// Parse out a DOCTYPE Declaration.
    /// 
    /// - Parameter handler: The handler.
    /// - Throws: if an I/O error occurs or if the DOCTYPE declaration is malformed or incomplete.
    ///
    func parseDocType(_ handler: H) throws {
    }

    /*===========================================================================================================================================================================*/
    /// Read and return all the <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> up to but not including the first encountered NON-whitespace
    /// character.
    /// 
    /// - Returns: the <code>[String](https://developer.apple.com/documentation/swift/String)</code> of
    ///            <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s read.
    /// - Throws: if an I/O error occurs.
    ///
    @usableFromInline final func readWhitespace() throws -> String {
        var chars: [Character] = []
        charStream.markSet()

        while let ch = try charStream.read() {
            guard ch.isWhitespace else {
                charStream.markBackup(count: 1)
                return String(chars)
            }
            chars <+ ch
        }

        charStream.markDelete()
        return String(chars)
    }

    /*===========================================================================================================================================================================*/
    /// Read `count` number of character from the input stream and return them as a string.
    /// 
    /// - Parameters:
    ///   - count: the number of characters to read.
    ///   - errorOnEOF: if `true` and there are fewer than `count` characters left in the input stream then throw an exception.
    /// - Returns: the number of characters read.
    /// - Throws: if there is an I/O error or `errorOnEOF` is `true` and there are fewer than `count` characters left in the input stream.
    ///
    @inlinable final func readString(count: Int, errorOnEOF: Bool = true) throws -> String {
        var chars: [Character] = []
        guard try charStream.read(chars: &chars, maxLength: count) == count || !errorOnEOF else { throw getSAXError_UnexpectedEndOfInput() }
        return String(chars)
    }

    /*===========================================================================================================================================================================*/
    /// Read and return all the <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s up to but not including the first encountered whitespace
    /// character.
    /// 
    /// - Returns: The <code>[String](https://developer.apple.com/documentation/swift/String)</code> of
    ///            <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s read.
    /// - Throws: if an I/O error occurs.
    ///
    @usableFromInline final func readUntilWhitespace() throws -> String {
        var chars: [Character] = []
        charStream.markSet()

        while let ch = try charStream.read() {
            guard !ch.isWhitespace else {
                charStream.markReturn()
                return String(chars)
            }
            chars <+ ch
            charStream.markUpdate()
        }

        charStream.markDelete()
        return String(chars)
    }

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
    @usableFromInline final func readUntil(marker: String, dropMarker: Bool = true, leaveFPatMarker: Bool = false) throws -> String {
        var chars: [Character] = []
        let _mrkr: [Character] = marker.getCharacters()

        while chars.count < _mrkr.count {
            guard let ch = try charStream.read() else { throw getSAXError_UnexpectedEndOfInput() }
            chars <+ ch
        }

        while !cmpSuffix(suffix: _mrkr, source: chars) {
            guard let ch = try charStream.read() else { throw getSAXError_UnexpectedEndOfInput() }
            chars <+ ch
        }

        return String(chars)
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
        if String(chars) == "<?xml" { return try parseXMLDeclaration(try getXMLDecl(tCharStream), chStream: tCharStream, xmlDecl: &xmlDecl) }
        //-----------------------------------------------------------------------------------
        // Otherwise there is no XML Declaration so we stick with what we have and continue.
        //-----------------------------------------------------------------------------------
        inputStream.markDelete()
        tCharStream.markReturn()
        return tCharStream
    }

    /*===========================================================================================================================================================================*/
    /// Parse the XML Declaration read from the document.
    /// 
    /// - Parameters:
    ///   - declString: the XML Declaration read from the document.
    ///   - chStream: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    ///   - xmlDecl: the current XML Declaration values.
    /// - Returns: either the current <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code> or a new one if it was determined that
    ///            it needed to change <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> encoding.
    /// - Throws: if an error occurred or if there was a problem with the XML Declaration.
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
        if let match: RegularExpression.Match = regex.firstMatch(in: declString) { return try parseXMLDeclValues(&xmlDecl, match, declString, chStream) }
        //---------------------------------------------------------------
        // The XML Declaration we got is malformed and cannot be parsed.
        //---------------------------------------------------------------
        throw getSAXError_InvalidXMLDeclaration("The XML Declaration string is malformed: \"\(declString)\"")
    }

    /*===========================================================================================================================================================================*/
    /// Parse out the XML Declaration found in the XML Document and populate the fields of our assumed xmlDecl tuple.
    /// 
    /// - Parameters:
    ///   - xmlDecl: the current (assumed) values.
    ///   - match: the RegularExpression.Match object from our RegularExpression test.
    ///   - declString: the full text of the XML Declaration found in the document.
    ///   - chStream: the current (detected) <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    /// - Returns: the current <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code> or a new one if the character encoding had to
    ///            change.
    /// - Throws: if the XML Declaration found in the document was malformed or the newly declared character encoding found in it is unsupported.
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
    /// Get the declared XML `version` from the XML Declaration found in the document. If the XML Declaration exists in the document then it has to at least have the `version`.
    /// 
    /// - Parameters:
    ///   - xmlDecl: the current XML Declaration values.
    ///   - declString: the XML Declaration found in the document.
    ///   - values: the values from that XML Declaration.
    /// - Throws: if the `version` is incorrect.
    ///
    @inlinable final func parseXMLDeclVersion(_ xmlDecl: inout XMLDecl, _ declString: String, _ values: [String: String]) throws {
        guard let declVersion = values["version"] else { throw getSAXError_InvalidXMLDeclaration("The version is missing from the XML Declaration: \"\(declString)\"") }
        guard (declVersion == "1.0") || (declVersion == "1.1") else { throw getSAXError_InvalidXMLVersion("The version stated in the XML Declaration is unsupported: \"\(declVersion)\"") }
        xmlDecl.version = declVersion
        xmlDecl.versionSpecified = true
    }

    /*===========================================================================================================================================================================*/
    /// Get the declared XML `standalone` field, if it exists, from the XML Declaration found in the document.
    /// 
    /// - Parameters:
    ///   - xmlDecl: the current (assumed) XML Declaration values.
    ///   - values: the values found in the XML Declaration in the document.
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
    /// Get the declared XML encoding from the XML Declaration found in the document. If an encoding is found that is different than the detected encoding then create a new
    /// <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code> and return that one.
    /// 
    /// - Parameters:
    ///   - xmlDecl: the current (assumed) XML Declaration values.
    ///   - chStream: the current (detected) <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    ///   - values: the values from the XML Declaration found in the document.
    /// - Returns: the current <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code> unless a different encoding was declared in the
    ///            XML Declaration in which case a new <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code> with that encoding is
    ///            returned.
    /// - Throws: if the newly declared character encoding is not supported.
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
                if willChange { return try changeEncoding(xmlDecl: xmlDecl, chStream: chStream) }
            }

            xmlDecl.encoding = declEncoding
            xmlDecl.encodingSpecified = true
        }

        //--------------------------------------------------------------------------------
        // There is no change to the encoding so we stick with what we have and continue.
        //--------------------------------------------------------------------------------
        inputStream.markDelete()
        return chStream
    }

    /*===========================================================================================================================================================================*/
    /// Changes the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code> to match the encoding that we found in the XML Declaration.
    /// 
    /// - Parameters:
    ///   - xmlDecl: the XML Declaration values.
    ///   - chStream: the current <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    /// - Returns: the new <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    /// - Throws: if the new encoding is not supported by the installed version of libiconv.
    ///
    @usableFromInline func changeEncoding(xmlDecl decl: XMLDecl, chStream oChStream: CharInputStream) throws -> CharInputStream {
        let nEnc: String = decl.encoding.uppercased()
        //-----------------------------------------------------------------------
        // Close the old character input stream and reset the byte input stream.
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
        _ = try readUntil(marker: "?>")
        return nChStream
    }

    /*===========================================================================================================================================================================*/
    /// The declared encoding is different than what we guessed at so now let's see if we really have to change or if it's simply a variation of what we guessed.
    /// 
    /// - Parameters:
    ///   - xmlDecl: the current XML Declaration values including what we guessed was the encoding.
    ///   - declEncoding: the encoding specified in the XML Declaration.
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
    /// The the fields out of a regex match of the XML Declaration.
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
    /// Without an XML Declaration at the beginning of the XML document the only valid <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>
    /// encodings are UTF-8, UTF-16, and UTF-32. But before we can read enough of the document to tell if we even have an XML Declaration we first have to try to determine the
    /// <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> width by looking at the first 4 bytes of data. This should tell us if we're looking at
    /// 8-bit (UTF-8), 16-bit (UTF-16), or 32-bit (UTF-32) characters.
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
    /// Read the XML Declaration from the XML document.
    /// 
    /// - Parameter charStream: the <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> stream to read the declaration from.
    /// - Returns: a <code>[String](https://developer.apple.com/documentation/swift/String)</code> containing the XML Declaration.
    /// - Throws: if the XML Declaration is malformed of if the EOF was found before the end of the XML Declaration was reached.
    ///
    @usableFromInline final func getXMLDecl(_ charStream: IConvCharInputStream) throws -> String {
        var chars: [Character] = []
        if let c1 = try charStream.read() {
            guard c1 != ">" else { throw getSAXError_InvalidXMLVersion("The XML Declaration string is malformed: \"<?xml>\"") }
            chars <+ c1
            while let c2 = try charStream.read() {
                if c2 == ">" && chars.last! == "?" { return "<?xml\(String(chars))>" }
                chars <+ c2
            }
        }
        throw getSAXError_InvalidXMLVersion("Unexpected end of input. The XML Declaration is incomplete: \"<?xml \(String(chars))\"")
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
        /// Character data.
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
