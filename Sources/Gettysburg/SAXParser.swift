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

            while let ch = try read() {
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
    func handleRootNodeItem(_ hasDocType: inout Bool, _ hasRootElem: inout Bool) throws {
        guard let ch = try read() else { throw SAXError.getUnexpectedEndOfInput() }

        switch ch {
            case "!":
                guard let ch = try read() else { throw SAXError.getUnexpectedEndOfInput() }
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

    func handleDocType() throws {
        var buffer: [Character] = []
        guard try read(chars: &buffer, count: 10) == 10 else { throw SAXError.getUnexpectedEndOfInput() }
        guard try String(buffer).matches(pattern: "^\\<\\!DOCTYPE\\s+") else { throw SAXError.getMalformedDocType(markReset(), description: "Not a DOCTYPE element: \"\(String(buffer))\"") }
        guard let elem = try nextIdentifier(leadingWhitespace: .Allowed)
    }

    /*===========================================================================================================================================================================*/
    /// Parse a nested element.
    ///
    /// - Throws: If there is an I/O error or the element is malformed.
    ///
    func handleNestedElement() throws {
        guard let ch = try read() else { return }
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
    func handleElementAttributes(tagName: String) throws {
        var attribs: SAXRawAttribList = []

        repeat {
            markUpdate()
            let ws = try readWhitespace()

            guard let ch = try read() else { throw SAXError.getUnexpectedEndOfInput() }

            if ch == ">" {
                try callElementBeginHandler(tagName: tagName, attributes: attribs)
                try handleElementBody(tagName: tagName, attributes: attribs)
                try callElementEndHandler(tagName: tagName)
                return
            }
            else if ch == "/" {
                guard let ch = try read() else { throw SAXError.getUnexpectedEndOfInput() }
                guard ch == ">" else { throw unexpectedCharacterError(character: ch) }
                try callElementBeginHandler(tagName: tagName, attributes: attribs)
                try callElementEndHandler(tagName: tagName)
                // This is an empty element and has no body.
                return
            }
            else if ch.isXmlNameStartChar {
                guard ws.isNotEmpty else { throw SAXError.getMalformedDocument(markBackup(), description: "Whitespace was expected.") }
                markBackup()
                guard let key = try nextIdentifier() else { throw SAXError.getMalformedDocument(markBackup(), description: "Missing Attribute Name") }
                guard let ch = try read() else { throw SAXError.getUnexpectedEndOfInput() }
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
    func callElementBeginHandler(tagName: String, attributes attribs: SAXRawAttribList) throws {
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
    func callElementEndHandler(tagName: String) throws {
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
    func handleElementBody(tagName: String, attributes attr: SAXRawAttribList) throws {
        markSet()
        defer { markDelete() }
        var text: [Character] = []

        while var ch = try read() {
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

    /// Handle an element closing tag.
    ///
    /// - Parameter tagName: The name of the tag it should be.
    /// - Throws: If an I/O error occurs, the closing tag is malformed, or the name of the closing tag is not correct.
    ///
    func handleClosingTag(tagName: String) throws {
        var buffer: [Character] = []
        guard try read(chars: &buffer, count: 3) == 3 else { throw SAXError.getUnexpectedEndOfInput() }

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

    /// Handle a CDATA section.
    ///
    /// - Throws: If an I/O error occurs or the CDATA section is malformed.
    ///
    func handleCDataSection() throws {
        let openMarker:      String      = "<![CDATA["
        let openMarkerCount: Int         = openMarker.count
        var buffer:          [Character] = []

        guard try read(chars: &buffer, count: openMarkerCount) == openMarkerCount else { throw SAXError.getUnexpectedEndOfInput() }
        guard buffer == openMarker else { throw SAXError.getMalformedCDATASection(markBackup(count: openMarkerCount), description: "Not a CDATA Section starting tag: \"\(String(buffer))\"") }

        buffer.removeAll()
        while let ch = try read() {
            if ch == ">" && buffer.last(count: 2) == "]]" {
                buffer.removeLast(2)
                handler.cdataSection(self, content: String(buffer))
                return
            }
            buffer <+ ch
        }
        throw SAXError.getUnexpectedEndOfInput()
    }

    /// Get an `Unexpected Character` error.
    ///
    /// - Parameter ch: The character that was unexpected.
    /// - Returns: The error.
    ///
    @inlinable func unexpectedCharacterError(character ch: Character) -> SAXError { SAXError.getMalformedDocument(markBackup(), description: "Unexpected character: \"\(ch)\"") }

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
    func handleProcessingInstruction() throws {
        let pi = try readProcessingInstruction()
        handler.processingInstruction(self, target: pi.target, data: pi.data)
    }

    /// Read a processing instruction from the input stream.
    ///
    /// - Returns: A tuple containing the processing instruction target and data.
    /// - Throws: If an I/O error occurs or the processing instruction is malformed.
    ///
    func readProcessingInstruction() throws -> (target: String, data: String) {
        var buffer: [Character] = []

        guard try read(chars: &buffer, count: 3) == 3, buffer[0 ..< 2] == "<?" else { throw SAXError.getMalformedProcInst(markReset(), description: String(buffer)) }

        while let ch = try read() {
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
    func handleComment() throws {
        let dd:     [Character] = [ "-", "-" ]
        var buffer: [Character] = []

        guard try read(chars: &buffer, count: 4) == 4 else { throw SAXError.getUnexpectedEndOfInput() }
        guard buffer == "<!--" else { throw SAXError.getMalformedComment(markReset(), description: "Bad comment opening: \"\(String(buffer))\"") }

        markUpdate()
        guard try read(chars: &buffer, count: 3) == 3 else { throw SAXError.getUnexpectedEndOfInput() }

        if buffer == "-->" {
            // Handle an empty comment node.
            markUpdate()
            handler.comment(self, content: "")
            return
        }

        guard buffer[0 ..< 2] == dd else { throw unexpectedCharacterError(character: "-") }

        while let ch = try read() {
            if buffer.last(count: 2) == dd {
                guard ch == ">" else { throw unexpectedCharacterError(character: "-") }
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
    func getXmlDeclaration() throws {
        markSet()
        defer { markDelete() }

        let pi = try _getXmlDeclaration()
        if pi.bad { throw SAXError.getMalformedXmlDecl(markReset(), description: "<?\(pi.target) \(pi.data)?>") }
    }

    /*===========================================================================================================================================================================*/
    func _getXmlDeclaration() throws -> (bad: Bool, target: String, data: String) {
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

    /*===========================================================================================================================================================================*/
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
    @inlinable final func readX() throws -> Character {
        guard let ch = try inputStream.read() else { throw SAXError.getUnexpectedEndOfInput() }
        return ch
    }

    /*===========================================================================================================================================================================*/
    /// Read the next character from the input stream.
    ///
    /// - Returns: The next character or `nil` if the EOF has been found.
    /// - Throws: If an I/O error occurs.
    ///
    @inlinable final func read() throws -> Character? { try inputStream.read() }

    /*===========================================================================================================================================================================*/
    /// Read, but do not remove, the next character from the input stream.
    ///
    /// - Returns: The next character or `nil` if the EOF has been found.
    /// - Throws: If an I/O error occurs.
    ///
    @inlinable final func peek() throws -> Character? { try inputStream.peek() }

    /*===========================================================================================================================================================================*/
    /// Read the next `count` characters from the input stream.
    ///
    /// - Parameters:
    ///   - chars: The array to receive the characters. Any characters already in the array will be removed.
    ///   - count: The maximum number of characters to read.
    /// - Returns: The actual number of characters read which might be less than `count` if EOF is found.
    /// - Throws: If an I/O error occurs.
    ///
    @inlinable final func read(chars: inout [Character], count: Int) throws -> Int { try inputStream.read(chars: &chars, maxLength: count) }

    /*===========================================================================================================================================================================*/
    /// Read the next `count` characters from the input stream and append them to the given character array.
    ///
    /// - Parameters:
    ///   - chars: The array to receive the characters. Any characters already in the array will be preserved.
    ///   - count: The maximum number of characters to read.
    /// - Returns: The actual number of characters read which might be less than `count` if EOF is found.
    /// - Throws: If an I/O error occurs.
    ///
    @inlinable final func append(to chars: inout [Character], count: Int) throws -> Int { try inputStream.append(to: &chars, maxLength: count) }

    /*===========================================================================================================================================================================*/
    /// Mark Set
    ///
    @inlinable final func markSet() { inputStream.markSet() }

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
    @discardableResult @inlinable final func getChar(errorOnEOF: Bool = false, allowed chars: Character...) throws -> Character? { try getChar(errorOnEOF: errorOnEOF) { chars.contains($0) } }

    /*===========================================================================================================================================================================*/
    /// Get and return the next character in the input stream only if it passes the test.
    ///
    /// - Parameters:
    ///   - errorOnEOF: If `true` then an error will be thrown if the EOF is found. The default is `false`.
    ///   - test: The closure used to test the character.
    /// - Returns: The character or `nil` if the character did not pass the test.
    /// - Throws: If an I/O error occurs.
    ///
    @discardableResult @inlinable final func getChar(errorOnEOF: Bool = false, test: (Character) throws -> Bool) throws -> Character? {
        guard let ch = try peek() else {
            if errorOnEOF { throw SAXError.getUnexpectedEndOfInput() }
            return nil
        }
        guard try test(ch) else { return nil }
        return try read()
    }

    /*===========================================================================================================================================================================*/
    /// Read and return any whitespace characters that are next in the input stream.
    ///
    /// - Returns: A string containing the whitespace characters. May be an empty string.
    /// - Throws: If an I/O error occurs.
    ///
    @discardableResult func readWhitespace() throws -> String {
        var buffer: [Character] = []
        while let ch = try read() {
            guard ch.isXmlWhitespace else { markBackup(); break }
            buffer <+ ch
        }
        return String(buffer)
    }

    /*===========================================================================================================================================================================*/
    /// Read the next identifier from the input stream. An identifer starts with an XML Name Start Char and then zero or more XML Name Chars.
    ///
    /// - Returns: The identifier or `nil` if there is no identifier.
    /// - Throws: If an I/O error occurs.
    ///
    func nextIdentifier(leadingWhitespace: LeadingWhitespace = .Allowed) throws -> String? {
        if leadingWhitespace != .None {
            let ws = try readWhitespace()
            guard leadingWhitespace == .Allowed || ws.isNotEmpty else { throw SAXError.getMissingWhitespace(inputStream) }
        }

        guard let ch1 = try read(), ch1.isXmlNameStartChar else { markBackup(); return nil }
        var buffer: [Character] = [ ch1 ]

        while let ch2 = try read() {
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
    func nextQuotedValue() throws -> String? {
        guard let quote = try getChar(allowed: "\"", "'") else { return nil }

        var buffer: [Character] = []

        while let ch = try read() {
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
    func nextParameter(leadingWhitespace: LeadingWhitespace = .Allowed) throws -> KVPair? {
        guard let key = try nextIdentifier(leadingWhitespace: leadingWhitespace) else { return nil }
        let ch = try read()
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
    final func readEntityChar() throws -> String {
        markSet()
        defer { markDelete() }

        var buffer: [Character] = []

        while let ch = try read() {
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
