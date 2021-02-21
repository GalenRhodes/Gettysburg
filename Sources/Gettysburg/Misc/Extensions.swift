/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: Extensions.swift
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

extension SAXExternalType: CustomStringConvertible {
    public var description: String {
        switch self {
            case .Internal:return "Internal"
            case .Public: return "Public"
            case .System: return "System"
        }
    }
}

extension SAXAttributeDefaultType: CustomStringConvertible {
    public var description: String {
        switch self {
            case .Optional: return "Optional"
            case .Required: return "Required"
            case .Implied: return "Implied"
            case .Fixed: return "Fixed"
        }
    }
}

extension SAXAttributeType: CustomStringConvertible {
    public var description: String {
        switch self {
            case .CData: return "CData"
            case .ID: return "ID"
            case .IDRef: return "IDRef"
            case .IDRefs: return "IDRefs"
            case .Entity: return "Entity"
            case .Entities: return "Entities"
            case .NMToken: return "NMToken"
            case .NMTokens: return "NMTokens"
            case .Notation: return "Notation"
            case .Enumerated: return "Enumerated"
        }
    }
}

extension SAXEntityType: CustomStringConvertible {
    public var description: String {
        switch self {
            case .General: return "General"
            case .Parameter: return "Parameter"
        }
    }
}

extension SAXElementAllowedContent: CustomStringConvertible {
    public var description: String {
        switch self {
            case .Empty: return "Empty"
            case .Elements: return "Elements"
            case .Mixed: return "Mixed"
            case .Any: return "Any"
        }
    }
}

extension SAXElementDeclItem.ItemType: CustomStringConvertible {
    public var description: String {
        switch self {
            case .Element: return "Element"
            case .List: return "List"
            case .PCData: return "PCData"
        }
    }
}

extension SAXElementDeclItem.ItemMultiplicity: CustomStringConvertible {
    public var description: String {
        switch self {
            case .Optional: return "Optional"
            case .Once: return "Once"
            case .ZeroOrMore: return "ZeroOrMore"
            case .OneOrMore: return "OneOrMore"
        }
    }
}

extension SAXElementDeclList.ItemConjunction: CustomStringConvertible {
    public var description: String {
        switch self {
            case .And: return "And"
            case .Or: return "Or"
        }
    }
}

extension InputStream {
    @inlinable func read() throws -> UInt8? {
        var byte: UInt8 = 0
        let res:  Int   = read(&byte, maxLength: 1)
        guard res >= 0 else { throw streamError ?? StreamError.UnknownError() }
        guard res > 0 else { return nil }
        return byte
    }
}

extension Array {
    @inlinable func last(count cc: Int) -> ArraySlice<Element> { self[index(endIndex, offsetBy: -Swift.min(cc, count)) ..< endIndex] }

    @inlinable func first(count cc: Int) -> ArraySlice<Element> { self[startIndex ..< index(startIndex, offsetBy: Swift.min(cc, count))] }
}

extension ArraySlice {
    @inlinable func last(count cc: Int) -> ArraySlice<Element> { self[index(endIndex, offsetBy: -Swift.min(cc, count)) ..< endIndex] }

    @inlinable func first(count cc: Int) -> ArraySlice<Element> { self[startIndex ..< index(startIndex, offsetBy: Swift.min(cc, count))] }
}

extension String {
    @inlinable func getChar(at idx: Int) -> Character? {
        guard let i = index(at: idx) else { return nil }
        return self[i]
    }

    @inlinable func index(at position: Int) -> String.Index? {
        let limit = index(before: endIndex)
        return index(startIndex, offsetBy: position, limitedBy: limit)
    }

    func getInvalidCharInfo(strings: String...) -> (Character, [Character]) { foo(startIndex, 0, strings) }

    func getInvalidCharInfo(strings: [String]) -> (Character, [Character]) { foo(startIndex, 0, strings) }

    private func foo(_ idx: Index, _ pos: Int, _ strList: [String]) -> (Character, [Character]) {
        guard idx < endIndex else { return (self[startIndex], []) }

        let ch1:      Character      = self[idx]
        var nStrList: [String]       = []
        var charSet:  Set<Character> = []

        for str: String in strList {
            if let ch2: Character = str.getChar(at: pos) {
                charSet.insert(ch2)
                if ch1 == ch2 { nStrList <+ str }
            }
        }

        if nStrList.isEmpty { return (ch1, charSet.map({ $0 }).sorted()) }
        return foo(self.index(after: idx), (pos + 1), nStrList)
    }
}

