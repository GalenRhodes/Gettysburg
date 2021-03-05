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
    @inlinable public var description: String {
        switch self {
            case .Internal:return "Internal"
            case .Public:  return "Public"
            case .System:  return "System"
        }
    }

    @inlinable static func valueFor(description desc: String) -> SAXExternalType {
        switch desc {
            case "Public": return .Public
            case "System": return .System
            default:       return .Internal
        }
    }
}

extension SAXAttributeDefaultType: CustomStringConvertible {
    @inlinable public var description: String {
        switch self {
            case .Optional: return "Optional"
            case .Required: return "Required"
            case .Implied:  return "Implied"
            case .Fixed:    return "Fixed"
        }
    }

    @inlinable static func valueFor(description desc: String?) -> SAXAttributeDefaultType {
        if let d = desc {
            switch d {
                case "REQUIRED": return .Required
                case "FIXED":    return .Fixed
                case "IMPLIED":  return .Implied
                default:         break
            }
        }
        return .Optional
    }
}

extension SAXAttributeType: CustomStringConvertible {
    @inlinable public var description: String {
        switch self {
            case .CData:      return "CData"
            case .ID:         return "ID"
            case .IDRef:      return "IDRef"
            case .IDRefs:     return "IDRefs"
            case .Entity:     return "Entity"
            case .Entities:   return "Entities"
            case .NMToken:    return "NMToken"
            case .NMTokens:   return "NMTokens"
            case .Notation:   return "Notation"
            case .Enumerated: return "Enumerated"
        }
    }

    @inlinable static func valueFor(description desc: String) -> SAXAttributeType {
        switch desc {
            case "CDATA":    return .CData
            case "ID":       return .ID
            case "IDREF":    return .IDRef
            case "IDREFS":   return .IDRefs
            case "ENTITY":   return .Entity
            case "ENTITIES": return .Entities
            case "NMTOKEN":  return .NMToken
            case "NMTOKENS": return .NMTokens
            case "NOTATION": return .Notation
            default:         return .Enumerated
        }
    }
}

extension SAXEntityType: CustomStringConvertible {
    @inlinable public var description: String {
        switch self {
            case .General:   return "General"
            case .Parameter: return "Parameter"
        }
    }

    @inlinable static func valueFor(description desc: String) -> SAXEntityType {
        switch desc {
            case "General": return .General
            default:        return .Parameter
        }
    }
}

extension SAXElementAllowedContent: CustomStringConvertible {
    @inlinable public var description: String {
        switch self {
            case .Empty:    return "Empty"
            case .Elements: return "Elements"
            case .Mixed:    return "Mixed"
            case .Any:      return "Any"
            case .PCData:   return "#PCDATA"
        }
    }

    @inlinable static func valueFor(description desc: String?) -> SAXElementAllowedContent {
        if let d = desc {
            switch d {
                case "EMPTY":       return .Empty
                case "ANY":         return .Any
                case "(\(PCDATA))": return .PCData
                default:            return (d.hasPrefix("(\(PCDATA)") ? .Mixed : .Elements)
            }
        }
        return .Empty
    }
}

extension SAXDTDElementContentItem.ItemType: CustomStringConvertible {
    @inlinable public var description: String {
        switch self {
            case .Element: return "Element"
            case .List:    return "List"
            case .PCData:  return "PCData"
        }
    }

    @inlinable static func valueFor(description desc: String) -> SAXDTDElementContentItem.ItemType {
        switch desc {
            case "Element": return .Element
            case "List":    return .List
            default:        return .PCData
        }
    }
}

extension SAXDTDElementContentItem.ItemMultiplicity: CustomStringConvertible {
    @inlinable public var description: String {
        switch self {
            case .Optional: return "Optional"
            case .Once: return "Once"
            case .ZeroOrMore: return "ZeroOrMore"
            case .OneOrMore: return "OneOrMore"
        }
    }

    @inlinable public var symbolChar: String {
        switch self {
            case .Optional:   return "?"
            case .Once:       return ""
            case .ZeroOrMore: return "*"
            case .OneOrMore:  return "+"
        }
    }

    @inlinable static func valueFor(description desc: String) -> SAXDTDElementContentItem.ItemMultiplicity {
        switch desc {
            case "Optional": return .Optional
            case "Once": return .Once
            case "ZeroOrMore": return .ZeroOrMore
            default: return .OneOrMore
        }
    }
}

extension SAXDTDElementContentList.ItemConjunction: CustomStringConvertible {
    @inlinable public var description: String {
        switch self {
            case .And: return "And"
            case .Or:  return "Or"
        }
    }

    @inlinable static func valueFor(description desc: String) -> SAXDTDElementContentList.ItemConjunction {
        switch desc {
            case "And": return .And
            default:    return .Or
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

extension StringProtocol {
    @inlinable func firstIndex(ofAnyOf chars: Character..., from idx: String.Index) -> String.Index? {
        var oIdx = idx
        while oIdx < endIndex {
            if chars.contains(self[oIdx]) { return oIdx }
            formIndex(after: &oIdx)
        }
        return nil
    }
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

    @usableFromInline func getInvalidCharInfo(strings: String...) -> (Character, [Character]) { foo(startIndex, 0, strings) }

    @usableFromInline func getInvalidCharInfo(strings: [String]) -> (Character, [Character]) { foo(startIndex, 0, strings) }

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

    @inlinable func positionOfIndex(_ idx: Index, startingAt pos: (Int, Int), tabSize: Int = 4) -> (Int, Int) {
        positionOfIndex(idx, startingLine: pos.0, startingColumn: pos.1, tabSize: tabSize)
    }

    @usableFromInline func positionOfIndex(_ idx: String.Index, startingLine: Int = 1, startingColumn: Int = 1, tabSize: Int = 4) -> (Int, Int) {
        var pos:  (Int, Int)                = (startingLine, startingColumn)
        let rx:   RegularExpression         = RegularExpression(pattern: "(?:\\R|\\u000b|\\u000c)")!
        let ms:   [RegularExpression.Match] = rx.matches(in: self)
        var lIdx: String.Index              = startIndex
        let eIdx: String.Index              = ((idx < endIndex) ? idx : endIndex)

        for x in (0 ..< ms.count) {
            let m    = ms[x]
            let uIdx = m.range.upperBound

            if idx < uIdx { break }

            switch m.subString {
                case "\u{0b}": pos.0 = tabCalc(pos: pos.0, tabSize: tabSize)
                case "\u{0c}": pos.0 += 24
                default: pos.0 += 1
            }

            pos.1 = 1
            lIdx = uIdx
        }

        while lIdx < eIdx {
            pos.1 = ((self[lIdx] == "\t") ? tabCalc(pos: pos.1, tabSize: tabSize) : (pos.1 + 1))
            lIdx = index(after: lIdx)
        }

        return pos
    }
}
