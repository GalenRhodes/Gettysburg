/*******************************************************************************************************************************************************************************//*
 *     PROJECT: Gettysburg
 *    FILENAME: SAXParser.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 6/1/21
 *
 * Copyright © 2021 Galen Rhodes. All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software for any purpose with or without fee is hereby granted, provided that the above copyright notice and this
 * permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO
 * EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN
 * AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *//******************************************************************************************************************************************************************************/

import Foundation
import CoreFoundation
import Rubicon

open class SAXParser {

    @usableFromInline typealias NSMappingList = Set<NSMapping>

    public var xmlVersion:      String { _xmlVersion }
    public var xmlEncoding:     String { _xmlEncoding }
    public var xmlIsStandalone: Bool { _xmlIsStandalone }
    public let handler:         SAXHandler

    open var url:      URL { inputStream.url }
    open var baseURL:  URL { inputStream.baseURL }
    open var filename: String { inputStream.filename }

    @usableFromInline let inputStream:      SAXCharInputStreamStack
    @usableFromInline var namespaceStack:   [NSMappingList] = []
    @usableFromInline var _xmlVersion:      String          = "1.1"
    @usableFromInline var _xmlEncoding:     String          = "UTF-8"
    @usableFromInline var _xmlIsStandalone: Bool            = true

    /*===========================================================================================================================================================================*/
    public init(inputStream: InputStream, url: URL, handler: SAXHandler) throws {
        nDebug(.In, "SAXParser.init")
        defer { nDebug(.Out, "SAXParser.init") }
        self.inputStream = try SAXCharInputStreamStack(initialInputStream: inputStream, url: url)
        self._xmlEncoding = self.inputStream.encodingName
        self.handler = handler
    }

    /*===========================================================================================================================================================================*/
    public convenience init(url: URL, handler: SAXHandler) throws {
        guard let _is = InputStream(url: url) else { throw StreamError.FileNotFound(description: url.absoluteString) }
        try self.init(inputStream: _is, url: url.absoluteURL, handler: handler)
    }

    /*===========================================================================================================================================================================*/
    public convenience init(fileAtPath: String, handler: SAXHandler) throws {
        guard let _is = InputStream(fileAtPath: fileAtPath) else { throw StreamError.FileNotFound(description: fileAtPath) }
        try self.init(inputStream: _is, url: GetFileURL(filename: fileAtPath), handler: handler)
    }

    /*===========================================================================================================================================================================*/
    public convenience init(data: Data, url: URL? = nil, handler: SAXHandler) throws {
        let _url = (url ?? URL(fileURLWithPath: "temp_\(UUID().uuidString).xml", isDirectory: false, relativeTo: GetCurrDirURL()))
        try self.init(inputStream: InputStream(data: data), url: _url, handler: handler)
    }

    /*===========================================================================================================================================================================*/
    /// Parse the XML document from the given input stream.
    ///
    /// - Throws: If an error occured.
    ///
    open func parse() throws {
        do {
            inputStream.open()
            defer { inputStream.close() }

            try getXmlDeclaration()
            markSet()
            defer { markDelete() }

            var hasDocType:  Bool = false
            var hasRootElem: Bool = false

            while let ch = try inputStream.read() {
                switch ch {
                    case "<": try handleRootNodeItem(&hasDocType, &hasRootElem)
                    default:  guard ch.isXmlWhitespace else { throw unexpectedCharacterError(character: ch) }
                }
                markUpdate()
            }
        }
        catch let e {
            guard handler.handleError(self, error: e) else { throw e }
        }
    }

    /*===========================================================================================================================================================================*/
    /// Parse a root node item.
    ///
    /// - Parameters:
    ///   - hasDocType: A flag that indicates the DOCTYPE node has already been found.
    ///   - hasRootElem: A flag that indicates the root element node has already been found.
    /// - Throws: If an I/O error occurs or the root node item is malformed.
    ///
    private func handleRootNodeItem(_ hasDocType: inout Bool, _ hasRootElem: inout Bool) throws {
        guard let ch = try inputStream.read() else { throw SAXError.getUnexpectedEndOfInput() }

        switch ch {
            case "!":
                guard let ch = try inputStream.read() else { throw SAXError.getUnexpectedEndOfInput() }
                switch ch {
                    case "-":
                        markBackup(count: 3)
                        try handleComment()
                    case "D":
                        markBackup(count: 3)
                        try handleDocType()
                    default:
                        throw unexpectedCharacterError(character: ch)
                }
                break
            case "?":
                markBackup(count: 2)
                try handleProcessingInstruction()
            default:
                guard ch.isXmlNameStartChar else { throw unexpectedCharacterError(character: ch) }
                guard !hasRootElem else { throw SAXError.getMalformedDocument(markBackup(count: 2), description: "Document already has a root element.") }
                markBackup(count: 2)
                try handleNestedElement()
                hasRootElem = true
                break
        }
    }

    /*===========================================================================================================================================================================*/
    private func handleDocType() throws {
        var buffer: [Character] = []
        guard try inputStream.read(chars: &buffer, maxLength: 10) == 10 else { throw SAXError.getUnexpectedEndOfInput() }
        guard try String(buffer).matches(pattern: "^\\<\\!DOCTYPE\\s+") else { throw SAXError.getMalformedDocType(markReset(), description: "Not a DOCTYPE element: \"\(String(buffer))\"") }
        guard let elem = try nextIdentifier(leadingWhitespace: .Allowed) else { throw SAXError.getMalformedDocType(markReset(), description: "Missing root element.") }
        guard let ch = try read(leadingWhitespace: .Required) else { throw SAXError.getUnexpectedEndOfInput() }
        switch ch {
            case "[": try handleInternalDocType(rootElement: elem)
            case "S": markBackup(); try handleExternalSystemDocType(rootElement: elem)
            case "P": markBackup(); try handleExternalPublicDocType(rootElement: elem)
            default: throw SAXError.getMalformedDocType(markBackup(), description: unexpectedCharMessage(character: ch))
        }
    }

    /*===========================================================================================================================================================================*/
    private func handleExternalSystemDocType(rootElement elem: String) throws {
        guard let tp = try nextIdentifier(leadingWhitespace: .None) else { throw SAXError.getMalformedDocType(markReset(), description: "Missing external type.") }
        guard tp == "SYSTEM" else { throw SAXError.getMalformedDocType(markReset(), description: "Incorrect external type: \"\(tp)\"") }
        let url = try readSystemID()
        let ws  = try readWhitespace()
        guard let ch = try inputStream.read() else { throw SAXError.getUnexpectedEndOfInput() }

        if ch == "[" {
            guard ws else { throw SAXError.getMissingWhitespace(markBackup()) }
            try handleInternalDocType(rootElement: elem)
        }
        else if ch != ">" {
            throw SAXError.getMalformedDocType(markBackup(), description: unexpectedCharMessage(character: ch))
        }

        let body = try GetExternalFile(parentStream: inputStream, url: url)
        try parseDocType(rootElement: elem, body: body, url: url)
    }

    /*===========================================================================================================================================================================*/
    private func handleExternalPublicDocType(rootElement elem: String) throws {
        markUpdate()
        guard let tp = try nextIdentifier(leadingWhitespace: .None) else { throw SAXError.getMalformedDocType(markReset(), description: "Missing external type.") }
        guard tp == "PUBLIC" else { throw SAXError.getMalformedDocType(markReset(), description: "Incorrect external type: \"\(tp)\"") }
        guard let pid = try nextQuotedValue(leadingWhitespace: .Required) else { throw SAXError.getMalformedURL(inputStream, description: "Missing public ID.") }
        let url = try readSystemID()
        guard let ch = try read(leadingWhitespace: .Allowed) else { throw SAXError.getUnexpectedEndOfInput() }
        guard ch == ">" else { throw SAXError.getMalformedDocType(markBackup(), description: unexpectedCharMessage(character: ch)) }
        let body = try GetExternalFile(parentStream: inputStream, url: url)
        try parseDocType(rootElement: elem, body: body, name: pid, url: url)
    }

    /*===========================================================================================================================================================================*/
    private func handleInternalDocType(rootElement elem: String) throws {
        var buffer: [Character]  = []
        let pos:    TextPosition = inputStream.position

        while let ch = try inputStream.read() {
            if ch == "]" {
                guard let ch = try inputStream.read() else { throw SAXError.getUnexpectedEndOfInput() }
                if ch == ">" { return try parseDocType(rootElement: elem, body: String(buffer), position: pos) }
                buffer <+ "]"
                buffer <+ ch
            }
            buffer <+ ch
        }

        throw SAXError.getUnexpectedEndOfInput()
    }

    /*===========================================================================================================================================================================*/
    private func parseDocType(rootElement elem: String, body: String, name: String? = nil, url: URL? = nil, position pos: TextPosition = (0, 0)) throws {
        let pattern             = "<!--(.*?)-->|<!(ELEMENT|ENTITY|ATTLIST|NOTATION)(?:\\s+([^>]*))?>"
        let regex               = GetRegularExpression(pattern: pattern, options: [ .dotMatchesLineSeparators ])
        var last:  String.Index = body.startIndex
        var error: Error?       = nil
        var pos                 = pos

        regex.forEachMatch(in: body) { match, _, stop in
            if let match = match {
                do {
                    try body[last ..< match.range.lowerBound].forEach { ch in
                        guard ch.isXmlWhitespace else { throw SAXError.MalformedDocType(position: pos, description: unexpectedCharMessage(character: ch)) }
                        textPositionUpdate(ch, pos: &pos, tabWidth: 4)
                    }

                    if let rComment = match[1].range {
                        let comment = String(body[rComment])
                        try _foo01(body: body, startIndex: match.range.lowerBound, comment: comment, rComment: rComment, position: pos)
                        handler.comment(self, content: comment)
                    }
                    else if let rType = match[2].range {
                        let type = String(body[rType])
                        if let rData = match[3].range {
                            let rToData = (match.range.lowerBound ..< rData.lowerBound)
                            let pData   = GetPosition(from: body, range: rToData, startingAt: pos)
                            let sData   = String(body[rData]).trimmingCharacters(in: .XMLWhitespace)

                            switch type {
                                case "ELEMENT": try parseDocTypeElement(rootElement: elem, body: sData, name: name, url: url, position: pData)
                                case "ENTITY":  try parseDocTypeEntity(rootElement: elem, body: sData, name: name, url: url, position: pData)
                                case "ATTLIST": try parseDocTypeAttList(rootElement: elem, body: sData, name: name, url: url, position: pData)
                                default:        try parseDocTypeNotation(rootElement: elem, body: sData, name: name, url: url, position: pData)
                            }
                        }
                        else {
                            throw SAXError.MalformedDocType(position: pos, description: "Empty DTD \(type) Decl.")
                        }
                    }

                    AdvancePosition(from: body, range: match.range, position: &pos)
                    last = match.range.upperBound
                }
                catch let e {
                    error = e
                    stop = true
                }
            }
        }

        if let e = error { throw e }
    }

    /*===========================================================================================================================================================================*/
    private func _foo01(body: String, startIndex: String.Index, comment: String, rComment: Range<String.Index>, position pos: TextPosition) throws {
        if let rx = comment.range(of: "--") {
            let d = comment.distance(from: startIndex, to: rx.lowerBound)
            let p = GetPosition(from: body, range: startIndex ..< body.index(startIndex, offsetBy: d), startingAt: pos)
            throw SAXError.MalformedComment(position: p, description: "Comment cannot contain double minus (-) signs.")
        }
        else if comment.hasSuffix("-") {
            let p = GetPosition(from: body, range: startIndex ..< rComment.lowerBound, startingAt: pos)
            throw SAXError.MalformedComment(position: p, description: "Comment cannot contain double minus (-) signs.")
        }
    }

    /*===========================================================================================================================================================================*/
    private func parseDocTypeElement(rootElement elem: String, body: String, name: String? = nil, url: URL? = nil, position pos: TextPosition) throws {
        let p = "(\(rxNamePattern))\\s+(EMPTY|ANY|\\([^>]+)"
        guard let m = GetRegularExpression(pattern: p).firstMatch(in: body) else { throw SAXError.MalformedEntityDecl(position: pos, description: "<!ELEMENT \(body)>") }
        guard let name = m[1].subString else { fatalError("Incorrect ELEMENT REGEX") }
        guard let elst = m[2].subString else { fatalError("Incorrect ELEMENT REGEX") }
        let type = SAXElementAllowedContent.valueFor(description: elst)
        let elems = (value(type, isOneOf: .Elements, .Mixed) ? try ParseDTDElementContentList(position: pos, list: elst) : nil)
        handler.dtdElementDecl(self, name: name, allowedContent: type, content: elems)
    }

    /*===========================================================================================================================================================================*/
    private func parseDocTypeAttList(rootElement elem: String, body: String, name: String? = nil, url: URL? = nil, position pos: TextPosition) throws {
        let p0 = "(\(rxNamePattern))"
        let p1 = "(?:\\([^|)]+(?:\\|[^|)]+)*\\))"
        let p2 = "(CDATA|ID|IDREF|IDREFS|ENTITY|ENTITIES|NMTOKEN|NMTOKENS|NOTATION|\(p1))"
        let p3 = "(\\#REQUIRED|\\#IMPLIED|(?:(?:(#FIXED)\\s+)?\(rxQuotedString)))"
        let p  = "\(p0)\\s+\(p0)\\s+\(p2)\\s+\(p3)"

        guard let m = GetRegularExpression(pattern: p).firstMatch(in: body) else { throw SAXError.MalformedEntityDecl(position: pos, description: "<!ATTLIST \(body)>") }
        guard let elem = m[1].subString else { fatalError("Incorrect ATTLIST REGEX") }
        guard let name = m[2].subString else { fatalError("Incorrect ATTLIST REGEX") }
        guard let tpNm = m[3].subString, let type = SAXAttributeType.valueFor(description: tpNm) else { fatalError("Incorrect ATTLIST REGEX") }
        guard let defv = m[5].subString ?? m[4].subString else { fatalError("Incorrect ATTLIST REGEX") }

        handler.dtdAttributeDecl(self, name: name, elementName: elem, type: type, enumList: type.enumList(tpNm), defaultType: .valueFor(description: defv), defaultValue: m[6].subString)
    }

    /*===========================================================================================================================================================================*/
    private func parseDocTypeEntity(rootElement elem: String, body: String, name: String? = nil, url: URL? = nil, position pos: TextPosition) throws {
        let p0 = "(\(rxNamePattern))"
        let p1 = "\\s+\(rxQuotedString)"
        let p2 = "(?:\(p1))"
        let p3 = "\\s+(?:(?:(SYSTEM)|(PUBLIC)\(p1))\(p1))"
        let p4 = "(?:\\s+(NDATA)\\s+\(p0))?"
        let p5 = "(?:\(p3)\(p4))"
        let p6 = "(?:\(p3))"
        let p7 = "\(p0)(?:\(p2)|\(p5))"
        let p8 = "(\\%)\\s+\(p0)(?:\(p2)|\(p6))"
        let p  = "(?:\(p7)|\(p8))"
        guard let m = GetRegularExpression(pattern: p).firstMatch(in: body) else { throw SAXError.MalformedEntityDecl(position: pos, description: "<!ENTITY \(body)>") }

        let i:    Int           = (m[1].subString == nil ? 10 : 1)
        let type: SAXEntityType = ((i == 1) ? .General : .Parameter)
        guard let name = m[i].subString else { throw SAXError.MalformedEntityDecl(position: pos, description: "<!ENTITY \(body)>") }

        if let value = m[i + 1].subString?.deQuoted() {
            handler.dtdInternalEntityDecl(self, name: name, type: type, content: value)
        }
        else if (i == 1 && m[7].subString == "NDATA"), let sid = m[6].subString?.deQuoted(), let note = m[8].subString?.deQuoted() {
            handler.dtdUnparsedEntityDecl(self, name: name, publicId: m[5].subString?.deQuoted(), systemId: sid, notation: note)
        }
        else if (m[i + 2].subString == "SYSTEM" || m[i + 3].subString == "PUBLIC"), let sid = m[i + 5].subString?.deQuoted() {
            handler.dtdExternalEntityDecl(self, name: name, type: type, publicId: m[i + 4].subString?.deQuoted(), systemId: sid)
        }
        else {
            throw SAXError.MalformedEntityDecl(position: pos, description: "<!ENTITY \(body)>")
        }
    }

    /*===========================================================================================================================================================================*/
    private func parseDocTypeNotation(rootElement elem: String, body: String, name: String? = nil, url: URL? = nil, position pos: TextPosition) throws {
        let p = "(\(rxNamePattern))\\s+(SYSTEM|PUBLIC)\\s+(\(rxQuotedString))(?:\\s+(\(rxQuotedString)))?"
        guard let m = GetRegularExpression(pattern: p).firstMatch(in: body) else { throw SAXError.MalformedNotationDecl(position: pos, description: "<!NOTATION \(body)>") }
        guard let name = m[1].subString else { fatalError("Incorrect NOTATION REGEX") }
        guard let type = m[2].subString else { fatalError("Incorrect NOTATION REGEX") }
        guard let prm1 = m[3].subString?.deQuoted() else { fatalError("Incorrect NOTATION REGEX") }
        let prm2 = m[4].subString?.deQuoted()

        switch type {
            case "SYSTEM":
                guard prm2 == nil else { throw SAXError.MalformedNotationDecl(position: pos, description: "Extra parameter in system notation: \"\(prm2!)\"") }
                handler.dtdNotationDecl(self, name: name, publicId: nil, systemId: prm1)
            case "PUBLIC":
                handler.dtdNotationDecl(self, name: name, publicId: prm1, systemId: prm2)
            default:
                throw SAXError.MalformedNotationDecl(position: pos, description: "Invalid notation type: \"\(type)\"")
        }
    }

    /*===========================================================================================================================================================================*/
    /// Parse a nested element.
    ///
    /// - Throws: If there is an I/O error or the element is malformed.
    ///
    private func handleNestedElement() throws {
        guard let ch = try inputStream.read() else { return }
        guard ch == "<" else { throw unexpectedCharacterError(character: ch) }
        guard let tagName = try nextIdentifier() else { throw SAXError.getMalformedDocument(markReset(), description: "Missing element tag name.") }
        try handleElementAttributes(tagName: tagName)
    }

    /*===========================================================================================================================================================================*/
    /// Handle the attributes of an element tag. In the example:
    /// ```
    /// <SomeElement attr1="value1" attr2="value2">
    /// ```
    /// Everything after `<SomeElement ` up to the closing character, `>`, are the element attributes.
    ///
    /// - Parameter tagName: The name of the element.
    /// - Throws: If an I/O error occurs or if the element tag is malformed.
    ///
    private func handleElementAttributes(tagName: String) throws {
        var attribs: SAXRawAttribList = []

        repeat {
            let ws = try readWhitespace()
            guard let ch = try inputStream.read() else { throw SAXError.getUnexpectedEndOfInput() }

            if ch == ">" {
                try callElementBeginHandler(tagName: tagName, attributes: attribs)
                try handleElementBody(tagName: tagName, attributes: attribs)
                try callElementEndHandler(tagName: tagName)
                return
            }
            else if ch == "/" {
                guard try getChar(errorOnEOF: true, allowed: ">") != nil else { throw unexpectedCharacterError() }
                try callElementBeginHandler(tagName: tagName, attributes: attribs)
                try callElementEndHandler(tagName: tagName)
                // This is an empty element and has no body.
                return
            }
            else if ch.isXmlNameStartChar {
                guard ws else { throw SAXError.getMalformedDocument(markBackup(), description: "Whitespace was expected.") }
                markBackup()
                guard let key = try nextIdentifier() else { throw SAXError.getMalformedDocument(markBackup(), description: "Missing Attribute Name") }
                guard let ch = try inputStream.read() else { throw SAXError.getUnexpectedEndOfInput() }
                guard ch == "=" else { throw unexpectedCharacterError(character: ch) }
                guard let value = try nextQuotedValue() else { throw SAXError.getMalformedDocument(markBackup(), description: "Missing Attribute Value") }
                attribs <+ (SAXNSName(name: key), value)
            }
        } while true
    }

    /*===========================================================================================================================================================================*/
    /// Call the handler's `beginPrefixMapping(_:mapping:)` and `beginElement(_:name:attributes:)` methods. If needed, one or more calls to `beginPrefixMapping(_:mapping:)` will
    /// be made **BEFORE** the call to `beginElement(_:name:attributes:)`.
    ///
    /// - Parameters:
    ///   - tagName: The name of the element.
    ///   - attr: The attributes of the element.
    /// - Throws: If an I/O error occurs.
    ///
    private func callElementBeginHandler(tagName: String, attributes attribs: SAXRawAttribList) throws {
        // Go through the attributes and see if there are any namespaces that need to be processed.
        var fAttribs: SAXRawAttribList = []
        var mappings: NSMappingList    = NSMappingList()

        for a: SAXRawAttribute in attribs {
            let uri = a.value.trimmed
            if uri.isNotEmpty {
                if a.name.prefix == "xmlns" { mappings.insert(NSMapping(prefix: a.name.localName, uri: uri)) }
                else if a.name.name == "xmlns" { mappings.insert(NSMapping(prefix: "", uri: uri)) }
                else { fAttribs <+ a }
            }
            else {
                fAttribs <+ a
            }
        }

        namespaceStack <+ mappings
        for m in mappings.sorted() { handler.beginPrefixMapping(self, mapping: m) }
        handler.beginElement(self, name: SAXNSName(name: tagName), attributes: fAttribs)
    }

    /*===========================================================================================================================================================================*/
    /// Call the handler's `endElement(_:name:)` and `endPrefixMapping(_:prefix:)` methods. If needed, one or more calls to `endPrefixMapping(_:prefix:)` will be made **AFTER**
    /// the call to `endElement(_:name:)`.
    ///
    /// - Parameter tagName: The name of the element.
    /// - Throws: If an I/O error occurs.
    ///
    private func callElementEndHandler(tagName: String) throws {
        handler.endElement(self, name: SAXNSName(name: tagName))
        if let e = namespaceStack.popLast() { for m in e.sorted().reversed() { handler.endPrefixMapping(self, prefix: m.prefix) } }
    }

    /*===========================================================================================================================================================================*/
    /// Handle the body of an element.
    ///
    /// - Parameters:
    ///   - tagName: The name of the element.
    ///   - attr: The attributes of the element.
    /// - Throws: If an I/O error occurs or anything in the body of the element is malformed.
    ///
    private func handleElementBody(tagName: String, attributes attr: SAXRawAttribList) throws {
        markSet()
        defer { markDelete() }
        var text: [Character] = []

        while var ch = try inputStream.read() {
            switch ch {
                case "<":
                    handler.text(self, content: String(text))
                    text.removeAll(keepingCapacity: true)
                    ch = try readX()

                    switch ch {
                        case "!":
                            ch = try readX()
                            switch ch {
                                case "-":
                                    markBackup(count: 3)
                                    try handleComment()
                                case "[":
                                    markBackup(count: 3)
                                    try handleCDataSection()
                                default:
                                    throw unexpectedCharacterError(character: ch)
                            }
                        case "?":
                            markBackup(count: 2)
                            try handleProcessingInstruction()
                        case "/":
                            markBackup(count: 2)
                            try handleClosingTag(tagName: tagName)
                        default:
                            guard ch.isXmlNameStartChar else { throw unexpectedCharacterError(character: ch) }
                            markBackup(count: 2)
                            try handleNestedElement()
                    }
                case "&":
                    text.append(contentsOf: try readEntityChar())
                default:
                    text <+ ch
            }
        }
    }

    /*===========================================================================================================================================================================*/
    /// Handle an element closing tag.
    ///
    /// - Parameter tagName: The name of the tag it should be.
    /// - Throws: If an I/O error occurs, the closing tag is malformed, or the name of the closing tag is not correct.
    ///
    private func handleClosingTag(tagName: String) throws {
        var buffer: [Character] = []
        guard try inputStream.read(chars: &buffer, maxLength: 3) == 3 else { throw SAXError.getUnexpectedEndOfInput() }

        var ch = buffer.popLast()!
        guard buffer == "</" else { throw SAXError.getMalformedDocument(markBackup(count: 3), description: "Invalid closing tag.") }
        guard ch.isXmlNameStartChar else { throw unexpectedCharacterError(character: ch) }

        buffer = [ ch ]
        repeat {
            ch = try readX()
            guard ch.isXmlNameChar else {
                while ch.isXmlWhitespace { ch = try readX() }
                guard ch == ">" else { throw unexpectedCharacterError(character: ch) }
                guard String(buffer) == tagName else { throw SAXError.getMalformedDocument(markBackup(), description: "Unexpected closing tag: \"\(String(buffer))\" != \"\(tagName)\"") }
                break
            }
            buffer <+ ch
        } while true
    }

    /*===========================================================================================================================================================================*/
    /// Handle a CDATA section.
    ///
    /// - Throws: If an I/O error occurs or the CDATA section is malformed.
    ///
    private func handleCDataSection() throws {
        let openMarker:      String      = "<![CDATA["
        let openMarkerCount: Int         = openMarker.count
        var buffer:          [Character] = []

        guard try inputStream.read(chars: &buffer, maxLength: openMarkerCount) == openMarkerCount else { throw SAXError.getUnexpectedEndOfInput() }
        guard buffer == openMarker else { throw SAXError.getMalformedCDATASection(markBackup(count: openMarkerCount), description: "Not a CDATA Section starting tag: \"\(String(buffer))\"") }

        buffer.removeAll()
        while let ch = try inputStream.read() {
            if ch == ">" && buffer.last(count: 2) == "]]" {
                buffer.removeLast(2)
                handler.cdataSection(self, content: String(buffer))
                return
            }
            buffer <+ ch
        }
        throw SAXError.getUnexpectedEndOfInput()
    }

    /*===========================================================================================================================================================================*/
    /// Get an Unexpected Character message.
    ///
    /// - Parameter ch: The character that was unexpected.
    /// - Returns: The message.
    ///
    @inlinable func unexpectedCharMessage(character ch: Character) -> String { "Unexpected character: \"\(ch)\"" }

    /*===========================================================================================================================================================================*/
    /// Get an `Unexpected Character` error.
    ///
    /// - Parameter ch: The character that was unexpected.
    /// - Returns: The error.
    ///
    @inlinable func unexpectedCharacterError(character ch: Character) -> SAXError { SAXError.getMalformedDocument(markBackup(), description: unexpectedCharMessage(character: ch)) }

    /*===========================================================================================================================================================================*/
    /// Get an `Unexpected Character` error.
    ///
    /// - Returns: The error.
    ///
    @inlinable func unexpectedCharacterError() -> SAXError {
        do {
            markBackup()
            return unexpectedCharacterError(character: try readX())
        }
        catch {
            return SAXError.getMalformedDocument(markBackup(), description: "Unexpected Error")
        }
    }

    /*===========================================================================================================================================================================*/
    /// Parse a processing instruction.
    ///
    /// - Throws: If there is an I/O error or the comment is malformed.
    ///
    private func handleProcessingInstruction() throws {
        let pi = try readProcessingInstruction()
        handler.processingInstruction(self, target: pi.target, data: pi.data)
    }

    /*===========================================================================================================================================================================*/
    /// Read a processing instruction from the input stream.
    ///
    /// - Returns: A tuple containing the processing instruction target and data.
    /// - Throws: If an I/O error occurs or the processing instruction is malformed.
    ///
    private func readProcessingInstruction() throws -> (target: String, data: String) {
        var buffer: [Character] = []

        guard try inputStream.read(chars: &buffer, maxLength: 3) == 3, buffer[0 ..< 2] == "<?" else { throw SAXError.getMalformedProcInst(markReset(), description: String(buffer)) }

        while let ch = try inputStream.read() {
            buffer <+ ch
            if buffer.last(count: 2) == "?>" {
                let pi = String(buffer)
                let pt = "^<\\?(\(rxNamePattern))\(rxWhitespacePattern)(.*?)\\?>$"
                guard let m = GetRegularExpression(pattern: pt).firstMatch(in: pi) else { throw SAXError.getMalformedProcInst(markReset(), description: pi) }
                guard let t = m[1].subString, let d = m[2].subString else { throw SAXError.getMalformedProcInst(markReset(), description: pi) }
                return (target: t, data: d)
            }
        }
        throw SAXError.getUnexpectedEndOfInput()
    }

    /*===========================================================================================================================================================================*/
    /// Parse a comment.
    ///
    /// - Throws: If there is an I/O error or the comment is malformed.
    ///
    private func handleComment() throws {
        let dd:     [Character] = [ "-", "-" ]
        var buffer: [Character] = []

        guard try inputStream.read(chars: &buffer, maxLength: 4) == 4 else { throw SAXError.getUnexpectedEndOfInput() }
        guard buffer == "<!--" else { throw SAXError.getMalformedComment(markReset(), description: "Bad comment opening: \"\(String(buffer))\"") }

        markUpdate()
        guard try inputStream.read(chars: &buffer, maxLength: 3) == 3 else { throw SAXError.getUnexpectedEndOfInput() }

        if buffer == "-->" {
            // Handle an empty comment node.
            markUpdate()
            handler.comment(self, content: "")
            return
        }

        guard buffer[0 ..< 2] == dd else { throw SAXError.getMalformedComment(markBackup(count: 2), description: "Comment cannot contain double minus (-) signs.") }

        while let ch = try inputStream.read() {
            if buffer.last(count: 2) == dd {
                guard ch == ">" else { throw SAXError.getMalformedComment(markBackup(count: 2), description: "Comment cannot contain double minus (-) signs.") }
                handler.comment(self, content: String(buffer[buffer.startIndex ..< (buffer.endIndex - 2)]))
                return
            }
            buffer <+ ch
        }
    }

    /*===========================================================================================================================================================================*/
    /// Parse the document's XML Declaration.
    ///
    /// - Throws: If an I/O error occured or the XML Declaration was malformed.
    ///
    private func getXmlDeclaration() throws {
        markSet()
        defer { markDelete() }

        let pi = try _getXmlDeclaration()
        if pi.bad { throw SAXError.getMalformedXmlDecl(markReset(), description: "<?\(pi.target) \(pi.data)?>") }
    }

    private func _getXmlDeclaration() throws -> (bad: Bool, target: String, data: String) {
        do {
            var bad: Bool = false
            let pi        = try readProcessingInstruction()
            guard pi.target.lowercased() == "xml" else { markReset(); return (bad, "", "") }

            GetRegularExpression(pattern: "\\s+(\(rxNamePattern))=(?:'([^']*)'|\"([^\"]*)\")").forEachMatch(in: " \(pi.data)") { (m: RegularExpression.Match?, _, stop: inout Bool) in
                if let m = m, let k = m[1].subString, let v = (m[2].subString ?? m[3].subString) {
                    if _populateXmlDeclFields(key: k, value: v) {
                        stop = true
                        bad = true
                    }
                }
            }

            return (bad, pi.target, pi.data)
        }
        catch SAXError.UnexpectedEndOfInput(position: let pos, description: let description) {
            throw SAXError.UnexpectedEndOfInput(position: pos, description: description)
        }
        catch {
            return (false, "", "")
        }
    }

    @inlinable final func _populateXmlDeclFields(key k: String, value v: String) -> Bool {
        switch k {
            case "version":
                guard value(v, isOneOf: "1.0", "1.1") else { return true }
                _xmlVersion = v
            case "encoding":
                // This is just for show. The encoding has already been determined.
                _xmlEncoding = v
            case "standalone":
                let val = v.lowercased()
                guard value(val, isOneOf: "yes", "no") else { return true }
                _xmlIsStandalone = (val == "yes")
            default:
                return true
        }
        return false
    }

    /*===========================================================================================================================================================================*/
    /// Read the next character from the input stream.
    ///
    /// - Returns: The next character
    /// - Throws: If an I/O error occurs or if the EOF has been found.
    ///
    @inlinable final func readX(leadingWhitespace lws: LeadingWhitespace = .None) throws -> Character {
        guard let ch = try read(leadingWhitespace: lws) else { throw SAXError.getUnexpectedEndOfInput() }
        return ch
    }

    /*===========================================================================================================================================================================*/
    /// Read the next character from the input stream.
    ///
    /// - Returns: The next character or `nil` if the EOF has been found.
    /// - Throws: If an I/O error occurs.
    ///
    @inlinable final func read(leadingWhitespace lws: LeadingWhitespace = .None) throws -> Character? {
        if lws != .None { try readWhitespace(isRequired: (lws == .Required)) }
        return try inputStream.read()
    }

    /*===========================================================================================================================================================================*/
    /// Mark Set
    ///
    @discardableResult @inlinable final func markSet() -> SAXCharInputStream { inputStream.markSet(); return inputStream }

    /*===========================================================================================================================================================================*/
    /// Mark Delete
    ///
    /// - Returns: The input stream.
    ///
    @discardableResult @inlinable final func markDelete() -> SAXCharInputStream { inputStream.markDelete(); return inputStream }

    /*===========================================================================================================================================================================*/
    /// Mark Return
    ///
    /// - Returns: The input stream.
    ///
    @discardableResult @inlinable final func markReturn() -> SAXCharInputStream { inputStream.markReturn(); return inputStream }

    /*===========================================================================================================================================================================*/
    /// Mark Reset
    ///
    /// - Returns: The input stream.
    ///
    @discardableResult @inlinable final func markReset() -> SAXCharInputStream { inputStream.markReset(); return inputStream }

    /*===========================================================================================================================================================================*/
    /// Mark Update
    ///
    /// - Returns: The input stream.
    ///
    @discardableResult @inlinable final func markUpdate() -> SAXCharInputStream { inputStream.markUpdate(); return inputStream }

    /*===========================================================================================================================================================================*/
    /// Mark Backup
    ///
    /// - Parameter count: The number of characters to back up.
    /// - Returns: The number of characters actually backed up.
    ///
    @discardableResult @inlinable final func markBackup(count: Int = 1) -> SAXCharInputStream { inputStream.markBackup(count: count); return inputStream }

    /*===========================================================================================================================================================================*/
    /// Get and return the next character in the input stream only if it is one of the allowed characters.
    ///
    /// - Parameters:
    ///   - errorOnEOF: If `true` then an error will be thrown if the EOF is found. The default is `false`.
    ///   - chars: The allowed characters.
    /// - Returns: The character or `nil` if the next character would not have been one of the allowed characters or if `errorOnEOF` is `true` and there was no next character.
    /// - Throws: If there was an I/O error or `errorOnEOF` is `true` and the EOF was found.
    ///
    @discardableResult @inlinable final func getChar(errorOnEOF: Bool = false, leadingWhitespace lws: LeadingWhitespace = .None, allowed chars: Character...) throws -> Character? {
        try getChar(errorOnEOF: errorOnEOF, leadingWhitespace: lws) { chars.contains($0) }
    }

    /*===========================================================================================================================================================================*/
    /// Get and return the next character in the input stream only if it passes the test.
    ///
    /// - Parameters:
    ///   - errorOnEOF: If `true` then an error will be thrown if the EOF is found. The default is `false`.
    ///   - test: The closure used to test the character.
    /// - Returns: The character or `nil` if the character did not pass the test.
    /// - Throws: If an I/O error occurs.
    ///
    @discardableResult @inlinable final func getChar(errorOnEOF: Bool = false, leadingWhitespace lws: LeadingWhitespace = .None, test: (Character) throws -> Bool) throws -> Character? {
        if lws != .None { try readWhitespace(isRequired: (lws == .Required)) }
        guard let ch = try inputStream.peek() else {
            if errorOnEOF { throw SAXError.getUnexpectedEndOfInput() }
            return nil
        }
        guard try test(ch) else { return nil }
        return try inputStream.read()
    }

    @inlinable final func readSystemID(leadingWhitespace lws: LeadingWhitespace = .Required) throws -> URL {
        guard let ur = try nextQuotedValue(leadingWhitespace: lws) else { throw SAXError.getMalformedDocType(markReset(), description: "Missing System ID") }
        return try GetURL(string: ur)
    }

    /*===========================================================================================================================================================================*/
    /// Read and return any whitespace characters that are next in the input stream.
    ///
    /// - Parameter isRequired: If `true` then at least one whitespace character is required.
    /// - Returns: A string containing the whitespace characters. May be an empty string.
    /// - Throws: If an I/O error occurs or `isRequired` is `true` and no whitespace characters were found.
    ///
    @discardableResult @usableFromInline func readWhitespace(isRequired f: Bool = false) throws -> Bool {
        markUpdate()
        if let ch = try inputStream.read() {
            // We got at least one character.
            if ch.isXmlWhitespace {
                // We got at least one whitespace character.
                while let ch = try inputStream.read(), ch.isXmlWhitespace {}
                markBackup()
                return true
            }
            markBackup()
            if f { throw SAXError.getMissingWhitespace(markBackup()) }
        }
        return false
    }

    /*===========================================================================================================================================================================*/
    /// Read the next identifier from the input stream. An identifer starts with an XML Name Start Char and then zero or more XML Name Chars.
    ///
    /// - Returns: The identifier or `nil` if there is no identifier.
    /// - Throws: If an I/O error occurs.
    ///
    @usableFromInline func nextIdentifier(leadingWhitespace lws: LeadingWhitespace = .Allowed) throws -> String? {
        if lws != .None { try readWhitespace(isRequired: (lws == .Required)) }
        markUpdate()
        guard let ch1 = try inputStream.read(), ch1.isXmlNameStartChar else { markBackup(); return nil }
        var buffer: [Character] = [ ch1 ]

        while let ch2 = try inputStream.read() {
            guard ch2.isXmlNameChar else { markBackup(); break }
            buffer <+ ch2
        }

        return String(buffer)
    }

    /*===========================================================================================================================================================================*/
    /// Read the next quoted value from the input stream.
    ///
    /// - Returns: The value without the quotes.
    /// - Throws: If an I/O error occurs or if the EOF is found before the closing quote.
    ///
    @usableFromInline func nextQuotedValue(leadingWhitespace lws: LeadingWhitespace = .None) throws -> String? {
        guard let quote = try getChar(leadingWhitespace: lws, allowed: "\"", "'") else { return nil }
        var buffer: [Character] = []

        while let ch = try inputStream.read() {
            if ch == quote { return String(buffer) }
            else if ch == "&" { buffer.append(contentsOf: try readEntityChar()) }
            else { buffer <+ ch }
        }

        throw SAXError.getUnexpectedEndOfInput()
    }

    /*===========================================================================================================================================================================*/
    /// Read the next parameter. A parameter consists of an identifier and a quoted value separated by an equals sign (=).
    ///
    /// - Returns: An instance of KVPair or `nil` if there is no parameter.
    /// - Throws: If an I/O error occurs or if the EOF is found before the closing quote on the parameter quoted value.
    ///
    @usableFromInline func nextParameter(leadingWhitespace lws: LeadingWhitespace = .Allowed) throws -> KVPair? {
        guard let key = try nextIdentifier(leadingWhitespace: lws) else { return nil }
        let ch = try inputStream.read()
        guard ch == "=" else { return nil }
        guard let value = try nextQuotedValue() else { return nil }
        return KVPair(key: key, value: value)
    }

    /*===========================================================================================================================================================================*/
    /// Complete an entity character by reading the name from the input stream and returning it's character value.
    ///
    /// - Returns: The entity character.
    /// - Throws: If an I/O error occurs.
    ///
    @usableFromInline func readEntityChar() throws -> String {
        markSet()
        defer { markDelete() }

        var buffer: [Character] = []

        while let ch = try inputStream.read() {
            if ch == ";" {
                switch String(buffer) {
                    case "quot": return "\""
                    case "lt":   return "<"
                    case "gt":   return ">"
                    case "apos": return "'"
                    case "amp":  return "&"
                  // TODO: Handle DTD defined character entities.
                    default:     markReset(); return "&"
                }
            }
            buffer <+ ch
        }

        markReset()
        return "&"
    }
}
