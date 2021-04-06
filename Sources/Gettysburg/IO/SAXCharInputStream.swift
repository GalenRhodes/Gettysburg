/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: SAXCharInputStream.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 2/17/21
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

/*===============================================================================================================================================================================*/
/// A Regular Expression pattern for identifying the XML Declaration.
///
let XML_DECL_PREFIX_PATTERN: String      = "\\A\\<\\?(?i:xml)\\s"
/*===============================================================================================================================================================================*/
/// The list of allowed whitespace characters.
///
let XML_WS_CHAR_DESCRIPTION: [Character] = [ "␠", "␉", "␊", "␍", "␤" ]
/*===============================================================================================================================================================================*/
/// The description of the error thrown when too many characters have been read at one time.
///
let MEM_LIMIT_DESCRIPTION:   String      = "Memory Limit Reached."

/*===============================================================================================================================================================================*/
/// `SAXParser` version of the <code>[CharInputStream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code> protocol that add a number of features needed by the
/// `SAXParser`.
///
public protocol SAXCharInputStream: CharInputStream {
    /*===========================================================================================================================================================================*/
    /// The base URL associated with the input stream.
    ///
    var baseURL:  URL { get }
    /*===========================================================================================================================================================================*/
    /// The URL associated with the input stream.
    ///
    var url:      URL { get }
    /*===========================================================================================================================================================================*/
    /// The filename associated with the input stream.
    ///
    var filename: String { get }

    var parser: SAXParser { get }

    func stackNew(string: String, url: URL) throws

    func stackNew(inputStream: InputStream, url: URL) throws

    func stackNew(data: Data, url: URL) throws

    func stackNew(url: URL) throws

    func stackNew(systemId: String) throws
}

extension SAXCharInputStream {
    /*===========================================================================================================================================================================*/
    /// Read an XML Name from this <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>. This method reads characters until the
    /// first non-XML Name Character, such as whitespace, is encountered.
    /// 
    /// - Parameters:
    ///   - mustHave: if `true` then at least the starting character must be read and the returned string will not be empty. If `false` the returned string might be empty.
    ///   - errorOnEOF: if `true` and the EOF is encountered then an error is thrown. If `false` and the EOF is encountered then the characters read so far are returned.
    ///   - leadingWS: tells if any leading whitespace is allowed, required, or not allowed.
    /// - Returns: the string of characters.
    /// - Throws: if there is an I/O error or if `errorOnEOF` is `true` and the EOF is encountered.
    ///
    func readXmlName(mustHave: Bool = true, errorOnEOF: Bool = true, leadingWS: LeadingWhitespace = .Allowed) throws -> String {
        if value(leadingWS, isOneOf: .Allowed, .Required) { try skipWhitespace(mustHave: (leadingWS == .Required)) }

        markSet()
        defer { markDelete() }

        var buffer: [Character] = []

        if let ch = try read() {
            guard ch.isXmlNameStartChar else {
                markBackup()
                if mustHave { throw SAXError.InvalidCharacter(self, found: ch) }
                return ""
            }

            buffer <+ ch

            while let ch = try read() {
                guard ch.isXmlNameChar else {
                    markBackup()
                    return String(buffer)
                }
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
    func readAll() throws -> String {
        defer { close() }
        var chars: [Character] = []
        while let ch = try read() { chars <+ ch }
        return String(chars)
    }

    /*===========================================================================================================================================================================*/
    /// Read until the given string is found in input stream.
    /// 
    /// - Parameters:
    ///   - found: The search string.
    ///   - excludeFound: if `true` the search string will be excluded from the returned string.
    /// - Returns: A string containing everything until the search string was found.
    /// - Throws: If an I/O error occurred or the memory limit was breached.
    ///
    func readUntil(found: String, excludeFound: Bool = false) throws -> String {
        try readUntil(found: found.getCharacters(), excludeFound: excludeFound)
    }

    /*===========================================================================================================================================================================*/
    /// Read characters until the predicate is satisfied.
    /// 
    /// - Parameters:
    ///   - errorOnEOF: error if EOF is found.
    ///   - body: the predicate.
    /// - Returns: a string containing the characters read.
    /// - Throws: if an I/O error occurs.
    ///
    func readUntil(errorOnEOF: Bool = true, predicate body: ([Character], inout Int) throws -> Bool) throws -> String {
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
        }

        if errorOnEOF { throw SAXError.UnexpectedEndOfInput(self) }
        return String(chars)
    }

    /*===========================================================================================================================================================================*/
    /// Read until the given set of characters are found in the input stream.
    /// 
    /// - Parameters:
    ///   - found: the search characters.
    ///   - excludeFound: if `true` the search characters will be excluded from the returned string.
    /// - Returns: A string containing everything until the search characters were found.
    /// - Throws: If an I/O error occurred or the memory limit was breached.
    ///
    func readUntil(found: Character..., excludeFound: Bool = false) throws -> String {
        try readUntil(found: found, excludeFound: excludeFound)
    }

    /*===========================================================================================================================================================================*/
    /// Read until the given set of characters are found in the input stream.
    /// 
    /// - Parameters:
    ///   - found: the search characters.
    ///   - excludeFound: if `true` the search characters will be excluded from the returned string.
    /// - Returns: A string containing everything until the search characters were found.
    /// - Throws: If an I/O error occurred or the memory limit was breached.
    ///
    func readUntil(found: [Character], excludeFound: Bool = false) throws -> String {
        try readUntil(errorOnEOF: true) { chars, bc in
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
    func peek() throws -> Character {
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
    func readNoNil() throws -> Character {
        guard let ch = try read() else { throw SAXError.UnexpectedEndOfInput(self) }
        return ch
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
    @discardableResult func skipWhitespace(mustHave: Bool = false, peek: Bool = true) throws -> Character {
        markSet()
        defer { markDelete() }

        if mustHave {
            guard let ch = try read() else { throw SAXError.UnexpectedEndOfInput(self) }
            guard ch.isXmlWhitespace else { throw SAXError.InvalidCharacter(self, found: ch, expected: XML_WS_CHAR_DESCRIPTION) }
        }

        while let ch = try read() {
            if !ch.isXmlWhitespace {
                if peek { markBackup() }
                return ch
            }
            markUpdate()
        }

        throw SAXError.UnexpectedEndOfInput(self)
    }

    /*===========================================================================================================================================================================*/
    /// Read an optional quoted string. If the first non-whitespace character is a single `'` or double `"` quote then the quoted string is returned, otherwise `nil` is returned.
    /// 
    /// - Parameter leadingWS: `None` ⏤ there can be no leading whitespace; `Allowed` ⏤ leading whitespace is allowed; `Required` ⏤ leading whitespace is required.
    /// - Returns: the quoted string or `nil` is there was not one.
    /// - Throws: if there is an I/O error or the EOF is encountered before the closing quotation mark.
    ///
    func readOptQuotedString(leadingWS: LeadingWhitespace = .Allowed) throws -> String? {
        if leadingWS != .None { try skipWhitespace(mustHave: (leadingWS == .Required)) }
        let quote = try peek()
        return (value(quote, isOneOf: "\"", "'") ? try readQuotedString(leadingWS: .None, quote: quote) : nil)
    }

    /*===========================================================================================================================================================================*/
    /// Read a quoted string. Quoted strings can be delimited by double quotes `"` or single quotes `'` but the same quote that was used to open the quoted string has to be used
    /// to close it. This method assumes that any nested quotation marks are escaped in a manner that makes them NOT look like the character being used as the quotation mark. For
    /// example, using "&quot;" to escape a double quote (").
    /// 
    /// - Parameter leadingWS: `None` ⏤ there can be no leading whitespace; `Allowed` ⏤ leading whitespace is allowed; `Required` ⏤ leading whitespace is required.
    /// - Returns: the quoted string.
    /// - Throws: if there is an I/O error or the EOF is encountered before the closing quotation mark.
    ///
    func readQuotedString(leadingWS: LeadingWhitespace = .Allowed) throws -> String {
        try readQuotedString(leadingWS: leadingWS, quote: "\"", "'")
    }

    /*===========================================================================================================================================================================*/
    /// Read a quoted string. You can specify any character to use as the quotation mark but the same character must be used for the open and close. This method assumes that any
    /// nested quotation marks are escaped in a manner that makes them NOT look like the character being used as the quotation mark. For example, using "&quot;" to escape a double
    /// quote (").
    /// 
    /// - Parameter quote: the `character(s)` to use as the quotation mark.
    /// - Returns: the string.
    /// - Throws: if an I/O error occurs.
    ///
    func readQuotedString(leadingWS: LeadingWhitespace = .Allowed, quote: Character...) throws -> String {
        try readQuotedString(leadingWS: leadingWS, quote: quote)
    }

    /*===========================================================================================================================================================================*/
    /// Read a quoted string. You can specify any character to use as the quotation mark but the same character must be used for the open and close. This method assumes that any
    /// nested quotation marks are escaped in a manner that makes them NOT look like the character being used as the quotation mark. For example, using "&quot;" to escape a double
    /// quote (").
    /// 
    /// - Parameter quote: the `character(s)` to use as the quotation mark.
    /// - Returns: the string.
    /// - Throws: if an I/O error occurs.
    ///
    func readQuotedString(leadingWS: LeadingWhitespace = .Allowed, quote: [Character]) throws -> String {
        markSet()
        defer { markDelete() }
        if leadingWS != .None { try skipWhitespace(mustHave: (leadingWS == .Required)) }
        let qt = try readChar(mustBeOneOf: quote)

        var chars: [Character] = []

        while let ch = try read() {
            if ch == qt { return String(chars) }
            chars <+ ch
        }

        throw SAXError.UnexpectedEndOfInput(self)
    }

    /*===========================================================================================================================================================================*/
    /// Read a key/value pair from the input stream. A key/value pair is an XML name followed by an equals sign followed by a quoted string. Single or double quotes can be used
    /// for the quoted string.
    /// 
    /// Example:
    /// ```
    ///     foo="bar"
    ///     foo='bar'
    /// ```
    /// 
    /// There cannot be any whitespace around the equals sign.
    /// 
    /// - Parameter leadingWS: specifies if any whitespace is allowed before the key.
    /// - Returns: an instance of KVPair.
    /// - Throws: if an I/O error occurs or if the key/value pair is malformed.
    ///
    func readKeyValuePair(leadingWS: LeadingWhitespace = .Allowed) throws -> KVPair {
        let key = try readXmlName(mustHave: true, errorOnEOF: true, leadingWS: leadingWS)
        try readChar(mustBeOneOf: "=")
        let val = try readQuotedString(leadingWS: .None, quote: "\"", "'")
        return (key, val)
    }

    /*===========================================================================================================================================================================*/
    /// Read the next character and make sure that it is one of the given characters.
    /// 
    /// - Parameter chars: the list of possibly correct characters.
    /// - Returns: the character read.
    /// - Throws: if there is an I/O error or the character read is not one of the given characters.
    ///
    @discardableResult func readChar(mustBeOneOf chars: Character...) throws -> Character {
        try readChar(mustBeOneOf: chars)
    }

    /*===========================================================================================================================================================================*/
    /// Read the next character and make sure that it is one of the given characters.
    /// 
    /// - Parameter chars: the list of possibly correct characters.
    /// - Returns: the character read.
    /// - Throws: if there is an I/O error or the character read is not one of the given characters.
    ///
    @discardableResult func readChar(mustBeOneOf chars: [Character]) throws -> Character {
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
    @discardableResult func readChars(mustBe string: String) throws -> String { try readChars(mustBe: string.getCharacters()) }

    /*===========================================================================================================================================================================*/
    /// Read a list of characters. Each character read must match it's corresponding character in the list. For example, if the list contains the characters "F", "o", "o", "B",
    /// "a", "r" then the six (6) characters read must be "F", "o", "o", "B", "a", "r" in that order.
    /// 
    /// - Parameter chars: the characters to match.
    /// - Returns: a string containing the characters.
    /// - Throws: if an I/O error occurs or one of the characters read does not match it's corresponding character in the list.
    ///
    @discardableResult func readChars(mustBe chars: Character...) throws -> String { try readChars(mustBe: chars) }

    /*===========================================================================================================================================================================*/
    /// Read a list of characters. Each character read must match it's corresponding character in the array. For example, if the array contains the characters "F", "o", "o", "B",
    /// "a", "r" then the six (6) characters read must be "F", "o", "o", "B", "a", "r" in that order.
    /// 
    /// - Parameter chars: the characters to match.
    /// - Returns: a string containing the characters.
    /// - Throws: if an I/O error occurs or one of the characters read does not match it's corresponding character in the array.
    ///
    @discardableResult func readChars(mustBe chars: [Character]) throws -> String {
        var buffer: [Character] = []
        for expected in chars {
            guard let ch = try read() else { throw SAXError.UnexpectedEndOfInput(self) }
            guard ch == expected else { throw SAXError.InvalidCharacter(self, found: ch, expected: expected) }
            buffer <+ ch
        }
        return String(buffer)
    }
}
