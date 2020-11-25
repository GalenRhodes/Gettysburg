/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: SAXParser.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 11/7/20
 *
 * Copyright © 2020 Galen Rhodes. All rights reserved.
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
import Rubicon

open class SAXParser {

    public var delegate: SAXParserDelegate? = nil
    public var isStrict: Bool               = true

    public private(set) var inputStream:  InputStream
    public private(set) var filename:     String
    public private(set) var xmlEncoding:  String.Encoding = .utf8
    public private(set) var xmlVersion:   String          = "1.0"
    public private(set) var isStandalone: Bool            = false

    public var line:   Int { _currPos.line }
    public var column: Int { _currPos.column }

    @usableFromInline var _currPos:         DocPosition      = (1, 1)
    @usableFromInline var _charInputStream: CharInputStream! = nil
    @usableFromInline var _elementStack:    [ElementInfo]    = []

    /*===========================================================================================================================*/
    /// Initialize the parser.
    ///
    /// - Parameters:
    ///   - inputStream: the input stream.
    ///   - filename: the filename.
    ///
    public init(inputStream: InputStream, filename: String? = nil) {
        self.inputStream = inputStream
        self.filename = (filename ?? "urn:\(UUID().uuidString)")
    }

    /*===========================================================================================================================*/
    /// Initialize the parser.
    ///
    /// - Parameter filename: the filename to read from.
    ///
    public convenience init?(filename: String) {
        guard let inputStream = InputStream(fileAtPath: filename) else { return nil }
        self.init(inputStream: inputStream, filename: filename)
    }

    /*===========================================================================================================================*/
    /// Initialize the parser.
    ///
    /// - Parameter url: the URL to read from.
    ///
    public convenience init?(url: URL) {
        guard let inputStream = InputStream(url: url) else { return nil }
        self.init(inputStream: inputStream, filename: url.description)
    }

    /*===========================================================================================================================*/
    /// Initialize the parser.
    ///
    /// - Parameters:
    ///   - data: the data object to read from.
    ///   - filename: the filename for the data.
    ///
    public convenience init(data: Data, filename: String? = nil) {
        self.init(inputStream: InputStream(data: data), filename: filename)
    }

    /*===========================================================================================================================*/
    /// Initialize the parser.
    ///
    /// - Parameters:
    ///   - data: the buffer to read the data from.
    ///   - filename: the filename for the data.
    ///
    public convenience init(data: UnsafeBufferPointer<UInt8>, filename: String? = nil) {
        self.init(inputStream: InputStream(data: Data(buffer: data)), filename: filename)
    }

    /*===========================================================================================================================*/
    /// Initialize the parser.
    ///
    /// - Parameters:
    ///   - data: the pointer to the data to read from.
    ///   - count: the number of bytes in the data.
    ///   - filename: the filename for the data.
    ///
    public convenience init(data: UnsafePointer<UInt8>, count: Int, filename: String? = nil) {
        self.init(inputStream: InputStream(data: Data(bytes: UnsafeRawPointer(data), count: count)), filename: filename)
    }

    /*===========================================================================================================================*/
    /// Parse the XML document.
    ///
    /// - Throws: if an error occurs during parsing.
    ///
    open func parse() throws {
        try createCharInputStream()
        //
        // There shouldn't be any preceeding whitespace in a proper XML document but we'll forgive it by just skipping over it.
        //
        try scanPastWhitespace()
        if let f = delegate?.parseStartDocument { f(self) }
        //
        // Now we're going to look to see if we have an XML declaration on this bugger. Example: <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        // The very first thing we better find is a less-than symbol `<`.  Anything else would mean a malformed document.
        //
        try xmlDeclCheck()

        //
        // Remember if we've already gotten the document element and/or the DTD.
        //
        var elementFlag: Bool                      = false
        var docTypeFlag: Bool                      = false
        var cp:          (Character?, DocPosition) = try getNextChar(false)

        while let ch = cp.0 {
            if ch.test(is: .xmlWhiteSpace) {
                unRead(cp: cp)
                try delegateIgnorableWhitespace()
            }
            else if ch == "<" {
                try parseRootNodes(pos: cp.1, docTypeFlag: &docTypeFlag, elementFlag: &elementFlag)
            }
            else {
                throw getUnexpectedCharError(char: (ch, cp.1))
            }

            cp = try getNextChar(false)
        }

        //
        // No more input.  We're done.
        //
        if let f = delegate?.parseEndDocument { f(self) }
    }

    /*===========================================================================================================================*/
    /// Parse an XML structure that begins with the less-than symbol (<).
    ///
    /// - Parameters:
    ///   - pos: The position of the less-than symbol in the document.
    ///   - docTypeFlag: DTD flag.
    ///   - elementFlag: Root Element Flag.
    /// - Throws: on error.
    ///
    @usableFromInline final func parseRootNodes(pos: DocPosition, docTypeFlag: inout Bool, elementFlag: inout Bool) throws {
        let (char, charPos) = try getNextChar()

        switch char {
            case "?":
                try parseAndDelegateProcessingInstruction()
            case "!":
                let strPos = try getString(count: 2)

                if strPos.string == "--" {
                    try parseAndDelegateComment()
                }
                else {
                    guard strPos.string == "DO" else { throw getMalformedError(expected: "--' or 'DO", got: strPos) }
                    guard !docTypeFlag else { throw getMalformedError(what: "another DTD element", pos: pos) }
                    try parseAndDelegateDocType()
                    docTypeFlag = true
                    return
                }
            default:
                //
                // Element?
                //
                unRead(char: char, pos: charPos)
                let nsName = try getNSNamePair()
                guard !elementFlag else { throw getMalformedError(what: "another element", pos: pos) }
                try parseAndDelegateElement(tagName: nsName)
                docTypeFlag = true
                elementFlag = true
        }
    }

    /*===========================================================================================================================*/
    /// Parse and delegate an element.
    ///
    /// - Throws: if an I/O error occurs or the element is malformed.
    ///
    @inlinable final func parseAndDelegateElement() throws {
        try parseAndDelegateElement(tagName: try getNSNamePair())
    }

    /*===========================================================================================================================*/
    /// Parse and delegate an element
    ///
    /// - Parameter tagName: the tag name of the element.
    /// - Throws: if an I/O error occurs or the element is malformed.
    ///
    @usableFromInline final func parseAndDelegateElement(tagName: NSName) throws {
        if let elem = try parseElementTag(tagName: tagName) {
            //
            // Now parse the body of the element?
            //
            try parseElementBody(elem: elem)
            //
            // Now parse the closing tag.
            //
            let p: DocPosition = _currPos
            let g: String      = try getElementClose()
            let w: String      = combine(tagName)

            guard g == w else { throw getBadClosingTag(wanted: w, got: g, pos: p) }
            delegateElementEnd(elementInfo: elem)
        }
    }

    /*===========================================================================================================================*/
    /// Parse and element.
    ///
    /// - Parameter tagName: the element tag name.
    /// - Returns: the element information.
    /// - Throws: if an I/O error occurs or the element is malformed.
    ///
    @usableFromInline final func parseElementTag(tagName: NSName) throws -> ElementInfo? {
        var attr: [NSAttribute] = []
        var char: CharPos       = try getNextChar()

        while char.0 != ">" {
            if char.0 == "/" {
                try delegateEmptyElement(tagName: tagName, namespaceURI: nil, attributes: attr)
                return nil
            }
            else if char.0.test(is: .xmlWhiteSpace) {
                try scanPastWhitespace()
            }
            else if char.0.test(is: .xmlNsNameStartChar) {
                unRead(cp: char)
                attr.append(try parseAttribute())
            }
            else {
                throw getUnexpectedCharError(char: char)
            }

            char = try getNextChar()
        }

        let elem = ElementInfo(tagName: tagName, stack: _elementStack, attributes: attr)
        delegateElementStart(elementInfo: elem)
        return elem
    }

    /*===========================================================================================================================*/
    /// Delegate and empty element.
    ///
    /// - Parameters:
    ///   - tagName: the elements tag name.
    ///   - attributes: the elements attributes.
    /// - Throws: if an I/O error occurs or the element is malformed.
    ///
    @usableFromInline final func delegateEmptyElement(tagName: NSName, namespaceURI uri: String?, attributes: [NSAttribute]) throws {
        let d = try getNextChar()
        guard d.0 == ">" else { throw getWrongCharError(wanted: ">", got: d) }
        let elem = ElementInfo(tagName: tagName, stack: _elementStack, attributes: attributes)
        delegateElementStart(elementInfo: elem)
        delegateElementEnd(elementInfo: elem)
    }

    /*===========================================================================================================================*/
    /// Get the closing element tag name.
    ///
    /// - Returns: the closing element tag name.
    /// - Throws: if an I/O error occurs or the element is malformed.
    ///
    @usableFromInline final func getElementClose() throws -> String {
        var chars: [Character] = []
        var char:  Character   = try getNextChar().0

        while char != ">" {
            chars.append(char)
            char = try getNextChar().0
        }

        return String(chars)
    }

    /*===========================================================================================================================*/
    /// Parse the element body.
    ///
    /// - Parameter elem: the element info.
    /// - Throws: if an I/O error occurs or the element is malformed.
    ///
    @usableFromInline final func parseElementBody(elem: ElementInfo) throws {
        var notDone: Bool = true
        while notDone {
            let (char, pos) = try getNextChar()
            if char == "<" { notDone = try parseElementBodyNode(elem: elem, pos: pos) }
            else { try parseAndDelegateCharacters() }
        }
    }

    /*===========================================================================================================================*/
    /// Parse the element body node.
    ///
    /// - Parameters:
    ///   - elem: the element info.
    ///   - pos: the starting position of the element body.
    /// - Returns: `false` if this is an empty element.
    /// - Throws: if an I/O error occurs or the element is malformed.
    ///
    @usableFromInline final func parseElementBodyNode(elem: ElementInfo, pos: DocPosition) throws -> Bool {
        let d = try getNextChar()
        switch d.0 {
            case "/": return false
            case "?": try parseAndDelegateProcessingInstruction()
            case "!": try parseExclamationPoint(pos: pos)
            default: try parseElementSub(elem: elem, char: d)
        }
        return true
    }

    /*===========================================================================================================================*/
    /// Parse the elements sub-element.
    ///
    /// - Parameters:
    ///   - elem: the element info.
    ///   - char: the first character of the sub-elements tag name.
    /// - Throws: if an I/O error occurs or the element is malformed.
    ///
    @inlinable final func parseElementSub(elem: ElementInfo, char: CharPos) throws {
        if char.0.test(is: .xmlNsNameStartChar) {
            unRead(cp: char)
            _elementStack.append(elem)
            try parseAndDelegateElement()
            _elementStack.removeLast()
        }
        else {
            throw getUnexpectedCharError(char: char)
        }
    }

    /*===========================================================================================================================*/
    /// Parse a node that starts with an exclamation point.
    ///
    /// - Parameter pos: the starting position of the node.
    /// - Throws: if an I/O error occurs or the element is malformed.
    ///
    @inlinable final func parseExclamationPoint(pos: DocPosition) throws {
        let s = try getString(count: 2).string

        if s == "--" {
            try parseAndDelegateComment()
        }
        else {
            let t = try (s + getString(count: 5).string)

            if t == "[CDATA[" { try parseAndDelegateCDataSection() }
            else { throw getMalformedSequence(seq: StringPos(string: "<!\(t)", pos: pos)) }
        }
    }

    /*===========================================================================================================================*/
    /// Parse and delegate a CData section node.
    ///
    /// - Throws: if an I/O error occurs or the element is malformed.
    ///
    @inlinable final func parseAndDelegateCDataSection() throws {
        var str = ""
        while !str.hasSuffix("]]>") { str += String(try getNextChar().0) }
        if let f = delegate?.parseCdataBlock { f(self, str.removeLast(count: 3)) }
    }

    /*===========================================================================================================================*/
    /// Parse and delegate a text node.
    ///
    /// - Throws: if an I/O error occurs or the element is malformed.
    ///
    @usableFromInline final func parseAndDelegateCharacters() throws {
        let str = try getString { _, c, a in c != "<" }
        if let f = delegate?.parseCharacters { f(self, str.string) }
    }

    /*===========================================================================================================================*/
    /// Delegate the element start.
    ///
    /// - Parameter elementInfo: the element info.
    ///
    @usableFromInline final func delegateElementStart(elementInfo: ElementInfo) {
        if let f = delegate?.parseStartElementNs {
            //
            // TODO: scan DTD for default attributes...
            // TODO: collect namespaces...
            //
            f(self, elementInfo.tagName.localName, elementInfo.tagName.prefix, elementInfo.namespaceURI, elementInfo.namespaces, elementInfo.saxAttributes)
        }
    }

    /*===========================================================================================================================*/
    /// Delegate the element end.
    ///
    /// - Parameter elementInfo: the element info.
    ///
    @usableFromInline final func delegateElementEnd(elementInfo: ElementInfo) {
        if let f = delegate?.parseEndElementNs { f(self, elementInfo.tagName.localName, elementInfo.tagName.prefix, elementInfo.namespaceURI) }
    }

    /*===========================================================================================================================*/
    /// Parse an element attribute.
    ///
    /// - Returns: the attribute.
    /// - Throws: if an I/O error occurs or if the attribute is malformed.
    ///
    @inlinable final func parseAttribute() throws -> NSAttribute {
        let aName = try getNSNamePair()
        try testNextChar { ch in (ch == "=") }
        let q = try testNextChar { ch in ch.isXmlQuote }
        let aValue = try getString(keepLast: true) { (i: Int, c: Character, a: inout [Character]) -> Bool in (c != q.0) }
        return (aName, StringPos(string: aValue.string.removeLast(count: 1), pos: aValue.pos))
    }

    /*===========================================================================================================================*/
    /// Parse and delegate the DTD.
    ///
    /// - Throws: if an I/O error occurs or the DTD is malformed.
    ///
    @usableFromInline final func parseAndDelegateDocType() throws {
        let s1 = "CTYPE"
        let s2 = try getString(count: 5)

        if s1 == s2.string {
            let ch = try getNextChar()
            guard ch.0.test(is: .xmlWhiteSpace) else { throw getUnexpectedCharError(char: ch) }
            let s3 = try getString(keepLast: true, body: { (i: Int, c: Character, a: inout [Character]) -> Bool in !((c == ">") && (i > 0) && (a[i - 1] == "]")) }).string
            try parseAndDelegateInternalSubset(s3.removeLast(count: 2))
        }
        else {
            throw getMalformedError(expected: s1, got: s2)
        }
    }

    /*===========================================================================================================================*/
    /// Parse and delegate an external subset.
    ///
    /// - Parameter str: the string containing the information about the external subset.
    /// - Throws: if the external subset cannot be found or is invalid.
    ///
    @usableFromInline final func parseAndDelegateExternalSubset(externalSubset str: String) throws {
        if let f = delegate?.parseExternalSubset { f(self, str, nil, nil) }
    }

    /*===========================================================================================================================*/
    /// Parse and delegate the internal subset.
    ///
    /// - Parameter str: the string containing the internal subset.
    /// - Throws: if the internal subset is invalid.
    ///
    @usableFromInline final func parseAndDelegateInternalSubset(_ str: String) throws {
        if let f = delegate?.parseInternalSubset { f(self, str, nil, nil) }
    }

    /*===========================================================================================================================*/
    /// Get the next `count` characters.
    ///
    /// - Parameter count: the number of characters to read.
    /// - Returns: the string of characters.
    /// - Throws: if an I/O error occurs or the EOF is reached before the desired number of characters are read.
    ///
    @usableFromInline final func getString(throwOnEOF: Bool = true, count: Int) throws -> StringPos {
        var chars: [Character] = []
        let pos                = _currPos
        for _ in (0 ..< count) { chars.append((try getNextChar()).0) }
        return StringPos(string: String(chars), pos: pos)
    }

    /*===========================================================================================================================*/
    /// Now we're going to look to see if we have an XML declaration on this bugger. Example: <?xml version="1.0" encoding="UTF-8"
    /// standalone="yes"?> The very first thing we better find is a less-than symbol `<`. Anything else would mean a malformed
    /// document.
    ///
    /// - Throws: if an I/O error occurs or the document is malformed.
    ///
    @usableFromInline final func xmlDeclCheck() throws {
        let str = try getString(count: 2)

        if str.string == "<?" {
            let (target, data) = try parseProcessingInstruction()
            //
            // If the target is "xml" then this is an XML declaration and we can extract the information from it.
            //
            if target.string == "xml" { try parseXmlDecl(content: data) }
            //
            // Otherwise treat it as a processing instruction by passing it to the delegate.
            //
            else if let f = delegate?.parseProcessingInstruction { f(self, target.string, data.string) }
        }
    }

    /*===========================================================================================================================*/
    /// Parse and send ignorable whitespace to the delegate.
    ///
    /// - Parameter char: the first ignorable whitespace character of this string.
    /// - Throws: if an I/O error occurs.
    ///
    @usableFromInline final func delegateIgnorableWhitespace() throws {
        let ws = try scanPastWhitespace()
        if let f = delegate?.parseIgnorableWhitespace { f(self, ws) }
    }

    /*===========================================================================================================================*/
    /// Parse and send a comment to the delegate.
    ///
    /// - Throws: if an I/O error occurs or the EOF is reached before the end of the comment is reached.
    ///
    @inlinable final func parseAndDelegateComment() throws {
        let comment: StringPos = try getString(keepLast: true) { (i, c, arr: inout [Character]) -> Bool in !((c == ">") && (i >= 2) && (String(arr[(i - 2) ..< i]) == "--")) }
        if let f = delegate?.parseComment { f(self, comment.string.removeLast(count: 3)) }
    }

    /*===========================================================================================================================*/
    /// Parse the XML declaration.
    ///
    /// - Parameter content: the content.
    /// - Throws: if the declaration is malformed.
    ///
    @usableFromInline final func parseXmlDecl(content: StringPos) throws {
        let kv = try parseKeyValueData(data: content)

        for (k, v) in kv {
            switch k.string {
                case "version":
                    guard v.string.isOneOf("1.0", "1.1") else { throw SAXError.UnsupportedVersion(description: v.string, pos: (v.pos.line, v.pos.column)) }
                    xmlVersion = v.string
                case "encoding":
                    //
                    // We're not really going to switch the encoding at this point because we're only supporting
                    // UTF-8, UTF-16, and UTF-32. The only time this might make sense if when we add support for
                    // other single-byte encodings such as Windows-1252 or ISO 8859-1
                    let oldEncoding = xmlEncoding
                    switch v.string.lowercased() {//@f:0
                        case "utf-8"             : xmlEncoding = String.Encoding.utf8
                        case "utf-16", "utf-16be": xmlEncoding = String.Encoding.utf16BigEndian
                        case "utf-16le"          : xmlEncoding = String.Encoding.utf16LittleEndian
                        case "utf-32", "utf-32be": xmlEncoding = String.Encoding.utf32BigEndian
                        case "utf-32le"          : xmlEncoding = String.Encoding.utf32LittleEndian
                        default                  : throw SAXError.UnsupportedEncoding(description : v.string, pos: (v.pos.line, v.pos.column))
                    }//@f:1
                    xmlEncoding = oldEncoding
                case "standalone":
                    isStandalone = v.string.lowercased().isOneOf("true", "yes")
                default:
                    throw SAXError.Malformed(description: "Pseudo-attribute \"\(k.string)\" not allowed here.", pos: (k.pos.line, k.pos.column))
            }
        }
    }

    /*===========================================================================================================================*/
    /// Update the given document position based on the given character as if it had been read from the input stream.
    ///
    /// - Parameters:
    ///   - pos: the position.
    ///   - char: the character.
    /// - Returns: the character.
    ///
    @discardableResult @inlinable final func updatePosition(_ pos: inout DocPosition, forChar char: Character) -> Character {
        switch char {
            case "\n":
                pos.line += 1
                pos.column = 1
            case "\t":
                pos.column = calcTab(col: pos.column)
            default:
                pos.column += 1
        }
        return char
    }

    /*===========================================================================================================================*/
    /// Scans and collects any whitespace starting with the next character until the next non-whitespace character.
    ///
    /// - Returns: A string of all the whitespace characters found.
    /// - Throws: if an I/O error occurs.
    ///
    @discardableResult @inlinable final func scanPastWhitespace() throws -> String {
        try getString(throwOnEOF: false, body: { (_, c, _) -> Bool in c.test(is: .xmlWhiteSpace) }).string
    }

    /*===========================================================================================================================*/
    /// Determine the character encoding used and then create an instance of CharInputStream for us to use.
    ///
    /// - Throws: if an I/O error occurs or there is not at least 4 bytes of data to read from the input stream.
    ///
    @usableFromInline final func createCharInputStream() throws {
        var bf: [UInt8]         = [ 0, 0, 0, 0 ]
        let bi: ByteInputStream = ByteInputStream(inputStream: inputStream)
        guard try bi.peek(buffer: &bf, maxLength: 4) == 4 else { throw SAXError.UnexpectedEndOfInput(pos: _currPos) }
        try determineEncoding(inputStream: bi, buffer: bf)
    }

    /*===========================================================================================================================*/
    /// Try to determine the encoding from the first 4 bytes.
    ///
    /// - Parameters:
    ///   - bi:
    ///   - buffer:
    /// - Throws: if an I/O error occurs or there is not at least 4 bytes of data to read from the input stream.
    ///
    @usableFromInline final func determineEncoding(inputStream bi: ByteInputStream, buffer: [UInt8]) throws {
        xmlEncoding = try encodingCheck(bi, buffer: buffer)
        switch xmlEncoding { //@f:0
            case .utf16LittleEndian: _charInputStream = Utf16CharInputStream(byteInputStream: bi, endian: CFByteOrderLittleEndian)
            case .utf16BigEndian   : _charInputStream = Utf16CharInputStream(byteInputStream: bi, endian: CFByteOrderBigEndian)
            case .utf32LittleEndian: _charInputStream = Utf32CharInputStream(byteInputStream: bi, endian: CFByteOrderLittleEndian)
            case .utf32BigEndian   : _charInputStream = Utf32CharInputStream(byteInputStream: bi, endian: CFByteOrderBigEndian)
            default                : _charInputStream = Utf8CharInputStream(byteInputStream: bi)
        } //@f:1
    }

    /*===========================================================================================================================*/
    /// Convenience function for setting the delegate and calling parse in one call.
    ///
    /// - Parameter delegate: the `SAXParserDelegate`.
    /// - Throws: if an error occurs during parsing.
    ///
    open func parse(delegate: SAXParserDelegate) throws {
        self.delegate = delegate
        try parse()
    }

    /*===========================================================================================================================*/
    /// Test a character to see if it's the one wanted.
    ///
    /// - Parameters:
    ///   - got: the character, and it's position, that we got.
    ///   - want: the character we wanted.
    /// - Returns: the character, and it's position, that we got.
    /// - Throws: if they don't match.
    ///
    @discardableResult @inlinable final func testChar(got: CharPos, want: Character) throws -> CharPos {
        guard want == got.0 else { throw getWrongCharError(wanted: want, got: got) }
        return got
    }

    /*===========================================================================================================================*/
    /// Parse a processing instruction. A processing instruction takes the form `<?target data?>` where `data` can be any text
    /// except for the sequence `?>` which marks the end of the processing instruction.
    ///
    /// - Returns: a tuple containing the target and data strings.
    /// - Throws: if an I/O error occurs or the EOF is reached.
    ///
    @usableFromInline final func parseProcessingInstruction() throws -> (StringPos, StringPos) {
        let target = try getName()
        try scanPastWhitespace()
        let data = try getString(keepLast: true) { (i, c, arr) -> Bool in !((i > 0) && (c == ">") && (arr[i - 1] == "?")) }
        return (target, StringPos(string: data.string.removeLast(count: 2), pos: data.pos))
    }

    /*===========================================================================================================================*/
    /// Parse and delegate a processing instruction.
    ///
    /// - Throws: if an I/O error occurs or the EOF is reached.
    ///
    @inlinable final func parseAndDelegateProcessingInstruction() throws {
        let (target, data) = try parseProcessingInstruction()
        if let f = delegate?.parseProcessingInstruction { f(self, target.string, data.string) }
    }

    /*===========================================================================================================================*/
    /// Parses out a string of Key/Value pairs. This method scans the input string for key/value pairs in the format
    /// `<whitespace>key="value"`. An apostrophe can be used in place of the double quotation mark but, which ever one is used, it
    /// has to end with the same one it starts with. In other words you can't have `key="value'`.
    ///
    /// - Parameters:
    ///   - data: the string to parse.
    /// - Returns: a <code>[Dictionary](https://developer.apple.com/documentation/swift/Dictionary)</code> of the key/value pairs.
    /// - Throws: if the input was not is the proper format.
    ///
    @usableFromInline final func parseKeyValueData(data: StringPos) throws -> [StringPos: StringPos] {
        var kv:  [StringPos: StringPos] = [:]
        let str: String                 = data.string
        var idx: String.Index           = str.startIndex
        var pos: DocPosition            = data.pos

        while idx < str.endIndex {
            let char = str[idx]

            if char.test(is: .xmlWhiteSpace) {
                idx = str.index(after: idx)
                updatePosition(&pos, forChar: char)
            }
            else if char.test(is: .xmlNameStartChar) {
                let key = try getString(from: str, index: &idx, pos: &pos) { (i, ch, _) in ch.test(is: ((i == 0) ? .xmlNameStartChar : .xmlNameChar)) }
                guard idx < str.endIndex else { throw SAXError.UnexpectedEndOfInput(pos: pos) }

                let (ch, start) = getNextChar(string: str, at: &idx, pos: &pos)
                guard ch == "=" else { throw getWrongCharError(wanted: "=", got: (ch, start)) }
                guard idx < str.endIndex else { throw SAXError.UnexpectedEndOfInput(pos: pos) }

                let qt = getNextChar(string: str, at: &idx, pos: &pos)
                guard qt.0.isXmlQuote else { throw getBadQuoteError(got: qt) }

                kv[key] = try getString(from: str, index: &idx, pos: &pos) { (_, ch, _) in (ch != qt.0) }
                getNextChar(string: str, at: &idx, pos: &pos) // Discard closing quotation mark.
            }
            else {
                throw getUnexpectedCharError(char: (char, pos))
            }
        }

        return kv
    }

    /*===========================================================================================================================*/
    /// Un-read a string of characters.
    ///
    /// - Parameters:
    ///   - string: the string.
    ///   - pos: the starting document position of this string.
    ///
    @inlinable final func unRead(string: String, pos: DocPosition) {
        _currPos = pos
        _charInputStream.unRead(string: string)
    }

    /*===========================================================================================================================*/
    /// Un-read a string of characters.
    ///
    /// - Parameter strPos: an instance of `StringPos`.
    ///
    @inlinable final func unRead(_ strPos: StringPos) {
        _currPos = strPos.pos
        _charInputStream.unRead(string: strPos.string)
    }

    /*===========================================================================================================================*/
    /// Un-read a character.
    ///
    /// - Parameters:
    ///   - char: the character.
    ///   - pos: the document position of this character.
    ///
    @inlinable final func unRead(char: Character, pos: DocPosition) {
        _currPos = pos
        _charInputStream.unRead(char: char)
    }

    /*===========================================================================================================================*/
    /// Un-read a character.
    ///
    /// - Parameter cp: the character and its document position of this character.
    ///
    @inlinable final func unRead(cp: (Character?, DocPosition)) {
        if let ch = cp.0 { unRead(char: ch, pos: cp.1) }
    }

    /*===========================================================================================================================*/
    /// Un-read a character.
    ///
    /// - Parameter cp: the character and its document position of this character.
    ///
    @inlinable final func unRead(cp: CharPos) {
        unRead(char: cp.0, pos: cp.1)
    }

    /*===========================================================================================================================*/
    /// Get a `prefix:localname` combination from the input stream.
    ///
    /// - Returns: a tuple (`NSName`) with the prefix and localname. Prefix may be `nil`.
    /// - Throws: if an I/O error occurs or if the EOF is reached.
    ///
    @inlinable final func getNSNamePair() throws -> NSName {
        try scanPastWhitespace()

        let start              = _currPos
        var prefix:    String? = nil
        var localName: String  = try getNSName().string
        let ch                 = try getNextChar()

        if ch.0 == ":" {
            prefix = localName
            localName = try getNSName().string
        }
        else {
            unRead(cp: ch)
        }

        return (prefix, localName, start)
    }

    /*===========================================================================================================================*/
    /// Get an XML namespace name.
    ///
    /// - Returns: an instance of `StringPos` with the string and it's position in the document.
    /// - Throws: if an I/O error occurs or the EOF has been reached.
    ///
    @inlinable final func getNSName() throws -> StringPos {
        try getString { (i, c, _) in ((i == 0) ? c.test(is: .xmlNsNameStartChar) : c.test(is: .xmlNsNameChar)) }
    }

    /*===========================================================================================================================*/
    /// Get an XML name.
    ///
    /// - Returns: an instance of `StringPos` with the string and it's position in the document.
    /// - Throws: if an I/O error occurs or the EOF has been reached.
    ///
    @inlinable final func getName() throws -> StringPos {
        try getString { (i, c, _) in ((i == 0) ? c.test(is: .xmlNameStartChar) : c.test(is: .xmlNameChar)) }
    }

    /*===========================================================================================================================*/
    /// Get a string from the input stream.
    ///
    /// - Parameters:
    ///   - keepLast: if `true` then the last character read (that caused the closure to return `false`) is returned as part of the
    ///               string.
    ///   - throwOnEOF: if `true` then an exception is thrown if EOF is reached.
    ///   - body: the closure to test the character.
    ///     - The count of characters read so far.
    ///     - The current character.
    ///     - The previous characters.
    /// - Returns: an instance of `StringPos` with the string and it's position in the document.
    /// - Throws: if an I/O error occurs or if `throwOnEOF` is `true` and the EOF has been reached.
    ///
    @inlinable final func getString(keepLast: Bool = false, throwOnEOF: Bool = true, body: (Int, Character, inout [Character]) throws -> Bool) throws -> StringPos {
        let start:       DocPosition               = _currPos
        var index:       Int                       = 0
        var chars:       [Character]               = []
        var (char, pos): (Character?, DocPosition) = try getNextChar(false)

        while let ch = char, try body(index++, ch, &chars) {
            chars.append(ch)
            (char, pos) = try getNextChar(false)
        }

        if let ch = char {
            if keepLast { chars.append(ch) }
            else { unRead(char: ch, pos: pos) }
        }
        else if throwOnEOF {
            throw SAXError.UnexpectedEndOfInput(pos: pos)
        }

        return StringPos(string: String(chars), pos: start)
    }

    /*===========================================================================================================================*/
    /// Get a substring from another string.
    ///
    /// - Parameters:
    ///   - str: the string to extract the substring from.
    ///   - idx: the index within the string to start extracting characters.
    ///   - pos: the position within the document of the character pointed to by idx.
    ///   - keepLast: if `true` then the last character read (that caused the closure to return `false`) is returned as part of the
    ///               string.
    ///   - throwOnEOF: if `true` then an exception is thrown if EOF is reached.
    ///   - body: the closure that is used to test the characters to see if the end of the substring has been reached.
    ///     - The count of characters read so far.
    ///     - The current character.
    ///     - The previous characters.
    /// - Returns: an instance of `StringPos` with the string and it's position in the document.
    /// - Throws: if an I/O error occurs or if `throwOnEOF` is `true` and the EOF has been reached.
    ///
    @inlinable final func getString(from str: String,
                                    index idx: inout String.Index,
                                    pos: inout DocPosition,
                                    keepLast: Bool = false,
                                    throwOnEOF: Bool = true,
                                    body: (Int, Character, inout [Character]) throws -> Bool) throws -> StringPos {
        var chars: [Character] = []
        var i:     Int         = 0
        let start: DocPosition = pos

        while try ((idx < str.endIndex) && body(i++, str[idx], &chars)) {
            chars.append(str[idx])
            idx = str.index(after: idx)
        }

        if idx < str.endIndex {
            if keepLast {
                chars.append(getNextChar(string: str, at: &idx, pos: &pos).0)
            }
        }
        else if throwOnEOF {
            throw SAXError.UnexpectedEndOfInput(pos: pos)
        }

        return StringPos(string: String(chars), pos: start)
    }

    /*===========================================================================================================================*/
    /// Get the next character from the input stream.
    ///
    /// - Parameter throwOnEOF: if `true` then an exception will be thrown if there is no next character because the EOF has been
    ///                         reached.
    /// - Returns: the next character or `nil` if the EOF has been reached.
    /// - Throws: if an I/O error occurs or if `throwOnEOF` is `true` and the EOF has been reached.
    ///
    @inlinable final func getNextChar(_ throwOnEOF: Bool) throws -> (Character?, DocPosition) {
        if var char: Character = try _charInputStream.read() {
            if char == "\r" {
                if let c = try _charInputStream.read(), c != "\n" { unRead(char: c, pos: _currPos) }
                char = "\n"
            }
            let pos = _currPos
            return (updatePosition(&_currPos, forChar: char), pos)
        }
        else if throwOnEOF {
            throw SAXError.UnexpectedEndOfInput(pos: _currPos)
        }
        else {
            return (nil, _currPos)
        }
    }

    /*===========================================================================================================================*/
    /// Get the next character and test it.
    ///
    /// - Parameters:
    ///   - peek: if `true` the character is only peeked and not read.
    ///   - body: the closure to test the character.
    /// - Returns: the character.
    /// - Throws: if an I/O error occurs or if the EOF is found.
    ///
    @discardableResult @inlinable final func testNextChar(peek: Bool = false, _ body: (Character) throws -> Bool) throws -> CharPos {
        let ch = try getNextChar()
        if peek { unRead(cp: ch) }
        guard try body(ch.0) else { throw SAXError.UnexpectedCharacter(description: "Character '\(ch.0.printable) not expected here.", pos: ch.1) }
        return ch
    }

    /*===========================================================================================================================*/
    /// Get a character from the input stream.
    ///
    /// - Returns: a tuple with the character and it's position in the document.
    /// - Throws: if an I/O error occurs or the EOF has been reached.
    ///
    @inlinable final func getNextChar() throws -> CharPos {
        let (char, pos) = try getNextChar(true)
        return (char!, pos)
    }

    /*===========================================================================================================================*/
    /// Get a character from a string. On return, both the `idx` and `pos` will be updated.
    ///
    /// - Parameters:
    ///   - string: the string.
    ///   - idx: the index of the character to get.
    ///   - pos: the position in the document for the character.
    /// - Returns: a tuple with the character and it's position in the document.
    ///
    @discardableResult @inlinable final func getNextChar(string: String, at idx: inout String.Index, pos: inout DocPosition) -> CharPos {
        let start = pos
        let char  = updatePosition(&pos, forChar: string[idx])
        idx = string.index(after: idx)
        return (char, start)
    }

    /*===========================================================================================================================*/
    /// Peek at the next character in the input stream.
    ///
    /// - Returns: the next character.
    /// - Throws: if an I/O error occurs or if the EOF is reached.
    ///
    @inlinable final func peekNextChar() throws -> Character {
        let (char, pos) = try getNextChar()
        unRead(char: char, pos: pos)
        return char
    }

    /*===========================================================================================================================*/
    /// Peek the next count characters.
    ///
    /// - Parameter count: the number of characters to get.
    /// - Returns: the characters as a <code>[String](https://developer.apple.com/documentation/swift/string/)</code>.
    /// - Throws: if an I/O error occurs or the EOF is encountered.
    ///
    @inlinable final func peekString(count: Int) throws -> StringPos {
        let s = try getString(count: count)
        unRead(s)
        return s
    }

    /*===========================================================================================================================*/
    /// Get the wrong character error.
    ///
    /// - Parameters:
    ///   - wanted: the character we wanted.
    ///   - got: the character we got.
    /// - Returns: the error.
    ///
    @inlinable final func getWrongCharError(wanted: Character, got: CharPos) -> SAXError {
        SAXError.UnexpectedCharacter(description: "Expected '\(wanted.printable)' but got '\(got.0.printable) instead.", pos: got.1)
    }

    /*===========================================================================================================================*/
    /// Get the bad quote error.
    ///
    /// - Parameter got: the quote character.
    /// - Returns: the error.
    ///
    @inlinable final func getBadQuoteError(got: CharPos) -> SAXError {
        SAXError.UnexpectedCharacter(description: "Expected (') or (\") but got '\(got.0.printable)' instead.", pos: got.1)
    }

    /*===========================================================================================================================*/
    /// Get the unexpected character error.
    ///
    /// - Parameter char: the character.
    /// - Returns: the error.
    ///
    @inlinable final func getUnexpectedCharError(char: CharPos) -> SAXError {
        SAXError.UnexpectedCharacter(description: "Character '\(char.0.printable)' not expected here.", pos: char.1)
    }

    /*===========================================================================================================================*/
    /// Get the malformed error.
    ///
    /// - Parameters:
    ///   - s1: the expected string.
    ///   - s2: the actual string.
    /// - Returns: the error.
    ///
    @inlinable final func getMalformedError(expected s1: String, got s2: StringPos) -> SAXError {
        SAXError.Malformed(description: "Expected '\(s1)' but got '\(s2.string)' instead.", pos: s2.pos)
    }

    /*===========================================================================================================================*/
    /// Get the malformed error.
    ///
    /// - Parameters:
    ///   - what: what
    ///   - pos: position
    /// - Returns: the error.
    ///
    @inlinable final func getMalformedError(what: String, pos: DocPosition) -> SAXError {
        SAXError.Malformed(description: "Did not expect to find \(what) here.", pos: pos)
    }

    /*===========================================================================================================================*/
    /// Get the malformed sequence error.
    ///
    /// - Parameter seq: the sequence.
    /// - Returns: the error.
    ///
    @inlinable final func getMalformedSequence(seq: StringPos) -> SAXError {
        SAXError.Malformed(description: "Unexpected sequence '\(seq.string)'.", pos: seq.pos)
    }

    /*===========================================================================================================================*/
    /// Get the bad closing tag error.
    ///
    /// - Parameters:
    ///   - wanted: the wanted closing tag name.
    ///   - got: the actual closing tag name.
    ///   - pos: the position.
    /// - Returns: the error.
    ///
    @inlinable final func getBadClosingTag(wanted: String, got: String, pos: DocPosition) -> SAXError {
        SAXError.Malformed(description: "Incorrect closing tag. Expected '</\(wanted)>' but got '</\(got)>' instead.", pos: pos)
    }
}
