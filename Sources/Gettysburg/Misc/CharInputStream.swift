/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: CharInputStream.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 2/16/21
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

public let MemLimitMessage = "Memory Limit Reached."

extension CharInputStream {

    /*===========================================================================================================================================================================*/
    /// Returns the current position in the text file. (line, column).
    ///
    @inlinable var position: (Int, Int) { (lineNumber, columnNumber) }

    /*===========================================================================================================================================================================*/
    /// Read an XML Name from this <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>. This method reads characters until the
    /// first non-XML Name Character, such as whitespace, is encountered.
    /// 
    /// - Parameters:
    ///   - mustHave: if `true` then at least the starting character must be read and the returned string will not be empty. If `false` the returned string might be empty.
    ///   - errorOnEOF: if `true` and the EOF is encountered then an error is thrown. If `false` and the EOF is encountered then the characters read so far are returned.
    /// - Returns: the string of characters.
    /// - Throws: if there is an I/O error or if `errorOnEOF` is `true` and the EOF is encountered.
    ///
    @inlinable func readXmlName(mustHave: Bool = true, errorOnEOF: Bool = true) throws -> String {
        var buffer: [Character] = []

        if let ch = try read() {
            guard ch.isXmlNameStartChar else {
                if mustHave { throw SAXError.InvalidCharacter(self, found: ch) }
                else { return "" }
            }

            buffer <+ ch

            while let ch = try read() {
                guard ch.isXmlNameChar else { return String(buffer) }
                buffer <+ ch
            }
        }

        if errorOnEOF { throw SAXError.UnexpectedEndOfInput(self) }
        return String(buffer)
    }

    /*===========================================================================================================================================================================*/
    /// NOTE: There is no real limit here. So be careful!
    /// 
    /// - Returns: the data read from the file.
    /// - Throws: I/O error
    ///
    @inlinable func readAll() throws -> String {
        defer { close() }
        var chars: [Character] = []
        while let ch = try read() { chars <+ ch }
        return String(chars)
    }

    /*===========================================================================================================================================================================*/
    /// Read all of the characters from a file.
    /// 
    /// - Parameter memLimit: The maximum number of characters to read.
    /// - Returns: the data read from the file.
    /// - Throws: I/O error
    ///
    @inlinable func readAll(memLimit: Int) throws -> String {
        var chars: [Character] = []
        while let ch = try read() { chars <+ ch }
        return String(chars)
    }

    @inlinable func readUntil(found: String, memLimit: Int, excludeFound: Bool = false) throws -> String {
        try readUntil(found: found.getCharacters(), memLimit: memLimit, excludeFound: excludeFound)
    }

    @inlinable func readUntil(found: Character..., memLimit: Int, excludeFound: Bool = false) throws -> String {
        try readUntil(found: found, memLimit: memLimit, excludeFound: excludeFound)
    }

    @inlinable func readUntil(found: [Character], memLimit: Int, excludeFound: Bool = false) throws -> String {
        try readUntil(memLimit: memLimit, errorOnEOF: true) { chars, bc in
            let f = (chars.last(count: found.count) == found)
            if f && excludeFound { bc = found.count }
            return f
        }
    }

    /*===========================================================================================================================================================================*/
    /// Peek at the next character but do not remove it.
    /// 
    /// - Returns: the next character.
    /// - Throws: if there is an I/O error or if the EOF is encountered.
    ///
    @inlinable func peek() throws -> Character {
        markSet()
        defer { markReturn() }
        return try readNoNil()
    }

    /*===========================================================================================================================================================================*/
    /// Read the next character from the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>. Throws an error if the EOF is
    /// encountered.
    /// 
    /// - Returns: the next character.
    /// - Throws: if there is an I/O error or if the EOF is encountered.
    ///
    @inlinable func readNoNil() throws -> Character {
        guard let ch = try read() else { throw SAXError.UnexpectedEndOfInput(self) }
        return ch
    }

    /*===========================================================================================================================================================================*/
    /// Read a set number of characters from the stream and return then as a string.
    /// 
    /// - Parameters:
    ///   - count: the number of characters to read.
    ///   - errorOnEOF: if `true` and the EOF is encountered before the number of characters are read then an error is thrown. Otherwise the characters read are returned.
    /// - Returns: the string.
    /// - Throws: if there is an I/O error or if errorOnEOF is `true` and the EOF is encountered before the set number of characters can be read.
    ///
    @inlinable func readString(count: Int, errorOnEOF: Bool = true) throws -> String {
        var chars: [Character] = []
        for _ in (0 ..< count) {
            guard let ch = try read() else {
                if errorOnEOF { throw SAXError.UnexpectedEndOfInput(self) }
                break
            }
            chars <+ ch
        }
        return String(chars)
    }

    @inlinable func readUntil(memLimit: Int, errorOnEOF: Bool = true, predicate body: ([Character], inout Int) throws -> Bool) throws -> String {
        markSet()
        defer { markDelete() }

        var chars: [Character] = []

        while let ch = try read() {
            var bc: Int = 0
            chars <+ ch
            if try body(chars, &bc) {
                if bc > 0 {
                    markBackup(count: bc)
                    chars.removeLast(bc)
                }
                return String(chars)
            }
            guard chars.count < memLimit else { throw SAXError.InternalError(description: MemLimitMessage) }
        }

        if errorOnEOF { throw SAXError.UnexpectedEndOfInput(self) }
        return String(chars)
    }

    /*===========================================================================================================================================================================*/
    /// Skip over whitespace characters returning the first non-whitespace character encountered.
    /// 
    /// - Parameters:
    ///   - mustHave: If `true` then there must be at least one whitespace character otherwise an error is thrown.
    ///   - peek: If `true` then the non-whitespace character is not removed from the input stream.
    /// - Returns:
    /// - Throws:
    ///
    @inlinable @discardableResult func skipWhitespace(mustHave: Bool = false, peek: Bool) throws -> Character {
        markSet()
        defer { markDelete() }

        if mustHave {
            guard let ch = try read() else { throw SAXError.UnexpectedEndOfInput(self) }
            guard ch.isXmlWhitespace else { throw SAXError.InvalidCharacter(self, found: ch, expected: "␠", "␉", "␊", "␍", "␤") }
        }

        while let ch = try read() {
            if !ch.isXmlWhitespace {
                if peek { markBackup() }
                return ch
            }
        }

        throw SAXError.UnexpectedEndOfInput(self)
    }

    /*===========================================================================================================================================================================*/
    /// Read an optional quoted string. If the first non-whitespace character is a single `'` or double `"` quote then the quoted string is returned, otherwise `nil` is returned.
    /// 
    /// - Parameters:
    ///   - memLimit: the max number of characters to read.
    ///   - leadingWS: `None` ⏤ there can be no leading whitespace; `Allowed` ⏤ leading whitespace is allowed; `Required` ⏤ leading whitespace is required.
    /// - Returns: the quoted string or `nil` is there was not one.
    /// - Throws: if there is an I/O error or the EOF is encountered before the closing quotation mark.
    ///
    @inlinable func readOptQuotedString(memLimit: Int, leadingWS: LeadingWhitespace = .Allowed) throws -> String? {
        if leadingWS != .None { try skipWhitespace(mustHave: (leadingWS == .Required), peek: true) }
        let quote = try peek()
        return (value(quote, isOneOf: "\"", "'") ? try readQuotedString(memLimit: memLimit, leadingWS: .None, quote: quote) : nil)
    }

    /*===========================================================================================================================================================================*/
    /// Read a quoted string. Quoted strings can be delimited by double quotes `"` or single quotes `'` but the same quote that was used to open the quoted string has to be used
    /// to close it. This method assumes that any nested quotation marks are escaped in a manner that makes them NOT look like the character being used as the quotation mark. For
    /// example, using "&quot;" to escape a double quote (").
    /// 
    /// - Parameters:
    ///   - memLimit: the max number of characters to read.
    ///   - leadingWS: `None` ⏤ there can be no leading whitespace; `Allowed` ⏤ leading whitespace is allowed; `Required` ⏤ leading whitespace is required.
    /// - Returns: the quoted string.
    /// - Throws: if there is an I/O error or the EOF is encountered before the closing quotation mark.
    ///
    @inlinable func readQuotedString(memLimit: Int, leadingWS: LeadingWhitespace = .Allowed) throws -> String {
        try readQuotedString(memLimit: memLimit, leadingWS: leadingWS, quote: "\"", "'")
    }

    /*===========================================================================================================================================================================*/
    /// Read a quoted string. You can specify any character to use as the quotation mark but the same character must be used for the open and close. This method assumes that any
    /// nested quotation marks are escaped in a manner that makes them NOT look like the character being used as the quotation mark. For example, using "&quot;" to escape a double
    /// quote (").
    /// 
    /// - Parameters:
    ///   - memLimit: the max number of characters to read.
    ///   - quote: the `character(s)` to use as the quotation mark.
    /// - Returns: the string.
    /// - Throws: if an I/O error occurs.
    ///
    @inlinable func readQuotedString(memLimit: Int, leadingWS: LeadingWhitespace = .Allowed, quote: Character...) throws -> String {
        try readQuotedString(memLimit: memLimit, leadingWS: leadingWS, quote: quote)
    }

    /*===========================================================================================================================================================================*/
    /// Read a quoted string. You can specify any character to use as the quotation mark but the same character must be used for the open and close. This method assumes that any
    /// nested quotation marks are escaped in a manner that makes them NOT look like the character being used as the quotation mark. For example, using "&quot;" to escape a double
    /// quote (").
    /// 
    /// - Parameters:
    ///   - memLimit: the max number of characters to read.
    ///   - quote: the `character(s)` to use as the quotation mark.
    /// - Returns: the string.
    /// - Throws: if an I/O error occurs.
    ///
    @inlinable func readQuotedString(memLimit: Int, leadingWS: LeadingWhitespace = .Allowed, quote: [Character]) throws -> String {
        markSet()
        defer { markDelete() }
        if leadingWS != .None { try skipWhitespace(mustHave: (leadingWS == .Required), peek: true) }
        let qt = try readChar(mustBeOneOf: quote)

        var chars: [Character] = []

        while let ch = try read() {
            if ch == qt { return String(chars) }
            chars <+ ch
            guard chars.count < memLimit else { throw SAXError.InternalError(description: MemLimitMessage) }
        }

        throw SAXError.UnexpectedEndOfInput(self)
    }

    /*===========================================================================================================================================================================*/
    /// Read the next character and make sure that it is one of the given characters.
    /// 
    /// - Parameter chars: the list of possibly correct characters.
    /// - Returns: the character read.
    /// - Throws: if there is an I/O error or the character read is not one of the given characters.
    ///
    @inlinable @discardableResult func readChar(mustBeOneOf chars: Character...) throws -> Character {
        try readChar(mustBeOneOf: chars)
    }

    /*===========================================================================================================================================================================*/
    /// Read the next character and make sure that it is one of the given characters.
    /// 
    /// - Parameter chars: the list of possibly correct characters.
    /// - Returns: the character read.
    /// - Throws: if there is an I/O error or the character read is not one of the given characters.
    ///
    @inlinable @discardableResult func readChar(mustBeOneOf chars: [Character]) throws -> Character {
        guard let ch = try read() else { throw SAXError.UnexpectedEndOfInput(self) }
        guard chars.contains(where: { $0 == ch }) else { throw SAXError.InvalidCharacter(self, found: ch, expected: chars) }
        return ch
    }

    /*===========================================================================================================================================================================*/
    /// Read a list of characters. Each character read must match it's corresponding character in the String. For example, if the string contains "FooBar" then the six (6)
    /// characters read must be "F", "o", "o", "B", "a", "r" in that order.
    /// 
    /// - Parameter string: the string to match.
    /// - Returns: the string.
    /// - Throws: if an I/O error occurs or one of the characters read does not match it's corresponding character in the string.
    ///
    @inlinable @discardableResult func readChars(mustBe string: String) throws -> String { try readChars(mustBe: string.getCharacters()) }

    /*===========================================================================================================================================================================*/
    /// Read a list of characters. Each character read must match it's corresponding character in the list. For example, if the list contains the characters "F", "o", "o", "B",
    /// "a", "r" then the six (6) characters read must be "F", "o", "o", "B", "a", "r" in that order.
    /// 
    /// - Parameter chars: the characters to match.
    /// - Returns: a string containing the characters.
    /// - Throws: if an I/O error occurs or one of the characters read does not match it's corresponding character in the list.
    ///
    @inlinable @discardableResult func readChars(mustBe chars: Character...) throws -> String { try readChars(mustBe: chars) }

    /*===========================================================================================================================================================================*/
    /// Read a list of characters. Each character read must match it's corresponding character in the array. For example, if the array contains the characters "F", "o", "o", "B",
    /// "a", "r" then the six (6) characters read must be "F", "o", "o", "B", "a", "r" in that order.
    /// 
    /// - Parameter chars: the characters to match.
    /// - Returns: a string containing the characters.
    /// - Throws: if an I/O error occurs or one of the characters read does not match it's corresponding character in the array.
    ///
    @inlinable @discardableResult func readChars(mustBe chars: [Character]) throws -> String {
        var buffer: [Character] = []
        for expected in chars {
            guard let ch = try read() else { throw SAXError.UnexpectedEndOfInput(self) }
            guard ch == expected else { throw SAXError.InvalidCharacter(self, found: ch, expected: expected) }
            buffer <+ ch
        }
        return String(buffer)
    }
}
