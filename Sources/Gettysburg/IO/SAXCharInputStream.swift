/*******************************************************************************************************************************************************************************//*
 *     PROJECT: Gettysburg
 *    FILENAME: SAXCharInputStream.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 6/2/21
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

public protocol SAXCharInputStream: CharInputStream, AnyObject {
    //@f:0
    var url:         URL         { get }
    var baseURL:     URL         { get }
    var filename:    String      { get }
    var docPosition: DocPosition { get }
    //@f:1
}

open class SAXIConvCharInputStream: IConvCharInputStream, SAXCharInputStream {
    //@f:0
    public      let url:         URL
    public      let baseURL:     URL
    public      let filename:    String
    public lazy var docPosition: DocPosition = StreamPosition(inputStream: self)
    //@f:1

    public init(inputStream: InputStream, url: URL? = nil) throws {
        (self.url, self.baseURL, self.filename) = try GetBaseURLAndFilename(url: url ?? GetFileURL(filename: TempFilename(extension: "xml")))
        let _inputStream = ((inputStream as? MarkInputStream) ?? MarkInputStream(inputStream: inputStream, autoClose: true))
        let encodingName = try getEncodingName(inputStream: _inputStream)
        super.init(inputStream: _inputStream, encodingName: encodingName, autoClose: true)
    }
}

open class SAXStringCharInputStream: StringCharInputStream, SAXCharInputStream {
    //@f:0
    public      let url:         URL
    public      let baseURL:     URL
    public      let filename:    String
    public lazy var docPosition: DocPosition = StreamPosition(inputStream: self)
    //@f:1

    public init(string: String, url: URL? = nil) throws {
        (self.url, self.baseURL, self.filename) = try GetBaseURLAndFilename(url: url ?? GetFileURL(filename: TempFilename(extension: "xml")))
        super.init(string: string)
    }
}

extension SAXCharInputStream {

    @inlinable public var last: Character {
        guard markCount > 0 else { fatalError("Internal State Error") }
        markBackup()
        do { return try readChar() }
        catch let e { fatalError("\(e)") }
    }

    @inlinable public func peekChar(leadingWhitespace: LeadingWhitespace = .None, err: SAXErrorSelect = .UnexpectedEndOfInput) throws -> Character {
        markSet()
        defer { markReturn() }
        return try readChar(leadingWhitespace: leadingWhitespace, err: err)
    }

    @inlinable public func readChar(leadingWhitespace: LeadingWhitespace = .None, err: SAXErrorSelect = .UnexpectedEndOfInput) throws -> Character {
        if leadingWhitespace != .None { try skipWhitespace(required: (leadingWhitespace == .Required), err: err) }
        guard let ch = try read() else { throw SAXError.get(err, inputStream: self, description: ERRMSG_EOF) }
        return ch
    }

    @inlinable public func readString(count: Int, err: SAXErrorSelect = .UnexpectedEndOfInput) throws -> String {
        var data = Array<Character>()
        guard try read(chars: &data, maxLength: count) == count else { throw SAXError.get(err, inputStream: self, description: ERRMSG_EOF) }
        return String(data)
    }

    /*===========================================================================================================================================================================*/
    /// Skip over any whitespace.
    ///
    /// We depart from the XML specs here in that we treat ANY control character as whitespace. See - `CharacterSet.XMLWhitespace`
    ///
    /// [See - Whitespace](https://www.w3.org/TR/REC-xml/#white)
    ///
    /// - Parameters:
    ///   - required: If `true` then at least one whitespace character must be found.
    ///   - err: The type of error to throw if needed.
    /// - Throws: If an I/O error occurs or `required` is `true` and at least one whitespace character is not found.
    ///
    @inlinable public func skipWhitespace(required: Bool = false, err: SAXErrorSelect = .IllegalCharacter) throws {
        if required {
            guard let ch = try read() else { throw SAXError.get(err, inputStream: self, description: ERRMSG_EOF) }
            guard ch.isXmlWhitespace else { throw SAXError.get(err, inputStream: self, description: ExpMsg(ERRMSG_ILLEGAL_CHAR, explanation: "a whitespace character", got: ch)) }
        }
        while let ch = try read() { guard ch.isXmlWhitespace else { markBackup(); break } }
    }

    /*===========================================================================================================================================================================*/
    /// Read an XML identifier.
    ///
    /// [See - Names and Tokens](https://www.w3.org/TR/REC-xml/#d0e804)
    ///
    /// - Parameters:
    ///   - leadingWhitespace: The leading whitespace requirement.
    ///   - err: The type of error to throw if needed.
    /// - Returns: A String containing the identifier.
    /// - Throws: If an error occurs.
    ///
    @inlinable public func readIdentifier(leadingWhitespace: LeadingWhitespace = .None, err: SAXErrorSelect = .MalformedDocument) throws -> String {
        if leadingWhitespace != .None { try skipWhitespace(required: (leadingWhitespace == .Required), err: err) }
        return try readWhile(err: err) { ch, data in
            if (data.count == 0) && !ch.isXmlNameStartChar { throw SAXError.get(err, inputStream: self, description: ExpMsg(ERRMSG_ILLEGAL_CHAR, explanation: ERREXP_IDENT_START, got: ch)) }
            return ch.isXmlNameChar
        }
    }

    /*===========================================================================================================================================================================*/
    /// Read characters until the given sequence of characters have been read.
    ///
    /// - Parameters:
    ///   - string: A String containing the sequence of characters to look for.
    ///   - mustHave: If `true` and an empty string would be returned then throw an error.
    ///   - mustHaveMsg: The message to use if an empty string would be returned.
    ///   - suffix: What action to take with the characters that matched.
    ///   - err: The type of error to throw if needed.
    /// - Returns: A string of the characters read.
    /// - Throws: If an error occurs.
    ///
    @inlinable public func readUntil(found string: String, mustHave: Bool = true, mustHaveMsg: String = "Required data is missing.", suffix: SuffixOption = .Drop, err: SAXErrorSelect = .UnexpectedEndOfInput) throws -> String {
        try readUntil(found: string.getCharacters(splitClusters: true), mustHave: mustHave, mustHaveMsg: mustHaveMsg, suffix: suffix, err: err)
    }

    /*===========================================================================================================================================================================*/
    /// Read characters until the given sequence of characters have been read.
    ///
    /// - Parameters:
    ///   - chars: A list containing the sequence of characters to look for.
    ///   - mustHave: If `true` and an empty string would be returned then throw an error.
    ///   - mustHaveMsg: The message to use if an empty string would be returned.
    ///   - suffix: What action to take with the characters that matched.
    ///   - err: The type of error to throw if needed.
    /// - Returns: A string of the characters read.
    /// - Throws: If an error occurs.
    ///
    @inlinable public func readUntil(found chars: Character..., mustHave: Bool = true, mustHaveMsg: String = "Required data is missing.", suffix: SuffixOption = .Drop, err: SAXErrorSelect = .UnexpectedEndOfInput) throws -> String {
        try readUntil(found: chars, mustHave: mustHave, mustHaveMsg: mustHaveMsg, suffix: suffix, err: err)
    }

    /*===========================================================================================================================================================================*/
    /// Read characters until the given sequence of characters have been read.
    ///
    /// - Parameters:
    ///   - chars: An instance of Array<Character> that contains the sequence of characters to look for.
    ///   - mustHave: If `true` and an empty string would be returned then throw an error.
    ///   - mustHaveMsg: The message to use if an empty string would be returned.
    ///   - suffix: What action to take with the characters that matched.
    ///   - err: The type of error to throw if needed.
    /// - Returns: A string of the characters read.
    /// - Throws: If an error occurs.
    ///
    public func readUntil(found chars: [Character], mustHave: Bool = true, mustHaveMsg: String = "Required data is missing.", suffix: SuffixOption = .Drop, err: SAXErrorSelect = .UnexpectedEndOfInput) throws -> String {
        let cc   = chars.count
        var data = Array<Character>()

        markSet()
        defer { markDelete() }

        guard try read(chars: &data, maxLength: cc) == cc else { throw SAXError.get(err, inputStream: self, description: mustHaveMsg) }

        while data.last(count: cc) != chars {
            guard let ch = try read() else { throw SAXError.get(err, inputStream: self, description: mustHaveMsg) }
            data <+ ch
        }

        if value(suffix, isOneOf: .Leave, .Peek) { markBackup(count: cc) }
        if value(suffix, isOneOf: .Leave, .Drop) { data.removeLast(cc) }
        if mustHave && data.isEmpty { throw SAXError.get(err, inputStream: self, description: mustHaveMsg) }
        return String(data)
    }

    /*===========================================================================================================================================================================*/
    /// Read characters while the predicate continues to return `true`.
    ///
    /// - Parameters:
    ///   - mustHave: If `true` and an empty string would be returned then throw an error.
    ///   - mustHaveMsg: The message to use if an empty string would be returned.
    ///   - suffix: What action to take with the character that the predicate closure returned `false` for.
    ///   - errorOnEOF: `true` if an error should be thrown if the EOF is encountered.
    ///   - err: The type of error to throw if needed.
    ///   - predicate: The predicate closure.
    /// - Returns: A string of the characters read.
    /// - Throws: If an error occurs.
    ///
    public func readWhile(mustHave: Bool = true, mustHaveMsg: String = "Required data is missing.", suffix: SuffixOption = .Leave, errorOnEOF: Bool = true, err: SAXErrorSelect = .UnexpectedEndOfInput, predicate: (Character, inout [Character]) throws -> Bool) throws -> String {
        var data = Array<Character>()

        markSet()
        defer { markDelete() }

        while let ch = try read() {
            guard try predicate(ch, &data) else {
                if value(suffix, isOneOf: .Peek, .Keep) { data <+ ch }
                if value(suffix, isOneOf: .Peek, .Leave) { markBackup() }
                if mustHave && data.isEmpty { throw SAXError.get(err, inputStream: self, description: mustHaveMsg) }
                return String(data)
            }
            data <+ ch
        }

        if mustHave && data.isEmpty { throw SAXError.get(err, inputStream: self, description: mustHaveMsg) }
        return String(data)
    }
}
