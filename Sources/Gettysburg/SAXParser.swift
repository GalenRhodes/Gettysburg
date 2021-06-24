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

    public init(inputStream: InputStream, url: URL, handler: SAXHandler) throws {
        self.inputStream = try SAXCharInputStreamStack(initialInputStream: inputStream, url: url)
        self._xmlEncoding = self.inputStream.encodingName
        self.handler = handler
    }

    public convenience init(url: URL, handler: SAXHandler) throws {
        guard let _is = InputStream(url: url) else { throw StreamError.FileNotFound(description: url.absoluteString) }
        try self.init(inputStream: _is, url: url.absoluteURL, handler: handler)
    }

    public convenience init(fileAtPath: String, handler: SAXHandler) throws {
        guard let _is = InputStream(fileAtPath: fileAtPath) else { throw StreamError.FileNotFound(description: fileAtPath) }
        try self.init(inputStream: _is, url: GetFileURL(filename: fileAtPath), handler: handler)
    }

    public convenience init(data: Data, url: URL? = nil, handler: SAXHandler) throws {
        let _url = (url ?? URL(fileURLWithPath: "temp_\(UUID().uuidString).xml", isDirectory: false, relativeTo: GetCurrDirURL()))
        try self.init(inputStream: InputStream(data: data), url: _url, handler: handler)
    }

    /*===========================================================================================================================================================================*/
    /// Parse the XML document from the given input stream.
    /// 
    /// It should be noted that the only text that should exist at the root of the document is whitespace.
    /// 
    /// - Throws: If an error occured.
    ///
    open func parse() throws {
        do {
            inputStream.open()
            inputStream.markSet()
            defer {
                inputStream.markDelete()
                inputStream.close()
            }

            var hasDocType:     Bool = false
            var hasRootElement: Bool = false

            while let ch = try inputStream.read() {
                switch ch {
                    case "<": try parseRootNode(&hasRootElement, &hasDocType)
                    default:  guard ch.isXmlWhitespace else { throw SAXError.getMalformedDocument(inputStream, description: ExpMsg(ERRMSG_ILLEGAL_CHAR, got: ch)) }
                }
                inputStream.markClear()
            }
        }
        catch let e {
            guard handler.handleError(self, error: e) else { throw e }
        }
    }

    /*===========================================================================================================================================================================*/
    /// Parse a comment, processing instruction, DOCTYPE, or element that appears in the root of the document.
    /// 
    /// - Parameters:
    ///   - hasRootElement:
    ///   - hasDocType:
    /// - Throws: If an I/O error occurs or if the root node is malformed.
    ///
    private func parseRootNode(_ hasRootElement: inout Bool, _ hasDocType: inout Bool) throws {
        guard let ch = try inputStream.read() else { throw SAXError.getUnexpectedEndOfInput() }

        switch ch {
            case "!":
                try parseRootCommentOrDocType(hasRootElement: hasRootElement, hasDocType: &hasDocType)
            case "?":
                inputStream.markBackup(count: 2)
                try parseProcessingInstruction()
            default: // TODO: Element
                guard ch.isXmlNameStartChar else { throw SAXError.getMalformedDocument(inputStream, description: ExpMsg(ERRMSG_ILLEGAL_CHAR, got: ch)) }
                guard !hasRootElement else { throw SAXError.getMalformedDocument(inputStream, description: "Document already has a root element.") }
                inputStream.markBackup(count: 2)
                try parseElement()
                hasRootElement = true
        }
    }

    /*===========================================================================================================================================================================*/
    /// Parse a DOCTYPE node or a comment that appears in the root of the document.
    /// 
    /// - Parameters:
    ///   - hasRootElement: `true` if the root element has already been parsed.
    ///   - hasDocType: R/W value that is `true` if the DOCTYPE element has already been parsed.
    /// - Throws: If an I/O error occurs or if the root node is malformed.
    ///
    private func parseRootCommentOrDocType(hasRootElement: Bool, hasDocType: inout Bool) throws {
        guard let ch = try inputStream.read() else { throw SAXError.getUnexpectedEndOfInput() }

        switch ch {
            case "-":
                inputStream.markBackup(count: 3)
                try parseComment(inputStream: inputStream)
            case "D":
                inputStream.markBackup(count: 3)
                try parseDocTypeNode(hasRootElement: hasRootElement, hasDocType: &hasDocType)
            default:
                inputStream.markBackup()
                throw SAXError.getMalformedDocument(inputStream, description: ExpMsg(ERRMSG_ILLEGAL_CHAR, expected: "-", "D", got: ch))
        }
    }

    /*===========================================================================================================================================================================*/
    /// Parse a processing instruction.
    /// 
    /// - Throws: If an I/O error occurs, the EOF is encountered, or the processing instruction is malformed.
    ///
    func parseProcessingInstruction() throws {
        defer { inputStream.markClear() }
        let opening = try inputStream.readString(count: 2)
        try test(inputStream, err: .MalformedProcInst, expected: "<?", got: opening)
        let body = try inputStream.readUntil(found: "?", ">")
        guard let m = GetRegularExpression(pattern: RX_PROC_INST).firstMatch(in: body) else { throw SAXError.getMalformedProcInst(inputStream, description: "<?\(body.noLF())?>") }
        guard let target = m[1].subString else { fatalError(ERRMSG_RX) }
        guard let data = m[2].subString else { fatalError(ERRMSG_RX) }

        if target.lowercased() == "xml" { setXmlDecl(try parseXmlDecl(data)) }
        else { handler.processingInstruction(self, target: target, data: data) }
    }

    /*===========================================================================================================================================================================*/
    /// Set the XML Decl fields from an instance of XMLDeclData.
    /// 
    /// - Parameter xmlDecl: An instance of XMLDeclData.
    ///
    private func setXmlDecl(_ xmlDecl: XMLDeclData) {
        if let s = xmlDecl.version { _xmlVersion = s }
        if let s = xmlDecl.encoding { _xmlEncoding = s }
        if let s = xmlDecl.standalone { _xmlIsStandalone = s }
    }

    /*===========================================================================================================================================================================*/
    /// Parse the XML Declaration.
    /// 
    /// - Parameter data: The body of the XML Declaration processing instruction.
    /// - Returns: An instance of XMLDeclData containing the information from the XML Declaration.
    /// - Throws: If the XML Declaration is malformed.
    ///
    func parseXmlDecl(_ data: String) throws -> XMLDeclData {
        let rx                  = GetRegularExpression(pattern: RX_XML_DECL)
        var err:        Error?  = nil
        var version:    String? = nil
        var encoding:   String? = nil
        var standalone: Bool?   = nil

        rx.forEachMatch(in: " \(data)") { match, _, stop in
            if let m = match {
                switch m[1].subString {
                    case "version":    if version == nil { version = m[2].subString?.deQuoted() }
                    case "encoding":   if encoding == nil { encoding = m[2].subString?.deQuoted() }
                    case "standalone": if standalone == nil { if let s = m[2].subString?.deQuoted().lowercased() { if value(s, isOneOf: "yes", "no") { standalone = (s == "yes") } } }
                    default:
                        err = SAXError.getMalformedProcInst(inputStream, description: "Unknown parameter: \(m.subString)")
                        stop = true
                }
            }
        }

        if let e = err { throw e }
        nDebug(.None, "XML DECL: version=\(version?.quoted() ?? "nil"); encoding=\(encoding?.quoted() ?? "nil"); standalone=\(standalone?.description.quoted() ?? "nil")")
        return XMLDeclData(version: version, encoding: encoding, standalone: standalone)
    }

    /*===========================================================================================================================================================================*/
    /// Handle the DOCTYPE element.
    /// 
    /// - Parameters:
    ///   - hasRootElement: `true` if the root element has already been parsed.
    ///   - hasDocType: R/W value that is `true` if the DOCTYPE element has already been parsed.
    /// - Throws: If an I/O error occured, the DOCTYPE is malformed, the root element or the DOCTYPE has already been parsed, or the EOF is encountered.
    ///
    private func parseDocTypeNode(hasRootElement: Bool, hasDocType: inout Bool) throws {
        defer { inputStream.markClear() }

        let opening = try inputStream.readString(count: 9)
        try test(inputStream, err: .MalformedDocument, expected: "<!DOCTYPE", got: opening)
        if hasRootElement { throw SAXError.getMalformedDocument(inputStream, description: "DOCTYPE not expected here.") }
        if hasDocType { throw SAXError.getMalformedDocument(inputStream, description: "Document already has a DOCTYPE.") }

        inputStream.markClear()
        let header = try readDocTypeHeader()

        if let m = GetRegularExpression(pattern: RX_DOCTYPE[0]).firstMatch(in: header) {
            guard let elem = m[1].subString else { fatalError(ERRMSG_RX) }
            handler.beginDocType(self, elementName: elem)
            defer { handler.endDocType(self, elementName: elem) }
            try parseInternalDTD(rootElement: elem)
        }
        else if let m = GetRegularExpression(pattern: RX_DOCTYPE[1]).firstMatch(in: header) {
            guard let elem = m[1].subString else { fatalError(ERRMSG_RX) }
            guard let systemId = m[3].subString?.deQuoted() else { fatalError(ERRMSG_RX) }
            let hasInternal = (m[4].subString?.trimmed == "[")
            handler.beginDocType(self, elementName: elem)
            defer { handler.endDocType(self, elementName: elem) }
            try parseExternalDTD(rootElement: elem, publicID: nil, systemID: GetURL(string: systemId, relativeTo: baseURL))
            if hasInternal { try parseInternalDTD(rootElement: elem) }
        }
        else if let m = GetRegularExpression(pattern: RX_DOCTYPE[2]).firstMatch(in: header) {
            guard let elem = m[1].subString else { fatalError(ERRMSG_RX) }
            guard let publicId = m[3].subString?.deQuoted() else { fatalError(ERRMSG_RX) }
            guard let systemId = m[4].subString?.deQuoted() else { fatalError(ERRMSG_RX) }
            handler.beginDocType(self, elementName: elem)
            defer { handler.endDocType(self, elementName: elem) }
            try parseExternalDTD(rootElement: elem, publicID: publicId, systemID: GetURL(string: systemId, relativeTo: baseURL))
        }
        else {
            inputStream.markReset()
            throw SAXError.getMalformedDocType(inputStream, description: "Bad DOCTYPE opening.")
        }

        hasDocType = true
    }

    /*===========================================================================================================================================================================*/
    /// Reads everything past the "<!DOCTYPE" up to the first instance of "[" or ">".
    /// 
    /// - Returns: The string.
    /// - Throws: If an I/O error occurs or the EOF is encountered.
    ///
    private func readDocTypeHeader() throws -> String {
        inputStream.markSet()
        defer { inputStream.markDelete() }

        var buffer = Array<Character>()

        while let ch = try inputStream.read() {
            buffer <+ ch
            if value(ch, isOneOf: "[", ">") { return String(buffer) }
        }

        throw SAXError.getUnexpectedEndOfInput()
    }

    /*===========================================================================================================================================================================*/
    /// Parse the internal DTD.
    /// 
    /// - Parameter elem: The name of the root element.
    /// - Throws: If an I/O error occurs, the EOF is encountered before the end of the DTD, or the DTD is malformed.
    ///
    private func parseInternalDTD(rootElement elem: String) throws {
        handler.dtdInternal(self, elementName: elem)

        var buffer = Array<Character>()
        let pos    = inputStream.docPosition

        while let ch = try inputStream.read() {
            if ch == ">" && buffer.last == "]" {
                return try parseDTD(rootElement: elem, body: String(buffer.dropLast(1)), position: pos)
            }
            buffer <+ ch
        }

        throw SAXError.getUnexpectedEndOfInput()
    }

    /*===========================================================================================================================================================================*/
    /// Parse an external DTD.
    /// 
    /// - Parameters:
    ///   - elem: The name of the root document element.
    ///   - publicID: The public ID of the DTD or `nil` if this is a SYSTEM DTD.
    ///   - systemID: The system ID (URL) of the DTD.
    /// - Throws: If there is an I/O error or the DTD is malformed.
    ///
    private func parseExternalDTD(rootElement elem: String, publicID: String? = nil, systemID: URL) throws {
        handler.dtdExternal(self, elementName: elem, publicId: publicID, systemId: systemID.absoluteString)
        let body = try GetExternalFile(parentStream: inputStream, url: systemID)
        try parseDTD(rootElement: elem, body: body, publicID: publicID, systemID: systemID, position: StringPosition(url: systemID, line: 0, column: 0))
    }

    /*===========================================================================================================================================================================*/
    /// Parse the body of the DOCTYPE.
    /// 
    /// - Parameters:
    ///   - elem: The name of the root document element.
    ///   - body: The cache string containing the entire DTD.
    ///   - publicID: The public ID of the DTD or `nil` if there isn't one.
    ///   - systemID: The system ID of the DTD or `nil` if this is an internal DTD.
    ///   - pos: The position of the start of the DTD in the document.
    /// - Throws: If the DTD is malformed.
    ///
    private func parseDTD(rootElement elem: String, body: String, publicID: String? = nil, systemID: URL? = nil, position pos: DocPosition) throws {
        let pattern: String            = "<!--(.*?)-->|<!(ELEMENT|ENTITY|ATTLIST|NOTATION)(?:\\s+([^>]*))?>"
        let regex:   RegularExpression = GetRegularExpression(pattern: pattern, options: [ .dotMatchesLineSeparators ])
        var last:    String.Index      = body.startIndex
        var err:     Error?            = nil
        let pos:     DocPosition       = pos.mutableCopy()

        regex.forEachMatch(in: body) { m, _, quit in
            if let match = m {
                do {
                    try parseDTDChildNode(match: match, content: body, index: &last, position: pos, element: elem, publicID: publicID, systemID: systemID)
                }
                catch let e {
                    err = e
                    quit = true
                }
            }
        }

        if let e = err { throw e }
    }

    /*===========================================================================================================================================================================*/
    /// Parse a node within the DTD itself.
    /// 
    /// - Parameters:
    ///   - m: The RegularExpression.Match instance for the current DTD child node.
    ///   - str: The String containing the entire DTD.
    ///   - idx: The current index in str.
    ///   - pos: The current DocPosition in str.
    ///   - elem: The name of the root element in the document.
    ///   - pid: The public ID of the DTD.
    ///   - sid: The system ID of the DTD.
    /// - Throws: If the DTD child node is malformed.
    ///
    private func parseDTDChildNode(match m: RegularExpression.Match, content str: String, index idx: inout String.Index, position pos: DocPosition, element elem: String, publicID pid: String?, systemID sid: URL?) throws {
        try str[idx ..< m.range.lowerBound].forEach { ch in
            guard ch.isXmlWhitespace else { throw SAXError.MalformedDocType(position: pos, description: ExpMsg(ERRMSG_ILLEGAL_CHAR, got: ch)) }
            pos.positionUpdate(ch)
        }

        if let rComment = m[1].range {
            let comment = String(str[rComment])
            try parseDTDComment(str, index: m.range.lowerBound, comment: comment, range: rComment, position: pos)
        }
        else if let rType = m[2].range {
            let type = String(str[rType])
            if let rData = m[3].range {
                let rToData = (m.range.lowerBound ..< rData.lowerBound)
                let pData   = str[rToData].advance(position: pos)
                let sData   = String(str[rData]).trimmingCharacters(in: .XMLWhitespace)

                switch type {
                    case "ELEMENT":  try parseDTDElement(rootElement: elem, body: sData, publicID: pid, systemID: sid, position: pData)
                    case "ENTITY":   try parseDTDEntity(rootElement: elem, body: sData, publicID: pid, systemID: sid, position: pData)
                    case "ATTLIST":  try parseDTDAttList(rootElement: elem, body: sData, publicID: pid, systemID: sid, position: pData)
                    case "NOTATION": try parseDTDNotation(rootElement: elem, body: sData, publicID: pid, systemID: sid, position: pData)
                    default:         throw SAXError.MalformedDocType(position: pos, description: ExpMsg("Unknown DTD child element", expected: "ELEMENT", "ENTITY", "ATTLIST", "NOTATION", got: type))
                }
            }
            else {
                throw SAXError.MalformedDocType(position: pos, description: "Empty DTD \(type) Decl.")
            }
        }

        m.subString.advance(position: pos)
        idx = m.range.upperBound
    }

    /*===========================================================================================================================================================================*/
    /// Parse a comment from the cached DOCTYPE string.
    /// 
    /// - Parameters:
    ///   - src: The cache string.
    ///   - idx: The current index in the string.
    ///   - txt: The text of the comment.
    ///   - r: The range within src that contains the comment text.
    ///   - pos: The document position of the comment text.
    /// - Throws: MalformedComment if the comment contains two dashes next to each other.
    ///
    private func parseDTDComment(_ src: String, index idx: String.Index, comment txt: String, range r: Range<String.Index>, position pos: DocPosition) throws {
        if let rx = txt.range(of: "--") {
            let d = txt.distance(from: idx, to: rx.lowerBound)
            let p = src[idx ..< src.index(idx, offsetBy: d)].advance(position: pos.mutableCopy())
            throw SAXError.MalformedComment(position: p, description: ERRMSG_COMMENT_DASHES)
        }
        else if txt.hasSuffix("-") {
            let p = src[idx ..< r.lowerBound].advance(position: pos.mutableCopy())
            throw SAXError.MalformedComment(position: p, description: ERRMSG_COMMENT_DASHES)
        }
        else {
            handler.comment(self, content: txt)
        }
    }

    /*===========================================================================================================================================================================*/
    /// Parse a DTD element item.
    /// 
    /// - Parameters:
    ///   - elem: The name of the DOCTYPE element.
    ///   - body: The body of the DTD.
    ///   - publicID: The public ID of the DTD.
    ///   - systemID: The system ID of the DTD.
    ///   - pos: The position of the element item in the containing document.
    /// - Throws: If the element item is malformed.
    ///
    private func parseDTDElement(rootElement elem: String, body: String, publicID: String?, systemID: URL?, position pos: DocPosition) throws {
        guard let m = GetRegularExpression(pattern: RX_DTD_ELEMENT).firstMatch(in: body) else { throw SAXError.MalformedEntityDecl(position: pos, description: "<!ELEMENT \(body.noLF())>") }
        guard let name = m[1].subString else { fatalError("Incorrect ELEMENT REGEX") }
        guard let elst = m[2].subString else { fatalError("Incorrect ELEMENT REGEX") }
        let type = SAXElementAllowedContent.valueFor(description: elst)
        guard value(type, isOneOf: .Elements, .Mixed) else { return handler.dtdElementDecl(self, name: name, allowedContent: type, content: nil) }
        let pp    = body[body.startIndex ..< m[2].range!.lowerBound].advance(position: pos)
        let elems = try ParseDTDElementContentList(position: pp, list: elst)
        handler.dtdElementDecl(self, name: name, allowedContent: type, content: elems)
    }

    /*===========================================================================================================================================================================*/
    /// Parse a DTD attribute list item.
    /// 
    /// - Parameters:
    ///   - elem: The name of the DOCTYPE element.
    ///   - body: The body of the DTD.
    ///   - publicID: The public ID of the DTD.
    ///   - systemID: The system ID of the DTD.
    ///   - pos: The position of the attribute list item in the containing document.
    /// - Throws: If the attribute list item is malformed.
    ///
    private func parseDTDAttList(rootElement elem: String, body: String, publicID: String?, systemID: URL?, position pos: DocPosition) throws {
        guard let m = GetRegularExpression(pattern: RX_DTD_ATTLIST).firstMatch(in: body) else { throw SAXError.MalformedEntityDecl(position: pos, description: "<!ATTLIST \(body.noLF())>") }
        guard let elem = m[1].subString else { fatalError("Incorrect ATTLIST REGEX") }
        guard let name = m[2].subString else { fatalError("Incorrect ATTLIST REGEX") }
        guard let tpNm = m[3].subString, let type = SAXAttributeType.valueFor(description: tpNm) else { fatalError("Incorrect ATTLIST REGEX") }
        guard let defv = m[5].subString ?? m[4].subString else { fatalError("Incorrect ATTLIST REGEX") }

        handler.dtdAttributeDecl(self, name: name, elementName: elem, type: type, enumList: type.enumList(tpNm), defaultType: .valueFor(description: defv), defaultValue: m[6].subString)
    }

    /*===========================================================================================================================================================================*/
    /// Parse a DTD entity item.
    /// 
    /// - Parameters:
    ///   - elem: The name of the DOCTYPE element.
    ///   - body: The body of the DTD.
    ///   - publicID: The public ID of the DTD.
    ///   - systemID: The system ID of the DTD.
    ///   - pos: The position of the entity item in the containing document.
    /// - Throws: If the entity item is malformed.
    ///
    private func parseDTDEntity(rootElement elem: String, body: String, publicID: String?, systemID: URL?, position pos: DocPosition) throws {
        guard let m = GetRegularExpression(pattern: RX_DTD_ENTITY).firstMatch(in: body) else { throw SAXError.MalformedEntityDecl(position: pos, description: "<!ENTITY \(body.noLF())>") }

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
    /// Parse a DTD notation item.
    /// 
    /// - Parameters:
    ///   - elem: The name of the DOCTYPE element.
    ///   - body: The body of the DTD.
    ///   - publicID: The public ID of the DTD.
    ///   - systemID: The system ID of the DTD.
    ///   - pos: The position of the notation item in the containing document.
    /// - Throws: If the notation item is malformed.
    ///
    private func parseDTDNotation(rootElement elem: String, body: String, publicID: String?, systemID: URL?, position pos: DocPosition) throws {
        guard let m = GetRegularExpression(pattern: RX_DTD_NOTATION).firstMatch(in: body) else { throw SAXError.MalformedNotationDecl(position: pos, description: "<!NOTATION \(body.noLF())>") }
        guard let name = m[1].subString else { fatalError("Incorrect NOTATION REGEX") }
        guard let type = m[2].subString else { fatalError("Incorrect NOTATION REGEX") }
        guard let prm1 = m[3].subString?.deQuoted() else { fatalError("Incorrect NOTATION REGEX") }
        let prm2 = m[4].subString?.deQuoted()

        switch type {
            case "SYSTEM":
                guard prm2 == nil else { throw SAXError.MalformedNotationDecl(position: pos, description: "Extra parameter in system notation: \(prm2!.quoted())") }
                handler.dtdNotationDecl(self, name: name, publicId: nil, systemId: prm1)
            case "PUBLIC":
                handler.dtdNotationDecl(self, name: name, publicId: prm1, systemId: prm2)
            default:
                throw SAXError.MalformedNotationDecl(position: pos, description: "Invalid notation type: \(type.quoted())")
        }
    }

    /*===========================================================================================================================================================================*/
    /// Parse a comment from the given input stream.
    /// 
    /// - Parameter inputStream: The input stream.
    /// - Throws: If an I/O error occurs or the comment is malformed.
    ///
    private func parseComment(inputStream: SAXCharInputStream) throws {
        defer { inputStream.markClear() }

        let dd: [Character] = "--".getCharacters()
        var data            = Array<Character>()

        guard try inputStream.read(chars: &data, maxLength: 4) == 4 else { throw SAXError.getUnexpectedEndOfInput() }
        try test(inputStream, err: .MalformedComment, expected: "<!--", got: data)

        guard try inputStream.read(chars: &data, maxLength: 2) == 2 else { throw SAXError.getUnexpectedEndOfInput() }

        while let ch = try inputStream.read() {
            if data.last(count: 2) == dd {
                guard ch == ">" else { throw SAXError.getMalformedComment(inputStream, description: ERRMSG_COMMENT_DASHES) }
                return handler.comment(self, content: String(data.dropLast(2)))
            }
        }

        throw SAXError.getUnexpectedEndOfInput()
    }

    /*===========================================================================================================================================================================*/
    /// Parse element.
    /// 
    /// - Throws: If an I/O error occurs, the EOF is encountered, or the element is malformed.
    ///
    private func parseElement() throws {
        guard try inputStream.readChar() == "<" else { throw SAXError.getMalformedDocument(inputStream, description: ExpMsg(ERRMSG_ILLEGAL_CHAR, expected: "<", got: inputStream.last)) }
        let tagName = try inputStream.readIdentifier(err: .MalformedElement)
        let body    = try inputStream.readUntil(found: ">", err: .MalformedElement)
        let rx      = GetRegularExpression(pattern: "^\(RX_XML_DECL)*\(RX_SPCSQ)(/)?\\>$")

        guard let m = rx.firstMatch(in: "\(body)>") else { throw SAXError.getMalformedElement(inputStream, description: "<\(tagName)\(body.noLF().collapeWS())>") }

        //@f:0
        let hasBody    = !(m[3].subString == "/")
        let rx2        = GetRegularExpression(pattern: RX_XML_DECL)
        let rawAttribs = rx2.parse(from: body) { m, _ in SAXRawAttribute(name: m[1].subString!.splitPrefix(), value: m[2].subString!.deQuoted()) }
        let maps       = Array<NSMapping>(NSMappingList(rawAttribs.compactMap { NSMapping($0) }))
        let attribs    = SAXRawAttribList(rawAttribs.drop { (($0.name.prefix == "xmlns") || (($0.name.prefix == nil) && ($0.name.localName == "xmlns"))) })
        //@f:1

        maps.forEach { handler.beginPrefixMapping(self, mapping: $0) }
        handler.beginElement(self, name: SAXNSName(name: tagName), attributes: attribs)
        if hasBody {
            inputStream.markClear()
            try parseElementBody(tagName)
        }
        handler.endElement(self, name: SAXNSName(name: tagName))
        maps.reversed().forEach { handler.endPrefixMapping(self, prefix: $0.prefix) }
    }

    /*===========================================================================================================================================================================*/
    /// Parse the element body.
    /// 
    /// - Parameter tagName: The name of the node we're in.
    /// - Throws: If an I/O error occurs, the EOF is encountered, or something in the element's body is malformed.
    ///
    private func parseElementBody(_ tagName: String) throws {
        defer { inputStream.markClear() }
        var data = Array<Character>()

        while let ch = try inputStream.read() {
            switch ch {
                case "<":
                    handler.text(self, content: String(data))
                    data.removeAll()
                    guard let ch = try inputStream.read() else { throw SAXError.getUnexpectedEndOfInput() }

                    switch ch {
                        case "/":
                            let ident = try inputStream.readIdentifier(leadingWhitespace: .Allowed, err: .MalformedDocument)
                            guard ident == tagName else {
                                throw SAXError.getMalformedDocument(inputStream, description: ExpMsg("Incorrect name for closing tag", expected: tagName, got: ident))
                            }
                            guard try inputStream.readChar(leadingWhitespace: .Allowed) == ">" else {
                                throw SAXError.getMalformedElement(inputStream, description: ExpMsg(ERRMSG_ILLEGAL_CHAR, expected: ">", got: inputStream.last))
                            }
                            return
                        case "!":
                            break
                        case "?":
                            break
                        default:
                            break
                    }
                case "&":
                    handler.text(self, content: String(data))
                    data.removeAll()
                    inputStream.markBackup()
                    try parseEntity(inputStream)
                default:
                    data <+ ch
                    inputStream.markClear()
            }
        }

        throw SAXError.getUnexpectedEndOfInput()
    }

    private func parseEntity(_ inputStream: SAXCharInputStream) throws {
        guard try inputStream.readChar() == "&" else { throw SAXError.getMalformedEntityRef(inputStream, description: ExpMsg(ERRMSG_ILLEGAL_CHAR, expected: "&", got: inputStream.last)) }
        let name = try inputStream.readUntil(found: ";", mustHave: true, err: .MalformedEntityRef)

    }
}
