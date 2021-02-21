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

extension CharInputStream {
    @inlinable func readUntil(found: String, excludeFound: Bool = false) throws -> String { try readUntil(found: found.getCharacters(), excludeFound: excludeFound) }

    @inlinable func readUntil(found: Character..., excludeFound: Bool = false) throws -> String { try readUntil(found: found, excludeFound: excludeFound) }

    @inlinable func readUntil(found: [Character], excludeFound: Bool = false) throws -> String {
        try readUntil(errorOnEOF: true) { chars, bc in
            let f = (chars.last(count: found.count) == found)
            if f && excludeFound { bc = found.count }
            return f
        }
    }

    @inlinable func readTagCloser() throws {
        let char = try skipWhitespace(returnLast: false)
        guard char == ">" else { throw SAXError.InvalidCharacter(self, found: char, expected: ">") }
    }

    @inlinable func peek() throws -> Character {
        markSet()
        defer { markReturn() }
        return try readNoNil()
    }

    @inlinable func readNoNil() throws -> Character {
        guard let ch = try read() else { throw SAXError.UnexpectedEndOfInput(self) }
        return ch
    }

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

    @inlinable func readString(leadingWS: LeadingWhitespace = .None, mustBeOneOf ex: String...) throws -> String {
        let xStr = try readNMToken(leadingWS: leadingWS)
        if ex.isEmpty { return xStr }
        for yStr in ex { if xStr == yStr { return xStr } }

        var sIdx = ex.startIndex
        var m    = "\"\(ex[sIdx++])\""

        if ex.count == 2 {
            m += " or \"\(ex[sIdx])\""
        }
        else if ex.count > 2 {
            m = "one of \(ex)"
            let eIdx = (ex.endIndex - 1)
            while sIdx < eIdx { m += ", \"\(ex[sIdx++])\"" }
            m += ", or \"\(ex[sIdx])\""
        }

        throw SAXError.MissingName(self, description: "Expected \(m) but found \"\(xStr)\" instead.")
    }

    @inlinable func readUntil(errorOnEOF: Bool = true, predicate body: ([Character], inout Int) throws -> Bool) throws -> String {
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

    @inlinable @discardableResult func skipWhitespace(mustHave: Bool = false, returnLast: Bool) throws -> Character {
        markSet()
        defer { markDelete() }

        if mustHave {
            guard let ch = try read() else { throw SAXError.UnexpectedEndOfInput(self) }
            guard ch.isXmlWhitespace else { throw SAXError.InvalidCharacter(self, found: ch, expected: "␠", "␉", "␊", "␍", "␤") }
        }

        while let ch = try read() {
            if !ch.isXmlWhitespace {
                if returnLast { markBackup() }
                return ch
            }
        }

        throw SAXError.UnexpectedEndOfInput(self)
    }

    @inlinable func readWhitespace(errorOnEOF: Bool = true) throws -> String {
        var chars: [Character] = []
        while let ch = try read() {
            guard ch.isXmlWhitespace else { return String(chars) }
            chars <+ ch
        }
        if errorOnEOF { throw SAXError.UnexpectedEndOfInput(self) }
        return String(chars)
    }

    @inlinable func readQuotedString(leadingWS: LeadingWhitespace = .Allowed) throws -> String {
        markSet()
        defer { markDelete() }
        if leadingWS != .None { try skipWhitespace(mustHave: (leadingWS == .Required), returnLast: true) }
        return try readQuotedString(quote: readChar(mustBeOneOf: "\"", "'"))
    }

    @inlinable func readQuotedString(quote: Character) throws -> String {
        var chars: [Character] = []
        while let ch = try read() {
            if ch == quote { return String(chars) }
            chars <+ ch
        }
        throw SAXError.UnexpectedEndOfInput(self)
    }

    @inlinable func readOptQuotedString(leadingWS: LeadingWhitespace = .Allowed) throws -> String? {
        markSet()
        defer { markDelete() }
        if leadingWS != .None { try skipWhitespace(mustHave: (leadingWS == .Required), returnLast: true) }

        var chars = Array<Character>()
        let quote = try readNoNil()

        guard value(quote, isOneOf: "\"", "'") else { return nil }

        while let ch = try read() {
            if ch == quote { return String(chars) }
            chars <+ ch
        }

        throw SAXError.UnexpectedEndOfInput(self)
    }

    @inlinable func readNMToken(leadingWS: LeadingWhitespace = .Required) throws -> String {
        markSet()
        defer { markDelete() }
        var chars: [Character] = []
        if leadingWS != .None { try skipWhitespace(mustHave: (leadingWS == .Required), returnLast: true) }
        while let ch = try read() {
            guard ch.isXmlNameChar else {
                markBackup()
                if chars.isEmpty { throw SAXError.MissingName(self, description: "Expected a NMTOKEN but didn't find one.") }
                return String(chars)
            }
            chars <+ ch
        }
        throw SAXError.UnexpectedEndOfInput(self)
    }

    @inlinable func readName(leadingWS: LeadingWhitespace = .Required) throws -> String {
        markSet()
        defer { markDelete() }
        var chars: [Character] = []
        if leadingWS != .None { try skipWhitespace(mustHave: (leadingWS == .Required), returnLast: true) }
        while let ch = try read() {
            guard ((chars.count == 0) && ch.isXmlNameStartChar) || ch.isXmlNameChar else {
                markBackup()
                if chars.isEmpty { throw SAXError.MissingName(self, description: "Expected a name but didn't find one.") }
                return String(chars)
            }
            chars <+ ch
        }
        throw SAXError.UnexpectedEndOfInput(self)
    }

    @inlinable @discardableResult func readChar(mustBeOneOf chars: Character...) throws -> Character { try readChar(mustBeOneOf: chars) }

    @inlinable @discardableResult func readChar(mustBeOneOf chars: [Character]) throws -> Character {
        guard let ch = try read() else { throw SAXError.UnexpectedEndOfInput(self) }
        guard chars.contains(where: { $0 == ch }) else { throw SAXError.InvalidCharacter(self, found: ch, expected: chars) }
        return ch
    }

    @inlinable @discardableResult func readChars(mustBe chars: [Character]) throws -> String {
        var buffer: [Character] = []
        for expected in chars {
            guard let ch = try read() else { throw SAXError.UnexpectedEndOfInput(self) }
            guard ch == expected else { throw SAXError.InvalidCharacter(self, found: ch, expected: expected) }
            buffer <+ ch
        }
        return String(buffer)
    }

    @inlinable @discardableResult func readChars(mustBe string: String) throws -> String { try readChars(mustBe: string.getCharacters()) }
}

