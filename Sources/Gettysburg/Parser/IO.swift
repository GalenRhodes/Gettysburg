/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: IO.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 2/8/21
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

extension SAXParser {

    /*===========================================================================================================================================================================*/
    /// Read and return a quoted string.
    ///
    /// - Returns: the text in between double quotes (") or single quotes (')
    /// - Throws: if an I/O error occurs or if the EOF is encountered before the closing quotation mark is found.
    ///
    @usableFromInline func readQuotedString() throws -> String { try readQuotedString(charStream) }

    /*===========================================================================================================================================================================*/
    /// Read and return a quoted string.
    ///
    /// - Parameter chStream: the [input stream](http://goober/Rubicon/Protocols/CharInputStream.html) to read from.
    /// - Returns: the text in between double quotes (") or single quotes (')
    /// - Throws: if an I/O error occurs or if the EOF is encountered before the closing quotation mark is found.
    ///
    @usableFromInline func readQuotedString(_ chStream: CharInputStream) throws -> String {
        var buffer: [Character] = []

        while let ch = try chStream.read() {
            if ch == "\"" || ch == "'" {
                let quoteChar = ch

                while let ch = try chStream.read() {
                    if ch == quoteChar { return String(buffer) }
                    else if ch == "&" { buffer.append(contentsOf: try readAndResolveEntityReference()) }
                    else { buffer <+ ch }
                }

                throw SAXError.UnexpectedEndOfInput(chStream)
            }
            else if !ch.isXmlWhitespace {
                throw SAXError.InvalidCharacter(chStream, description: getBadCharMsg3(expected: "\"", "'", found: ch))
            }
        }

        throw SAXError.UnexpectedEndOfInput(chStream)
    }

    /*===========================================================================================================================================================================*/
    /// Read and return all the <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> up to but not including the first encountered NON-whitespace
    /// <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>.
    ///
    /// - Parameter noEOF: if `true` then an error is thrown if the EOF is encountered before the first non-whitespace
    ///                    <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> is found. The default is `false`.
    /// - Returns: the <code>[String](https://developer.apple.com/documentation/swift/String)</code> of
    ///            <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s read.
    /// - Throws: if an I/O error occurs or `noEOF` is `true` and the EOF is encountered before the first non-whitespace
    ///           <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> is found.
    ///
    @discardableResult @usableFromInline func readWhitespace(noEOF: Bool = false) throws -> String { try readWhitespace(charStream, noEOF: noEOF) }

    /*===========================================================================================================================================================================*/
    /// Read and return all the <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> up to but not including the first encountered NON-whitespace
    /// <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>.
    ///
    /// - Parameters:
    ///   - chStream: the [input stream](http://goober/Rubicon/Protocols/CharInputStream.html) to read from.
    ///   - noEOF: if `true` then an error is thrown if the EOF is encountered before the first non-whitespace
    ///            <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> is found. The default is `false`.
    /// - Returns: the <code>[String](https://developer.apple.com/documentation/swift/String)</code> of
    ///            <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s read.
    /// - Throws: if an I/O error occurs or `noEOF` is `true` and the EOF is encountered before the first non-whitespace
    ///           <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> is found.
    ///
    @discardableResult @usableFromInline func readWhitespace(_ chStream: CharInputStream, noEOF: Bool = false) throws -> String {
        var buffer: [Character] = []
        while let ch = try chStream.read() {
            guard ch.isXmlWhitespace else {
                chStream.push(char: ch)
                return String(buffer)
            }
            buffer <+ ch
        }
        if noEOF { throw SAXError.UnexpectedEndOfInput(chStream) }
        return String(buffer)
    }

    /*===========================================================================================================================================================================*/
    /// Skip past all the <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> up to but not including the first encountered NON-whitespace
    /// <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>.
    ///
    /// - Parameters:
    ///   - mustHave: if `true` then there has to be at least ONE whitespace character.
    ///   - push: if '`true`' the first non-whitespace character encountered will be pushed back into the input stream as well as being returned. The default is `false`.
    /// - Returns: the fist non-whitespace character.
    /// - Throws: if an I/O error occurs or `noEOF` is `true` and the EOF is encountered before the first non-whitespace
    ///           <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> is found.
    ///
    @discardableResult @inlinable func skipWhitespace(mustHave: Bool = true, push: Bool = false) throws -> Character { try skipWhitespace(charStream, mustHave: mustHave, push: push) }

    /*===========================================================================================================================================================================*/
    /// Skip past all the <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> up to but not including the first encountered NON-whitespace
    /// <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>.
    ///
    /// - Parameters:
    ///   - chStream: the [input stream](http://goober/Rubicon/Protocols/CharInputStream.html) to read from.
    ///   - mustHave: if `true` then there has to be at least ONE whitespace character. The default is `true`.
    ///   - push: if '`true`' the first non-whitespace character encountered will be pushed back into the input stream as well as being returned. The default is `false`.
    /// - Returns: the fist non-whitespace character.
    /// - Throws: if an I/O error occurs or `noEOF` is `true` and the EOF is encountered before the first non-whitespace
    ///           <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> is found.
    ///
    @discardableResult @inlinable func skipWhitespace(_ chStream: CharInputStream, mustHave: Bool = true, push: Bool = false) throws -> Character {
        if mustHave {
            guard let ch = try chStream.read() else { throw SAXError.UnexpectedEndOfInput(chStream) }
            guard ch.isXmlWhitespace else { throw SAXError.InvalidCharacter(chStream, description: "Expected space, new line, or tab character but found \"\(ch)\" instead.") }
        }
        while let ch = try chStream.read() {
            guard ch.isXmlWhitespace else {
                if push { chStream.push(char: ch) }
                return ch
            }
        }
        throw SAXError.UnexpectedEndOfInput(chStream)
    }

    /*===========================================================================================================================================================================*/
    /// Read `count` number of <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s from the [input
    /// stream](http://goober/Rubicon/Protocols/CharInputStream.html) and return them as a string.
    ///
    /// - Parameters:
    ///   - count: the number of <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s to read.
    ///   - exact: if true and the number of character read before EOF is encountered is less than count then an exception is thrown. Default is true.
    /// - Returns: the number of <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s read.
    /// - Throws: if there is an I/O error or if there are fewer than `count` <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s left in the
    ///           input stream.
    ///
    @inlinable func readString(count: Int, exact: Bool = true) throws -> String { try readString(charStream, count: count, exact: exact) }

    /*===========================================================================================================================================================================*/
    /// Read `count` number of <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s from the [input
    /// stream](http://goober/Rubicon/Protocols/CharInputStream.html) and return them as a string.
    ///
    /// - Parameters:
    ///   - chStream: the [input stream](http://goober/Rubicon/Protocols/CharInputStream.html) to read from.
    ///   - count: the number of <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s to read.
    ///   - exact: if true and the number of character read before EOF is encountered is less than count then an exception is thrown. Default is true.
    /// - Returns: the number of <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s read.
    /// - Throws: if there is an I/O error or if there are fewer than `count` <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s left in the
    ///           input stream.
    ///
    @inlinable func readString(_ chStream: CharInputStream, count: Int, exact: Bool = true) throws -> String {
        var buffer: [Character] = []
        for _ in (0 ..< count) {
            guard let ch = try chStream.read() else {
                if exact { throw SAXError.UnexpectedEndOfInput(chStream) }
                return String(buffer)
            }
            buffer <+ ch
        }
        return String(buffer)
    }

    /*===========================================================================================================================================================================*/
    /// Read and return all the <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s up to but not including the first encountered whitespace
    /// <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>.
    ///
    /// - Returns: The <code>[String](https://developer.apple.com/documentation/swift/String)</code> of
    ///            <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s read.
    /// - Throws: if an I/O error occurs.
    ///
    @usableFromInline func readUntilWhitespace() throws -> String { try readUntilWhitespace(charStream) }

    /*===========================================================================================================================================================================*/
    /// Read and return all the <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s up to but not including the first encountered whitespace
    /// <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>.
    ///
    /// - Parameter chStream: the [input stream](http://goober/Rubicon/Protocols/CharInputStream.html) to read from.
    /// - Returns: The <code>[String](https://developer.apple.com/documentation/swift/String)</code> of
    ///            <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s read.
    /// - Throws: if an I/O error occurs.
    ///
    @usableFromInline func readUntilWhitespace(_ chStream: CharInputStream) throws -> String { try doReadUntil(chStream, backup: true) { ch, _ in ch.isXmlWhitespace } }

    /*===========================================================================================================================================================================*/
    /// Read until the given set of <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s is found.
    ///
    /// - Parameter marker: the sequence of <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s that will trigger the end of the read.
    /// - Returns: The <code>[String](https://developer.apple.com/documentation/swift/String)</code> of
    ///            <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s read from the input.
    /// - Throws: if an I/O error occurs or the EOF is reached before the marker is located.
    ///
    @usableFromInline func readUntil(marker mrk: Character...) throws -> String { try readUntil(charStream, marker: mrk) }

    /*===========================================================================================================================================================================*/
    /// Read until the given set of <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s is found.
    ///
    /// - Parameters:
    ///   - chStream: the [input stream](http://goober/Rubicon/Protocols/CharInputStream.html) to read from.
    ///   - marker: the sequence of <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s that will trigger the end of the read.
    /// - Returns: The <code>[String](https://developer.apple.com/documentation/swift/String)</code> of
    ///            <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s read from the input.
    /// - Throws: if an I/O error occurs or the EOF is reached before the marker is located.
    ///
    @usableFromInline func readUntil(_ chStream: CharInputStream, marker mrk: Character...) throws -> String { try readUntil(chStream, marker: mrk) }

    /*===========================================================================================================================================================================*/
    /// Read until the given set of <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s is found.
    ///
    /// - Parameters:
    ///   - chStream: the [input stream](http://goober/Rubicon/Protocols/CharInputStream.html) to read from.
    ///   - marker: the sequence of <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s that will trigger the end of the read.
    /// - Returns: The <code>[String](https://developer.apple.com/documentation/swift/String)</code> of
    ///            <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s read from the input.
    /// - Throws: if an I/O error occurs or the EOF is reached before the marker is located.
    ///
    @usableFromInline func readUntil(_ chStream: CharInputStream, marker mrk: [Character]) throws -> String { try doReadUntil(chStream) { buf in cmpSuffix(suffix: mrk, source: buf) } }

    /*===========================================================================================================================================================================*/
    /// Read <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s from the [input stream](http://goober/Rubicon/Protocols/CharInputStream.html) and
    /// make sure they match the given <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s in the order they're given.
    ///
    /// - Parameter chars: the list of expected <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s.
    /// - Returns: the string from the <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s.
    /// - Throws: if an I/O error occurs, the EOF is encountered, or the read <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s don't match the
    ///           <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s in the list.
    ///
    @discardableResult @inlinable func readCharAnd(expected chars: Character...) throws -> String { try readCharAnd(charStream, expected: chars) }

    /*===========================================================================================================================================================================*/
    /// Read <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s from the [input stream](http://goober/Rubicon/Protocols/CharInputStream.html) and
    /// make sure they match the given <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s in the order they're given.
    ///
    /// - Parameters:
    ///   - chStream: the [input stream](http://goober/Rubicon/Protocols/CharInputStream.html) to read from.
    ///   - chars: the list of expected <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s.
    /// - Returns: the string from the <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s.
    /// - Throws: if an I/O error occurs, the EOF is encountered, or the read <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s don't match the
    ///           <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s in the list.
    ///
    @discardableResult @inlinable func readCharAnd(_ chStream: CharInputStream, expected chars: Character...) throws -> String { try readCharAnd(chStream, expected: chars) }

    /*===========================================================================================================================================================================*/
    /// Read <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s from the [input stream](http://goober/Rubicon/Protocols/CharInputStream.html) and
    /// make sure they match the given <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s in the order they're given.
    ///
    /// - Parameters:
    ///   - chStream: the [input stream](http://goober/Rubicon/Protocols/CharInputStream.html) to read from.
    ///   - chars: the list of expected <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s.
    /// - Returns: the string from the <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s.
    /// - Throws: if an I/O error occurs, the EOF is encountered, or the read <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s don't match the
    ///           <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s in the list.
    ///
    @discardableResult @inlinable func readCharAnd(_ chStream: CharInputStream, expected chars: [Character]) throws -> String {
        guard !chars.isEmpty else { fatalError() }
        var buffer: [Character] = []

        for ch1 in chars {
            guard let ch2 = try chStream.read() else { throw SAXError.UnexpectedEndOfInput(chStream) }
            guard ch1 == ch2 else {
                chStream.push(char: ch2)
                throw SAXError.InvalidCharacter(chStream, description: getBadCharMsg2(expected: ch1, found: ch2))
            }

            buffer <+ ch2
        }

        return String(buffer)
    }

    /*===========================================================================================================================================================================*/
    /// Read <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s from the [input stream](http://goober/Rubicon/Protocols/CharInputStream.html) and
    /// make sure they match the <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s in the given string in the order they're given.
    ///
    /// - Parameter string: the string containing the expected <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s.
    /// - Returns: the string from the <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s.
    /// - Throws: if an I/O error occurs, the EOF is encountered, or the read <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s don't match the
    ///           <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s in the list.
    ///
    @discardableResult @inlinable func readCharAnd(expected string: String) throws -> String { try readCharAnd(charStream, expected: string) }

    /*===========================================================================================================================================================================*/
    /// Read <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s from the [input stream](http://goober/Rubicon/Protocols/CharInputStream.html) and
    /// make sure they match the <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s in the given string in the order they're given.
    ///
    /// - Parameters:
    ///   - chStream: the [input stream](http://goober/Rubicon/Protocols/CharInputStream.html) to read from.
    ///   - string: the string containing the expected <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s.
    /// - Returns: the string from the <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s.
    /// - Throws: if an I/O error occurs, the EOF is encountered, or the read <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s don't match the
    ///           <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s in the list.
    ///
    @discardableResult @inlinable func readCharAnd(_ chStream: CharInputStream, expected string: String) throws -> String {
        guard !string.isEmpty else { fatalError() }
        var buffer: [Character] = []

        for sc in string.unicodeScalars {
            let ch1 = Character(sc)

            guard let ch2 = try chStream.read() else { throw SAXError.UnexpectedEndOfInput(chStream) }
            guard ch1 == ch2 else {
                chStream.push(char: ch2)
                throw SAXError.InvalidCharacter(chStream, description: getBadCharMsg2(expected: ch1, found: ch2))
            }

            buffer <+ ch2
        }

        return String(buffer)
    }

    /*===========================================================================================================================================================================*/
    /// Read the next <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> from the [input
    /// stream](http://goober/Rubicon/Protocols/CharInputStream.html) and make sure it matches the any of the expected
    /// <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s.
    ///
    /// - Parameter chars: the list of expected <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s.
    /// - Returns: the <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> read.
    /// - Throws: if an I/O error occurs, the EOF is encountered, or the read <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> is not any of the
    ///           expected <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s.
    ///
    @discardableResult @inlinable func readCharOr(expected chars: Character...) throws -> Character { try readCharOr(charStream, expected: chars) }

    /*===========================================================================================================================================================================*/
    /// Read the next <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> from the [input
    /// stream](http://goober/Rubicon/Protocols/CharInputStream.html) and make sure it matches the any of the expected
    /// <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s.
    ///
    /// - Parameters:
    ///   - chStream: the [input stream](http://goober/Rubicon/Protocols/CharInputStream.html) to read from.
    ///   - chars: the list of expected <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s.
    /// - Returns: the <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> read.
    /// - Throws: if an I/O error occurs, the EOF is encountered, or the read <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> is not any of the
    ///           expected <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s.
    ///
    @discardableResult @inlinable func readCharOr(_ chStream: CharInputStream, expected chars: Character...) throws -> Character { try readCharOr(chStream, expected: chars) }

    /*===========================================================================================================================================================================*/
    /// Read the next <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> from the [input
    /// stream](http://goober/Rubicon/Protocols/CharInputStream.html) and make sure it matches the any of the expected
    /// <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s.
    ///
    /// - Parameters:
    ///   - chStream: the [input stream](http://goober/Rubicon/Protocols/CharInputStream.html) to read from.
    ///   - chars: the list of expected <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s.
    /// - Returns: the <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> read.
    /// - Throws: if an I/O error occurs, the EOF is encountered, or the read <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> is not any of the
    ///           expected <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s.
    ///
    @discardableResult @inlinable func readCharOr(_ chStream: CharInputStream, expected chars: [Character]) throws -> Character {
        guard !chars.isEmpty else { fatalError() }
        guard let ch = try chStream.read() else { throw SAXError.UnexpectedEndOfInput(chStream) }
        if chars.isAny(predicate: { $0 == ch }) { return ch }
        throw SAXError.InvalidCharacter(chStream, description: getBadCharMsg3(expected: chars, found: ch))
    }

    /*===========================================================================================================================================================================*/
    /// Read a single <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> from the input stream.
    ///
    /// - Returns: the <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> read.
    /// - Throws: if an I/O error occurs or the EOF is encountered.
    ///
    @inlinable func readChar() throws -> Character { try readChar(charStream) }

    /*===========================================================================================================================================================================*/
    /// Read a single <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> from the input stream.
    ///
    /// - Parameter chStream: the [input stream](http://goober/Rubicon/Protocols/CharInputStream.html) to read from.
    /// - Returns: the <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> read.
    /// - Throws: if an I/O error occurs or the EOF is encountered.
    ///
    @inlinable func readChar(_ chStream: CharInputStream) throws -> Character {
        guard let ch = try chStream.read() else { throw SAXError.UnexpectedEndOfInput(chStream) }
        return ch
    }

    /*===========================================================================================================================================================================*/
    /// Read an [XML name](https://www.w3.org/TR/REC-xml/#sec-common-syn) from the input stream.
    ///
    /// - Returns: the XML name.
    /// - Throws: if an I/O error occurs.
    ///
    @inlinable func readXmlName() throws -> String { try readXmlName(charStream) }

    /*===========================================================================================================================================================================*/
    /// Read an [XML name](https://www.w3.org/TR/REC-xml/#sec-common-syn) from the input stream.
    ///
    /// - Parameter chStream: the [input stream](http://goober/Rubicon/Protocols/CharInputStream.html) to read from.
    /// - Returns: the XML name.
    /// - Throws: if an I/O error occurs.
    ///
    @inlinable func readXmlName(_ chStream: CharInputStream) throws -> String {
        try doReadUntil(chStream, backup: true) { ch, cc in !((cc == 0) ? ch.isXmlNameStartChar : ch.isXmlNameChar) }
    }

    /*===========================================================================================================================================================================*/
    /// Read an [XML NMTOKEN](https://www.w3.org/TR/REC-xml/#sec-common-syn) from the input stream.
    ///
    /// - Returns: the XML name.
    /// - Throws: if an I/O error occurs.
    ///
    @inlinable func readXmlNmtoken() throws -> String { try readXmlNmtoken(charStream) }

    /*===========================================================================================================================================================================*/
    /// Read an [XML NMTOKEN](https://www.w3.org/TR/REC-xml/#sec-common-syn) from the input stream.
    ///
    /// - Parameter chStream: the [input stream](http://goober/Rubicon/Protocols/CharInputStream.html) to read from.
    /// - Returns: the XML name.
    /// - Throws: if an I/O error occurs.
    ///
    @inlinable func readXmlNmtoken(_ chStream: CharInputStream) throws -> String { try doReadUntil(chStream, backup: true) { ch, _ in !ch.isXmlNameChar } }

    /*===========================================================================================================================================================================*/
    /// Read from the [character input stream](http://goober/Rubicon/Protocols/CharInputStream.html) until the given
    /// <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> is found.
    ///
    /// - Parameter ch: the given <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>.
    /// - Returns: the string of <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s up to, but not including, the given
    ///            <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>.
    /// - Throws: if an I/O error occurs or the EOF is encountered before the <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> is found.
    ///
    @inlinable func readUntil(character ch: Character) throws -> String { try readUntil(charStream, character: ch) }

    /*===========================================================================================================================================================================*/
    /// Read from the [character input stream](http://goober/Rubicon/Protocols/CharInputStream.html) until the given
    /// <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> is found.
    ///
    /// - Parameters:
    ///   - chStream: the [input stream](http://goober/Rubicon/Protocols/CharInputStream.html) to read from.
    ///   - ch: the given <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>.
    /// - Returns: the string of <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s up to, but not including, the given
    ///            <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>.
    /// - Throws: if an I/O error occurs or the EOF is encountered before the <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> is found.
    ///
    @inlinable func readUntil(_ chStream: CharInputStream, character ch: Character) throws -> String { try doReadUntil(chStream, backup: true) { c0, _ in ch == c0 } }

    /*===========================================================================================================================================================================*/
    /// Read <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s from the [input stream](http://goober/Rubicon/Protocols/CharInputStream.html)
    /// until the closure returns `true`. The closure is called for each <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> read. When the closure
    /// returns `true` then reading will stop and a string containing the <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s read is returned.
    ///
    /// - Parameters:
    ///   - backup: if `true` then the last `count` <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s are returned to the [input
    ///             stream](http://goober/Rubicon/Protocols/CharInputStream.html) to be read again.
    ///   - cc: the number of <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s to return to the input stream.
    ///   - body: a closure that receives the last <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> read and the total number of
    ///           <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s read so far. When the closure returns `true` reading will stop.
    /// - Returns: the string of <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s read.
    /// - Throws: if an I/O error occurs or any error thrown by the closure.
    ///
    @inlinable func doReadUntil(backup: Bool = false, count cc: Int = 1, predicate body: (Character, Int) throws -> Bool) throws -> String {
        try doReadUntil(charStream, backup: backup, count: cc, predicate: body)
    }

    /*===========================================================================================================================================================================*/
    /// Read <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s from the [input stream](http://goober/Rubicon/Protocols/CharInputStream.html)
    /// until the closure returns `true`. The closure is called for each <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> read. When the closure
    /// returns `true` then reading will stop and a string containing the <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s read is returned.
    ///
    /// - Parameters:
    ///   - chStream: the [input stream](http://goober/Rubicon/Protocols/CharInputStream.html) to read from.
    ///   - backup: if `true` then the last `count` <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s are returned to the [input
    ///             stream](http://goober/Rubicon/Protocols/CharInputStream.html) to be read again.
    ///   - cc: the number of <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s to return to the input stream.
    ///   - body: a closure that receives the last <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> read and the total number of
    ///           <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s read so far. When the closure returns `true` reading will stop.
    /// - Returns: the string of <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s read.
    /// - Throws: if an I/O error occurs or any error thrown by the closure.
    ///
    @inlinable func doReadUntil(_ chStream: CharInputStream, backup: Bool = false, count cc: Int = 1, predicate body: (Character, Int) throws -> Bool) throws -> String {
        try doRead(charInputStream: chStream) { ch, buffer in
            if try body(ch, buffer.count) {
                if backup { chStream.markBackup(count: cc) }
                return true
            }
            buffer <+ ch
            return false
        }
    }

    /*===========================================================================================================================================================================*/
    /// Read <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s from the [input stream](http://goober/Rubicon/Protocols/CharInputStream.html)
    /// until the closure returns `true`. The closure is called for each <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> read. When the closure
    /// returns `true` then reading will stop and a string containing the <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s read is returned.
    ///
    /// - Parameters:
    ///   - backup: if `true` then the last `count` <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s are returned to the [input
    ///             stream](http://goober/Rubicon/Protocols/CharInputStream.html) to be read again.
    ///   - cc: the number of <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s to return to the input stream.
    ///   - body: a closure that receives the all the <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s read so far. When the closure returns
    ///           `true` reading will stop.
    /// - Returns: the string of <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s read.
    /// - Throws: if an I/O error occurs or any error thrown by the closure.
    ///
    @inlinable func doReadUntil(backup: Bool = false, count cc: Int = 1, predicate body: ([Character]) throws -> Bool) throws -> String {
        try doReadUntil(charStream, backup: backup, count: cc, predicate: body)
    }

    /*===========================================================================================================================================================================*/
    /// Read <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s from the [input stream](http://goober/Rubicon/Protocols/CharInputStream.html)
    /// until the closure returns `true`. The closure is called for each <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> read. When the closure
    /// returns `true` then reading will stop and a string containing the <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s read is returned.
    ///
    /// - Parameters:
    ///   - backup: if `true` then the last `count` <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s are returned to the [input
    ///             stream](http://goober/Rubicon/Protocols/CharInputStream.html) to be read again.
    ///   - cc: the number of <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s to return to the input stream.
    ///   - body: a closure that receives the all the <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s read so far. When the closure returns
    ///           `true` reading will stop.
    /// - Returns: the string of <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s read.
    /// - Throws: if an I/O error occurs or any error thrown by the closure.
    ///
    @inlinable func doReadUntil(_ chStream: CharInputStream, backup: Bool = false, count cc: Int = 1, predicate body: ([Character]) throws -> Bool) throws -> String {
        try doRead(charInputStream: chStream) { ch, buffer in
            buffer <+ ch
            guard try body(buffer) else { return false }
            if backup {
                chStream.markBackup(count: cc)
                buffer.removeLast(cc)
            }
            return true
        }
    }

    /*===========================================================================================================================================================================*/
    /// Read <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s from the [character input
    /// stream](http://goober/Rubicon/Protocols/CharInputStream.html) and pass them to the closure along with a
    /// <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> <code>[Array](https://developer.apple.com/documentation/swift/Array)</code>. When the
    /// closure returns `true` then the <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>
    /// <code>[Array](https://developer.apple.com/documentation/swift/Array)</code> will be wrapped in a string and returned.
    ///
    /// - Parameter body: the closure.
    /// - Returns: a new string made from the contents of the <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>
    ///            <code>[Array](https://developer.apple.com/documentation/swift/Array)</code> passed to the closure.
    /// - Throws: any error thrown by the closure or if an I/O error occurs or the EOF is encountered.
    ///
    @inlinable func doRead(_ body: (Character, inout [Character]) throws -> Bool) throws -> String { try doRead(charInputStream: charStream, body) }

    /*===========================================================================================================================================================================*/
    /// Read <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>s from the [character input
    /// stream](http://goober/Rubicon/Protocols/CharInputStream.html) and pass them to the closure along with a
    /// <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> <code>[Array](https://developer.apple.com/documentation/swift/Array)</code>. When the
    /// closure returns `true` then the <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>
    /// <code>[Array](https://developer.apple.com/documentation/swift/Array)</code> will be wrapped in a string and returned.
    ///
    /// - Parameters:
    ///   - cString: the [character input stream](http://goober/Rubicon/Protocols/CharInputStream.html) to read from.
    ///   - body: the closure.
    /// - Returns: a new string made from the contents of the <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>
    ///            <code>[Array](https://developer.apple.com/documentation/swift/Array)</code> passed to the closure.
    /// - Throws: any error thrown by the closure or if an I/O error occurs or the EOF is encountered.
    ///
    @inlinable func doRead(charInputStream chStream: CharInputStream, _ body: (Character, inout [Character]) throws -> Bool) throws -> String {
        do {
            chStream.markSet()
            defer { chStream.markDelete() }

            var chars: [Character] = []

            while let ch = try chStream.read() {
                if try body(ch, &chars) {
                    return String(chars)
                }
            }
        }
        catch let e {
            chStream.markBackup()
            throw e
        }

        throw SAXError.UnexpectedEndOfInput(chStream)
    }

    @inlinable func markSet() { charStream.markSet() }

    @inlinable func markDelete() { charStream.markDelete() }

    @inlinable func markReturn() { charStream.markReturn() }

    @inlinable func markUpdate() { charStream.markUpdate() }

    @inlinable func markReset() { charStream.markReset() }

    @inlinable func markBackup(count: Int = 1) { charStream.markBackup(count: count) }
}
