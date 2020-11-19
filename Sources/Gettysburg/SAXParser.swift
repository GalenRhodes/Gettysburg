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

public typealias NSName = (prefix: String?, localName: String)
public typealias DocPosition = (line: Int, column: Int)

open class SAXParser {

    @usableFromInline enum ScanOption {
        case Continue
        case Stop
        case StopAndKeepLast
    }

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
    @usableFromInline var _posStack:        [DocPos]         = []

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
        // Save the actual starting position of the first non-whitespace character...
        //
        var pos = _currPos
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

        pos = _currPos

        while let char = try getNextChar(false) {
            if char.test(is: .xmlWhiteSpace) {
                unRead(char: char, pos: pos)
                try delegateIgnorableWhitespace()
            }
            else if char == "<" {
                let pos2  = _currPos
                let char2 = try getNextChar()
                switch char2 {
                    case "?":
                        unRead(string: "<?", pos: pos)
                        try parseAndDelegateProcessingInstruction()
                    case "!":
                        let pos3 = _currPos
                        let str  = try getChars(count: 2)

                        if str == "--" {
                            try parseAndDelegateComment()
                        }
                        else if str == "DO" {
                            unRead(string: "<!DO", pos: pos)
                            if docTypeFlag {
                                throw SAXError.Malformed(description: "Did not expect to find another DTD element here.", pos: pos)
                            }
                            try parseAndDelegateDocType()
                            docTypeFlag = true
                        }
                        else {
                            unRead(string: "<!\(str)", pos: pos)
                            throw SAXError.UnexpectedCharacter(description: "Expected '--' or 'DO' but found '\(str)' instead.", pos: pos3)
                        }
                    default:
                        if char2.test(is: .xmlNsNameStartChar) {
                            if elementFlag {
                                unRead(string: "<\(char2)", pos: pos)
                                throw SAXError.Malformed(description: "Did not expect to find another element here.", pos: pos)
                            }
                            unRead(char: char2, pos: pos2)
                            try parseAndDelegateElement()
                            docTypeFlag = true
                            elementFlag = true
                        }
                        else {
                            unRead(string: "<\(char2)", pos: pos)
                            throw SAXError.UnexpectedCharacter(description: "Character '\(char2) is not allowed to start an element tag name.", pos: pos2)
                        }
                }
            }
            else {
                unRead(char: char, pos: pos)
                throw SAXError.Malformed(description: "Character \(char) not allowed here.", pos: pos)
            }

            pos = _currPos
        }
        //
        // No more input.  We're done.
        //
    }

    @usableFromInline func parseAndDelegateElement() throws {
    }

    @usableFromInline func parseAndDelegateDocType() throws {
        let test   = "<!DOCTYPE"
        let sample = try getChars(count: 9)

        if test == sample {
            let pos1  = _currPos
            let char1 = try getNextChar()
            guard char1.test(is: .xmlWhiteSpace) else { throw SAXError.UnexpectedCharacter(description: "Character '\(char1)' not expected here.", pos: pos1) }

            var str: String = ""
            while let char2 = try getNextChar(true) {
                if try char2 == "]" && peekNextChar() == ">" {
                    str += "\(char2)"
                    try parseAndDelegateInternalSubset(internalSubset: str)
                    return
                }
                else {
                    str += "\(char2)"
                }
            }
        }
        else {
            throw SAXError.UnexpectedCharacter(description: "Expected '\(test)' but got '\(sample)' instead.", pos: _currPos)
        }
    }

    @usableFromInline func parseAndDelegateExternalSubset(externalSubset str: String) throws {
        if let f = delegate?.parseExternalSubset {
            f(self, str, nil, nil)
        }
    }

    @usableFromInline func parseAndDelegateInternalSubset(internalSubset str: String) throws {
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
    @inlinable func getChars(count: Int) throws -> String {
        var str: String = ""
        for _ in (0 ..< count) { str += "\(try getNextChar())" }
        return str
    }

    /*===========================================================================================================================*/
    /// Now we're going to look to see if we have an XML declaration on this bugger. Example: <?xml version="1.0" encoding="UTF-8"
    /// standalone="yes"?> The very first thing we better find is a less-than symbol `<`. Anything else would mean a malformed
    /// document.
    /// 
    /// - Throws: if an I/O error occurs or the document is malformed.
    ///
    func xmlDeclCheck() throws {
        let pos = _currPos
        try testChar(got: try getNextChar(), want: "<")
        let char: Character = try getNextChar()
        if char == "?" {
            unRead(string: "<?", pos: pos)
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
    @inlinable func delegateIgnorableWhitespace() throws {
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
        var pos: DocPosition = _currPos
        var str: String      = ""

        while let ch = try getNextChar(true) {
            if ch == "-" {
                pos = _currPos

                let s = try getChars(count: 2)

                if s == "->" {
                    if let f = delegate?.parseComment {
                        f(self, str)
                        return
                    }
                }
                else {
                    unRead(string: s, pos: pos)
                    str += "-"
                }
            }
            else {
                str += "\(ch)"
            }
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
    @inlinable func delegateProcessingInstruction(target: StringPos, content: StringPos) {
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
    /// Get the next character from the input stream. Also updates the line and column numbers accordingly.
    /// 
    /// - Returns: the next character.
    /// - Throws: if an I/O error occurs or if the end-of-input is reached.
    ///
    @inlinable func getNextChar() throws -> Character {
        try getNextChar(true)!
    }

    @inlinable func peekNextChar() throws -> Character {
        let pos  = _currPos
        let char = try getNextChar()
        unRead(char: char, pos: pos)
        return char
    }

    /*===========================================================================================================================*/
    /// Get the next character from the input stream. Also updates the line and column numbers accordingly.
    /// 
    /// - Parameter throwOnEOF: if there is no next character because we are at the EOF then throw an exception.
    /// - Returns: the next character or `nil` if throwOnEOF is `false` and we are at the EOF.
    /// - Throws: if an I/O error occurs or if throwOnEOF is `true` and we are at the EOF.
    ///
    @inlinable func getNextChar(_ throwOnEOF: Bool) throws -> Character? {
        if let char: Character = try _charInputStream.read() {
            if char == "\r" {
                if let c = try _charInputStream.read(), c != "\n" { unRead(char: c, pos: _currPos) }
                _currPos.line += 1
                _currPos.column = 1
                return "\n"
            }
            return updatePosition(&_currPos, forChar: char)
        }
        else if throwOnEOF {
            throw SAXError.UnexpectedEndOfInput(pos: _currPos)
        }
        else {
            return nil
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
    @discardableResult @inlinable func updatePosition(_ pos: inout DocPosition, forChar char: Character) -> Character {
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
    @inlinable @discardableResult func scanPastWhitespace() throws -> String {
        var pos = _currPos
        var ws  = ""

        while let char = try getNextChar(false) {
            if char.test(is: .xmlWhiteSpace) {
                ws += "\(char)"
                pos = _currPos
            }
            else {
                _currPos = pos
                unRead(char: char, pos: pos)
                return ws
            }
        }

        return ws
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
            try readAtLeast(bi, buffer: buffer, count: 4)
            bi.unRead(src: buffer, length: 4)
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
    /// Read `count` bytes from the input stream. Does not return until at least `count` bytes have been read. If the end-of-file
    /// is reached or an I/O error occurs before the required number of bytes have been read then an exception is thrown.
    /// 
    /// - Parameters:
    ///   - buffer: the buffer to read the bytes into.
    ///   - count: the number of bytes to read.
    /// - Returns: the number of bytes actually read. (will always be the same as `count`)
    /// - Throws: an exception if the end-of-file is reached or an I/O error occurs before the required number of bytes has been
    ///           read.
    ///
    @discardableResult open func readAtLeast(_ bInput: ByteInputStream, buffer: UnsafeMutablePointer<UInt8>, count: Int) throws -> Int {
        var bytesRead: Int = 0
        repeat {
            let ioResult = try bInput.read(buffer: buffer + bytesRead, maxLength: count - bytesRead)
            guard ioResult > 0 else { throw SAXError.UnexpectedEndOfInput(pos: _currPos) }
            bytesRead += ioResult
        }
        while bytesRead < count
        return bytesRead
    }

    /*===========================================================================================================================*/
    /// Convenience function for setting the delegate and calling parse in one call.
    /// 
    /// - Parameter delegate: the `SAXParserDelegate`.
    /// - Throws: if an error occurs during parsing.
    ///
    @inlinable open func parse(delegate: SAXParserDelegate) throws {
        self.delegate = delegate
        try parse()
    }

    /*===========================================================================================================================*/
    /// Push the line number and column number onto the position stack.
    ///
    @inlinable func pushPosition() {
        _posStack.append(DocPos(pos: _currPos))
    }

    /*===========================================================================================================================*/
    /// Pop and discard the last position pushed onto the position stack.
    ///
    @inlinable func discardLastPosition() {
        guard _posStack.count > 0 else { fatalError("Document Position Stack Empty") }
        _posStack.removeLast()
    }

    /*===========================================================================================================================*/
    /// Discard the last postion pushed onto the position stack and replace it with the current position.
    ///
    @inlinable func updateLastPosition() {
        discardLastPosition()
        pushPosition()
    }

    /*===========================================================================================================================*/
    /// Pop and restore the last position pushed onto the postion stack.
    ///
    @inlinable func popPosition() {
        guard _posStack.count > 0 else { fatalError("Document Position Stack Empty") }
        _currPos = _posStack.removeLast().pos
    }

    /*===========================================================================================================================*/
    /// Restore the last pushed position without removing it from the position stack.
    ///
    @inlinable func peekPosition() -> DocPosition {
        guard let lp = _posStack.last?.pos else { return _currPos }
        return lp
    }

    /*===========================================================================================================================*/
    /// Test a character to see if it's one that we expected.
    /// 
    /// - Parameters:
    ///   - want: the character we wanted.
    ///   - got: the character we got.
    /// - Returns: the character we got.
    /// - Throws: if the wanted character is not equal to the one we got.
    ///
    @inlinable @discardableResult func testChar(got: Character, want: Character, _ epos: DocPosition? = nil) throws -> Character {
        guard want == got else {
            throw SAXError.UnexpectedCharacter(description: "Expected '\(want)' but received '\(got)'.", pos: ((epos == nil) ? _currPos : epos!))
        }
        return got
    }

    /*===========================================================================================================================*/
    /// Test a character to see if it's one that we expected.
    /// 
    /// - Parameters:
    ///   - got: the character we got.
    ///   - want: the set of characters we wanted.
    /// - Returns: the character we got.
    /// - Throws: if the character we got is not in the set we wanted.
    ///
    @inlinable @discardableResult func testChar(got: Character, want: CharacterSet, _ epos: DocPosition? = nil) throws -> Character {
        guard got.test(is: want) else {
            throw SAXError.UnexpectedCharacter(description: "Character '\(got)' not allowed here.", pos: ((epos == nil) ? _currPos : epos!))
        }
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

        let targetPos: DocPosition = _currPos
        let target:    String      = try getString(startCharSet: .xmlNameStartChar, otherCharSet: .xmlNameChar)

        try scanPastWhitespace()

        let dataPos: DocPosition = _currPos
        var data:    String      = ""

        while let ch1 = try getNextChar(true) {
            if ch1 == "?" {
                let pos = _currPos
                let ch2 = try getNextChar()
                if ch2 == ">" { break }
                unRead(char: ch2, pos: pos)
            }
            data += "\(ch1)"
        }

        return (StringPos(string: target, pos: targetPos), StringPos(string: data.trimmingCharacters(in: .xmlWhiteSpace), pos: dataPos))
    }

    /*===========================================================================================================================*/
    /// Parses out a string of Key/Value pairs. This method scans the input string for key/value pairs in the format
    /// `<whitespace>key="value"`. An apostrophe can be used in place of the double quotation mark but, which ever one is used, it
    /// has to end with the same one it starts with. In other words you can't have `key="value'`. Also, spaces around the equal
    /// sign (`=`) is allowed.
    /// 
    /// - Parameters:
    ///   - data: the string to parse.
    /// - Returns: a <code>[Dictionary](https://developer.apple.com/documentation/swift/Dictionary)</code> of the key/value pairs.
    /// - Throws: if the input was not is the proper format.
    ///
    func parseKeyValueData(data: StringPos) throws -> [StringPos: StringPos] {
        var pos:        DocPosition            = (data.pos.line, data.pos.column - 1)
        var keyPos:     DocPosition            = pos
        var valPos:     DocPosition            = pos
        var kv:         [StringPos: StringPos] = [:]
        var stage:      ParseKVStage           = .PreKey
        var key:        String                 = ""
        var val:        String                 = ""
        var quoteSym:   Character              = "\""
        var stageStack: [ParseKVStage]         = []

        for char in data.string {
            var _char: Character? = updatePosition(&pos, forChar: char)

            while let c = _char {
                _char = ((stage == .InWhiteSpace) ? parseKeyValue01(c, &stage, &stageStack) : try parseKeyValue02(c, &key, &val, &kv, pos, &keyPos, &valPos, &quoteSym, &stage, &stageStack))
            }
        }

        return kv
    }

    /*===========================================================================================================================*/
    /// Parses out a string of Key/Value pairs. Worker #1
    /// 
    /// - Parameters:
    ///   - char: the character.
    ///   - stage: the current stage.
    ///   - stageStack: the stage stack.
    /// - Returns: the character.
    ///
    func parseKeyValue01(_ char: Character, _ stage: inout ParseKVStage, _ stageStack: inout [ParseKVStage]) -> Character? {
        guard char.test(isNot: ParseKVStage.InWhiteSpace.expecting) else { return nil }
        stage = stageStack.removeLast()
        return char
    }

    /*===========================================================================================================================*/
    /// Parses out a string of Key/Value pairs. Worker #2
    /// 
    /// - Parameters:
    ///   - char: the character.
    ///   - key: the current key under construction.
    ///   - val: the current value under construction.
    ///   - kv: the key/value dictionary.
    ///   - pos: the current document position.
    ///   - keyPos: the position of the start of the key.
    ///   - valPos: the position of the start of the value.
    ///   - quoteSym: which quotation symbol was used to start the value.
    ///   - stage: the current stage.
    ///   - stageStack: the stage stack.
    /// - Returns: always returns `nil`.
    /// - Throws: if an unexpected character is encountered.
    ///
    func parseKeyValue02(_ char: Character,
                         _ key: inout String,
                         _ val: inout String,
                         _ kv: inout [StringPos: StringPos],
                         _ pos: DocPosition,
                         _ keyPos: inout DocPosition,
                         _ valPos: inout DocPosition,
                         _ quoteSym: inout Character,
                         _ stage: inout ParseKVStage,
                         _ stageStack: inout [ParseKVStage]) throws -> Character? {
        if (stage.isIn(.InValue) && (char == quoteSym)) || char.test(is: stage.expecting) {
            try parseKeyValue03(char, &key, &val, &kv, pos, &keyPos, &valPos, &quoteSym, stage)
            stage = stage.nextStage[0]
        }
        else if stage.isIn(.InValue) {
            val += "\(char)"
        }
        else if stage.isIn(.InKey) && char.test(is: .xmlNameChar) {
            key += "\(char)"
        }
        else if stage.whiteSpaceCanTerminate && char.test(is: ParseKVStage.InWhiteSpace.expecting) {
            stageStack.append(stage.nextStage[1])
            stage = .InWhiteSpace
        }
        else if stage.expectingChar == " " && char.test(isNot: ParseKVStage.InWhiteSpace.expecting) {
            throw SAXError.UnexpectedCharacter(description: "Character '\(char)' not expected here.", pos: pos)
        }
        else {
            try testChar(got: char, want: stage.expectingChar, pos)
        }
        return nil
    }

    /*===========================================================================================================================*/
    /// Parses out a string of Key/Value pairs. Worker #3
    /// 
    /// - Parameters:
    ///   - char: the current character.
    ///   - key: the current key under construction.
    ///   - val: the current value under construction.
    ///   - kv: the key/value dictionary.
    ///   - pos: the current document position.
    ///   - keyPos: the position of the start of the key.
    ///   - valPos: the position of the start of the value.
    ///   - quoteSym: which quotation symbol was used to start the value.
    ///   - stage: the current stage.
    /// - Throws: if the key is an empty string.
    ///
    func parseKeyValue03(_ char: Character,
                         _ key: inout String,
                         _ val: inout String,
                         _ kv: inout [StringPos: StringPos],
                         _ pos: DocPosition,
                         _ keyPos: inout DocPosition,
                         _ valPos: inout DocPosition,
                         _ quoteSym: inout Character,
                         _ stage: ParseKVStage) throws {
        switch stage {
            case .PreKey:
                keyPos = pos
                key = "\(char)"
            case .PostKey:
                quoteSym = char
                valPos = pos
            case .PostEquals, .PreInValue:
                valPos = pos
            case .InKey:
                if key.isEmpty { throw SAXError.Malformed(description: "Missing pseudo-attribute name.", pos: pos) }
            case .InValue:
                kv[StringPos(string: key, pos: keyPos)] = StringPos(string: val, pos: valPos)
                key = ""
                val = ""
            default:
                break
        }
    }

    /*===========================================================================================================================*/
    /// Un-read a string of characters.
    /// 
    /// - Parameters:
    ///   - string: the string.
    ///   - pos: the starting document position of this string.
    ///
    @inlinable func unRead(string: String, pos: DocPosition) {
        _currPos = pos
        _charInputStream.unRead(string: string)
    }

    /*===========================================================================================================================*/
    /// Un-read a character.
    /// 
    /// - Parameters:
    ///   - char: the character.
    ///   - pos: the document position of this character.
    ///
    @inlinable func unRead(char: Character, pos: DocPosition) {
        _currPos = pos
        _charInputStream.unRead(char: char)
    }

    /*===========================================================================================================================*/
    /// Get a `prefix:localname` combination from the input stream.
    /// 
    /// - Returns: a tuple (`NSName`) with the prefix and localname. Prefix may be `nil`.
    /// - Throws: if an I/O error occurs or if the EOF is reached.
    ///
    @usableFromInline func getNSName() throws -> NSName {
        try scanPastWhitespace()
        var localName: String      = try getString(startCharSet: .xmlNsNameStartChar, otherCharSet: .xmlNsNameChar)
        var prefix:    String?     = nil
        let pos:       DocPosition = _currPos
        let char:      Character   = try getNextChar()

        if char == ":" {
            prefix = localName
            localName = try getString(startCharSet: .xmlNsNameStartChar, otherCharSet: .xmlNsNameChar)
        }
        else {
            unRead(char: char, pos: pos)
        }

        return (prefix, localName)
    }

    /*===========================================================================================================================*/
    /// Get a string from the input stream.
    /// 
    /// - Parameters:
    ///   - start: the character set that the first character must conform to. If the first character does not conform to this
    ///            character set then an exception is thrown.
    ///   - otherCharSet: the character set that all the characters after the first one must conform to. The first character that
    ///                   does not match this character set is considered to mark the end of the string. If this character set is
    ///                   `nil` then the `startCharSet` is used.
    /// - Returns: the string of characters.
    /// - Throws: if an I/O error occurs, the EOF is reached, or if the first character read does not conform to the `startCharSet`.
    ///
    @usableFromInline func getString(startCharSet start: CharacterSet, otherCharSet: CharacterSet? = nil) throws -> String {
        let other  = (otherCharSet ?? start)
        var string = ""
        var pos    = _currPos
        var char   = try testChar(got: try getNextChar(), want: start)

        repeat {
            string += "\(char)"
            pos = _currPos
            char = try getNextChar()
        }
        while char.test(is: other)

        unRead(char: char, pos: pos)
        return string
    }
}
