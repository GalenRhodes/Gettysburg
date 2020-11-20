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

public typealias DocPosition = (line: Int, column: Int)
public typealias NSName = (prefix: String?, localName: String, pos: DocPosition)

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
        //
        // Now we're going to look to see if we have an XML declaration on this bugger. Example: <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        // The very first thing we better find is a less-than symbol `<`.  Anything else would mean a malformed document.
        //
        try xmlDeclCheck()

        //
        // Remember if we've already gotten the document element and/or the DTD.
        //
        var elementFlag: Bool = false
        var docTypeFlag: Bool = false
        var (char, pos)       = try getNextChar(false)

        while let ch = char {
            if ch.test(is: .xmlWhiteSpace) {
                unRead(char: ch, pos: pos)
                try delegateIgnorableWhitespace()
            }
            else if char == "<" {
                try parseStructure(pos: pos, docTypeFlag: &docTypeFlag, elementFlag: &elementFlag)
            }
            else {
                unRead(char: ch, pos: pos)
                throw SAXError.Malformed(description: "Character \(ch) not allowed here.", pos: pos)
            }

            (char, pos) = try getNextChar(false)
        }
        //
        // No more input.  We're done.
        //
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
    private func parseStructure(pos: DocPosition, docTypeFlag: inout Bool, elementFlag: inout Bool) throws {
        let (char, charPos) = try getNextChar()

        switch char {
            case "?":
                //
                // Processing instruction?
                //
                unRead(string: "<?", pos: pos)
                try parseAndDelegateProcessingInstruction()
            case "!":
                //
                // Comment or DTD?
                //
                let strPos = try getString(count: 2)

                if strPos.string == "--" {
                    //
                    // Comment!
                    //
                    unRead(string: "<!--", pos: pos)
                    try parseAndDelegateComment()
                }
                else {
                    unRead(string: "<!\(strPos.string)", pos: pos)
                    guard strPos.string == "DO" else { throw SAXError.UnexpectedCharacter(description: "Expected '--' or 'DO' but found '\(strPos.string)' instead.", pos: strPos.pos) }
                    //
                    // DTD!
                    //
                    guard !docTypeFlag else { throw SAXError.Malformed(description: "Did not expect to find another DTD element here.", pos: pos) }
                    try parseAndDelegateDocType()
                    docTypeFlag = true
                    return
                }
            default:
                //
                // Element?
                //
                unRead(string: "<\(char)", pos: pos)
                guard char.test(is: .xmlNsNameStartChar) else { throw SAXError.UnexpectedCharacter(description: "Character '\(char) is not allowed to start an element tag name.", pos: charPos) }
                guard !elementFlag else { throw SAXError.Malformed(description: "Did not expect to find another element here.", pos: pos) }
                try parseAndDelegateElement()
                docTypeFlag = true
                elementFlag = true
        }
    }

    /*===========================================================================================================================*/
    /// Parse and delegate an element.
    ///
    /// - Throws: if an I/O error occurs or the element is malformed.
    ///
    func parseAndDelegateElement() throws {
    }

    /*===========================================================================================================================*/
    /// Parse and delegate the DTD.
    ///
    /// - Throws: if an I/O error occurs or the DTD is malformed.
    ///
    func parseAndDelegateDocType() throws {
        let test   = "<!DOCTYPE"
        let sample = try getString(count: 9)

        if test == sample.string {
            let (char1, pos1) = try getNextChar()
            guard char1.test(is: .xmlWhiteSpace) else { throw SAXError.UnexpectedCharacter(description: "Character '\(char1)' not expected here.", pos: pos1) }

            var notDone: Bool   = true
            var str:     String = ""
            var char2           = try getNextChar().0

            while notDone {
                if try char2 == "]" && peekNextChar() == ">" {
                    try parseAndDelegateInternalSubset(str + "\(char2)")
                    notDone = false
                }
                else {
                    str += "\(char2)"
                    char2 = try getNextChar().0
                }
            }
        }
        else {
            throw SAXError.UnexpectedCharacter(description: "Expected '\(test)' but got '\(sample.string)' instead.", pos: sample.pos)
        }
    }

    /*===========================================================================================================================*/
    /// Parse and delegate an external subset.
    ///
    /// - Parameter str: the string containing the information about the external subset.
    /// - Throws: if the external subset cannot be found or is invalid.
    ///
    func parseAndDelegateExternalSubset(externalSubset str: String) throws {
        if let f = delegate?.parseExternalSubset {
            f(self, str, nil, nil)
        }
    }

    /*===========================================================================================================================*/
    /// Parse and delegate the internal subset.
    ///
    /// - Parameter str: the string containing the internal subset.
    /// - Throws: if the internal subset is invalid.
    ///
    func parseAndDelegateInternalSubset(_ str: String) throws {
        if let f = delegate?.parseInternalSubset {
            f(self, str, nil, nil)
        }
    }

    /*===========================================================================================================================*/
    /// Get the next `count` characters.
    ///
    /// - Parameter count: the number of characters to read.
    /// - Returns: the string of characters.
    /// - Throws: if an I/O error occurs or the EOF is reached before the desired number of characters are read.
    ///
    func getString(throwOnEOF: Bool = true, count: Int) throws -> StringPos {
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
    func xmlDeclCheck() throws {
        let str = try getString(count: 2)
        unRead(str)
        if str.string == "<?" {
            let (target, content) = try parseProcessingInstruction()
            //
            // If the target is "xml" then this is an XML declaration and we can extract the information from it.
            //
            if target.string == "xml" { try parseXmlDecl(content: content) }
            //
            // Otherwise treat it as a processing instruction by passing it to the delegate.
            //
            else { delegateProcessingInstruction(target: target, content: content) }
        }
    }

    /*===========================================================================================================================*/
    /// Parse and send ignorable whitespace to the delegate.
    ///
    /// - Parameter char: the first ignorable whitespace character of this string.
    /// - Throws: if an I/O error occurs.
    ///
    func delegateIgnorableWhitespace() throws {
        let ws = try scanPastWhitespace()
        if let f = delegate?.parseIgnorableWhitespace {
            f(self, ws)
        }
    }

    /*===========================================================================================================================*/
    /// Parse and send a comment to the delegate.
    ///
    /// - Throws: if an I/O error occurs or the EOF is reached before the end of the comment is reached.
    ///
    func parseAndDelegateComment() throws {
        var (char, _)            = try getNextChar()
        var chars:   [Character] = []
        let notDone: Bool        = true
        let intro:   StringPos   = try getString(count: 4)

        guard intro.string == "<!--" else { throw SAXError.Malformed(description: "Malformed Comment", pos: intro.pos) }

        while notDone {
            if char == "-" {
                let sp = try getString(count: 2)

                if sp.string == "->" {
                    if let f = delegate?.parseComment { f(self, String(chars).trimmed) }
                    break
                }
                else {
                    unRead(sp)
                }
            }
            chars.append(char)
            (char, _) = try getNextChar()
        }
    }

    /*===========================================================================================================================*/
    /// Parse and send the processing instruction to the parser delegate.
    ///
    /// - Throws: if an I/O error occurs or the EOF is reached.
    ///
    func parseAndDelegateProcessingInstruction() throws {
        let (line, column): (StringPos, StringPos) = try parseProcessingInstruction()
        delegateProcessingInstruction(target: line, content: column)
    }

    /*===========================================================================================================================*/
    /// Send the processing instruction to the parser delegate.
    ///
    /// - Parameters:
    ///   - target: the target
    ///   - content: the content
    ///
    func delegateProcessingInstruction(target: StringPos, content: StringPos) {
        if let f = delegate?.parseProcessingInstruction {
            f(self, target.string, content.string)
        }
    }

    /*===========================================================================================================================*/
    /// Parse the XML Declaration for version, encoding, and standalone-ness.
    ///
    /// - Parameter content: the content of the XML Decl tag.
    /// - Throws: if the XML Decl is malformed.
    ///
    func parseXmlDecl(content: StringPos) throws {
        let kv = try parseKeyValueData(data: content)

        for (k, v) in kv {
            switch k.string {
                case "version":
                    guard v.string.isOneOf("1.0", "1.1") else {
                        throw SAXError.UnsupportedVersion(description: v.string, pos: (v.pos.line, v.pos.column))
                    }
                    xmlVersion = v.string
                case "encoding":
                    switch v.string.lowercased() {//@f:0
                        case "utf-8"             : xmlEncoding = String.Encoding.utf8
                        case "utf-16", "utf-16be": xmlEncoding = String.Encoding.utf16BigEndian
                        case "utf-16le"          : xmlEncoding = String.Encoding.utf16LittleEndian
                        case "utf-32", "utf-32be": xmlEncoding = String.Encoding.utf32BigEndian
                        case "utf-32le"          : xmlEncoding = String.Encoding.utf32LittleEndian
                        default                  : throw SAXError.UnsupportedEncoding(description : v.string, pos: (v.pos.line, v.pos.column))
                    }//@f:1
              // TODO: Change Input Encoding...
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
    @discardableResult func scanPastWhitespace() throws -> String {
        try getString(throwsOnEOF: false, body: { i, c, _ in c.test(is: .xmlWhiteSpace) }).string
    }

    /*===========================================================================================================================*/
    /// Determine the character encoding used and then create an instance of CharInputStream for us to use.
    ///
    /// - Throws: if an I/O error occurs or there is not at least 4 bytes of data to read from the input stream.
    ///
    func createCharInputStream() throws {
        do {
            let buffer: UnsafeMutablePointer<UInt8> = createMutablePointer(capacity: 4)
            defer { discardMutablePointer(buffer, 4) }
            if inputStream.streamStatus == .notOpen { inputStream.open() }

            let bi: ByteInputStream = ByteInputStream(inputStream: inputStream)
            //
            // The first thing we do is read at least 4 bytes of data from the stream. That
            // should be enough to give us a good guess.
            //
            let x:  Int             = 4
            let y:  Int             = try bi.read(buffer: buffer, maxLength: x)
            guard y == x else { throw SAXError.UnexpectedEndOfInput(pos: _currPos) }
            bi.unRead(src: buffer, length: y)
            //
            // Try to determine the encoding from the first 4 bytes.
            //
            xmlEncoding = try encodingCheck(bi, buffer: buffer)

            switch xmlEncoding { //@f:0
                case .utf16LittleEndian: _charInputStream = Utf16CharInputStream(byteInputStream: bi, endian: CFByteOrderLittleEndian)
                case .utf16BigEndian   : _charInputStream = Utf16CharInputStream(byteInputStream: bi, endian: CFByteOrderBigEndian)
                case .utf32LittleEndian: _charInputStream = Utf32CharInputStream(byteInputStream: bi, endian: CFByteOrderLittleEndian)
                case .utf32BigEndian   : _charInputStream = Utf32CharInputStream(byteInputStream: bi, endian: CFByteOrderBigEndian)
                default                : _charInputStream = Utf8CharInputStream(byteInputStream: bi)
            } //@f:1
        }
        catch let e {
            throw e
        }
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
    @discardableResult @inlinable final func testChar(got: (Character, DocPosition), want: Character) throws -> (Character, DocPosition) {
        guard want == got.0 else { throw SAXError.UnexpectedCharacter(description: "Expected '\(want)' but received '\(got.0)'.", pos: got.1) }
        return got
    }

    /*===========================================================================================================================*/
    /// Parse a processing instruction. A processing instruction takes the form `<?target data?>` where `data` can be any text
    /// except for the sequence `?>` which marks the end of the processing instruction.
    ///
    /// - Returns: a tuple containing the target and data strings.
    /// - Throws: if an I/O error occurs or the EOF is reached.
    ///
    func parseProcessingInstruction() throws -> (StringPos, StringPos) {
        try testChar(got: try getNextChar(), want: "<")
        try testChar(got: try getNextChar(), want: "?")
        let target = try getName()
        try scanPastWhitespace()
        let data = try getString { i, c, arr in
            guard arr.count > 0 && c == ">" && arr[arr.count - 1] == "?" else { return true }
            arr.removeLast()
            return false
        }
        return (target, data)
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
    func parseKeyValueData(data: StringPos) throws -> [StringPos: StringPos] {
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
                guard ch == "=" else { throw SAXError.UnexpectedCharacter(description: "Expected '=' but got '\(ch.printable)' instead.", pos: start) }
                guard idx < str.endIndex else { throw SAXError.UnexpectedEndOfInput(pos: pos) }

                let (qt, p) = getNextChar(string: str, at: &idx, pos: &pos)
                guard qt == "\"" || qt == "'" else { throw SAXError.UnexpectedCharacter(description: "Expected (\") or (') but got '\(qt.printable)' instead.", pos: p) }

                kv[key] = try getString(from: str, index: &idx, pos: &pos) { (_, ch, _) in (ch != qt) }
                getNextChar(string: str, at: &idx, pos: &pos) // Discard closing quotation mark.
            }
            else {
                throw SAXError.UnexpectedCharacter(description: "Character '\(char.printable)' not expected here.", pos: pos)
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
    /// Get a `prefix:localname` combination from the input stream.
    ///
    /// - Returns: a tuple (`NSName`) with the prefix and localname. Prefix may be `nil`.
    /// - Throws: if an I/O error occurs or if the EOF is reached.
    ///
    func getNSNamePair() throws -> NSName {
        try scanPastWhitespace()

        let start              = _currPos
        var localName: String  = try getNSName().string
        var prefix:    String? = nil
        let (char, pos)        = try getNextChar()

        if char == ":" {
            prefix = localName
            localName = try getNSName().string
        }
        else {
            unRead(char: char, pos: pos)
        }

        return (prefix, localName, start)
    }

    /*===========================================================================================================================*/
    /// Get an XML namespace name.
    ///
    /// - Returns: an instance of `StringPos` with the string and it's position in the document.
    /// - Throws: if an I/O error occurs or the EOF has been reached.
    ///
    func getNSName() throws -> StringPos {
        try getString { (i, c, _) in ((i == 0) ? c.test(is: .xmlNsNameStartChar) : c.test(is: .xmlNsNameChar)) }
    }

    /*===========================================================================================================================*/
    /// Get an XML name.
    ///
    /// - Returns: an instance of `StringPos` with the string and it's position in the document.
    /// - Throws: if an I/O error occurs or the EOF has been reached.
    ///
    func getName() throws -> StringPos {
        try getString { (i, c, _) in ((i == 0) ? c.test(is: .xmlNameStartChar) : c.test(is: .xmlNameChar)) }
    }

    /*===========================================================================================================================*/
    /// Get a string from the input stream.
    ///
    /// - Parameters:
    ///   - keepLast: if `true` then the last character read (that caused the closure to return `false`) is returned as part of the
    ///               string.
    ///   - throwsOnEOF: if `true` then an exception is thrown if EOF is reached.
    ///   - body: the closure to test the character.
    ///     - The count of characters read so far.
    ///     - The current character.
    ///     - The previous characters.
    /// - Returns: an instance of `StringPos` with the string and it's position in the document.
    /// - Throws: if an I/O error occurs or if `throwOnEOF` is `true` and the EOF has been reached.
    ///
    @inlinable final func getString(keepLast: Bool = false, throwsOnEOF: Bool = true, body: (Int, Character, inout [Character]) throws -> Bool) throws -> StringPos {
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
        else if throwsOnEOF {
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
    ///   - throwsOnEOF: if `true` then an exception is thrown if EOF is reached.
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
                                    throwsOnEOF: Bool = true,
                                    body: (Int, Character, inout [Character]) throws -> Bool) throws -> StringPos {
        var chars: [Character] = []
        var i:     Int         = 0
        let start: DocPosition = pos

        while try ((idx < str.endIndex) && body(i++, str[idx], &chars)) { chars.append(str[idx]) }

        if idx < str.endIndex {
            if keepLast { chars.append(getNextChar(string: str, at: &idx, pos: &pos).0) }
        }
        else if throwsOnEOF {
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
    /// Get a character from the input stream.
    ///
    /// - Returns: a tuple with the character and it's position in the document.
    /// - Throws: if an I/O error occurs or the EOF has been reached.
    ///
    @inlinable final func getNextChar() throws -> (Character, DocPosition) {
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
    @discardableResult @inlinable final func getNextChar(string: String, at idx: inout String.Index, pos: inout DocPosition) -> (Character, DocPosition) {
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
}
