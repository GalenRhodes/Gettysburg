/*******************************************************************************************************************************************************************************//*
 *     PROJECT: Gettysburg
 *    FILENAME: SAXDTDElemContTools.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 6/21/21
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

@usableFromInline let CHARS1: [Character] = [ ",", "|", ")" ]
@usableFromInline let CHARS2: [Character] = [ "+", "*", "?" ]

/*===============================================================================================================================================================================*/
/// Parse the DTD Element Content List.
/// 
/// - Parameters:
///   - pos: The current position of the DTD Element Content List in the parent source file.
///   - src: A string containing the DTD Element Content List.
/// - Returns: An instance of SAXDTDElemContList.
/// - Throws: If the DTD Element Content List is malformed.
///
func ParseDTDElementContentList(position pos: TextPosition, list src: String) throws -> SAXDTDElemContList {
    var idx: String.Index = src.startIndex
    var pos: TextPosition = pos
    return try _parseDTDElementContentList(src, index: &idx, position: &pos, isRoot: true)
}

/*===============================================================================================================================================================================*/
/// Parse the DTD Element Content List.
/// 
/// - Parameters:
///   - isRoot: `true` if this is the root list.
///   - src: The string containing the content list.
///   - idx: The current index in the string.
///   - pos: The current position of the index in the parent source file.
/// - Returns: An instance of SAXDTDElemContList.
/// - Throws: If the DTD Element Content List is malformed.
///
func _parseDTDElementContentList(_ src: String, index idx: inout String.Index, position pos: inout TextPosition, isRoot: Bool) throws -> SAXDTDElemContList {
    func foo(_ conjChar: Character, _ m: SAXDTDElemCont.ItemMultiplicity, _ pos: TextPosition) -> Error {
        return SAXError.MalformedElementDecl(position: pos, description: _msg("Invalid character", expected: ((m == .Once) ? CHARS2 + CHARS1 : CHARS1), got: conjChar))
    }

    _ = try _nextChar(src, index: &idx, position: &pos, willThrow: true, allowed: "(")

    let firstItem: SAXDTDElemCont   = try _parseItem(src, index: &idx, position: &pos, pcDataAllowed: isRoot)
    var items:     [SAXDTDElemCont] = [ firstItem ]

    guard let conjChar = try _nextChar(src, index: &idx, position: &pos, allowed: CHARS1) else { throw foo(src[idx], firstItem.multiplicity, pos) }

    if conjChar != ")" {
        repeat { items <+ try _parseItem(src, index: &idx, position: &pos, pcDataAllowed: false) } while try _nextChar(src, index: &idx, position: &pos, allowed: conjChar) != nil
        _ = try _nextChar(src, index: &idx, position: &pos, willThrow: true, allowed: ")")
    }

    let mult = ((idx < src.endIndex) ? SAXDTDElemCont.ItemMultiplicity.valueFor(char: try _nextChar(src, index: &idx, position: &pos, allowed: CHARS2)) : .Once)
    return SAXDTDElemContList(multiplicity: mult, conjunction: ((conjChar == "|") ? .Or : .And), items: items)
}

func _parseItem(_ src: String, index idx: inout String.Index, position pos: inout TextPosition, pcDataAllowed: Bool) throws -> SAXDTDElemCont {
    if src[idx] == "(" { return try _parseDTDElementContentList(src, index: &idx, position: &pos, isRoot: false) }

    let (element, mult, p) = try _getElement(src, index: &idx, position: &pos)

    if element == PCDATA {
        guard pcDataAllowed else { throw SAXError.MalformedElementDecl(position: p, description: "\"\(PCDATA)\" not allowed here.") }
        return SAXDTDElemContPCData()
    }

    return SAXDTDElemContElement(name: element, multiplicity: mult)
}

func _getElement(_ src: String, index idx: inout String.Index, position pos: inout TextPosition) throws -> (String, SAXDTDElemCont.ItemMultiplicity, TextPosition) {
    let p1:   TextPosition                    = pos
    var mlt:  SAXDTDElemCont.ItemMultiplicity = .Once
    var ch:   Character                       = try _nextChar(src, index: &idx, position: &pos)
    var data: [Character]                     = []

    if ch == "#" {
        data <+ ch
        ch = try _nextChar(src, index: &idx, position: &pos)
    }

    guard ch.isXmlNameStartChar else { throw SAXError.MalformedElementDecl(position: pos, description: _msg("Invalid element starting character", got: ch)) }
    data <+ ch

    while let ch = try _nextChar(src, index: &idx, position: &pos, allowed: .XMLNameChar) { data <+ ch }

    let p2 = pos
    if let ch = try _nextChar(src, index: &idx, position: &pos, allowed: CHARS2) { mlt = SAXDTDElemCont.ItemMultiplicity.valueFor(char: ch) }

    let str = String(data)

    if data[0] == "#" {
        guard str == PCDATA else { throw SAXError.MalformedElementDecl(position: p1, description: _msg("Invalid element", expected: PCDATA, got: str)) }
        guard mlt == .Once else { throw SAXError.MalformedElementDecl(position: p2, description: "\"\(PCDATA)\" elements are not allowed to have a multiplicity marker.") }
    }

    return (str, mlt, p1)
}

@inlinable func _nextChar(_ src: String, index idx: inout String.Index, position pos: inout TextPosition) throws -> Character {
    try _nextChar(src, index: &idx, position: &pos, test: { _, _ in true })!
}

@inlinable func _nextChar(_ src: String, index idx: inout String.Index, position pos: inout TextPosition, willThrow: Bool = false, allowed: CharacterSet) throws -> Character? {
    if let ch = try _nextChar(src, index: &idx, position: &pos, test: { c, _ in allowed.contains(char: c) }) { return ch }
    guard !willThrow else { throw SAXError.MalformedElementDecl(position: pos, description: _msg("Invalid character", got: src[idx])) }
    return nil
}

@inlinable func _nextChar(_ src: String, index idx: inout String.Index, position pos: inout TextPosition, willThrow: Bool = false, allowed: Character...) throws -> Character? {
    try __nextChar(src, index: &idx, position: &pos, willThrow: willThrow, allowed: allowed)
}

@inlinable func _nextChar(_ src: String, index idx: inout String.Index, position pos: inout TextPosition, willThrow: Bool = false, allowed: [Character]) throws -> Character? {
    try __nextChar(src, index: &idx, position: &pos, willThrow: willThrow, allowed: allowed)
}

@inlinable func __nextChar(_ src: String, index idx: inout String.Index, position pos: inout TextPosition, willThrow: Bool, allowed: [Character]) throws -> Character? {
    if let ch = try _nextChar(src, index: &idx, position: &pos, test: { c, p in value(c, isOneOf: allowed) }) { return ch }
    guard !willThrow else { throw SAXError.MalformedElementDecl(position: pos, description: _msg("Invalid character", expected: allowed, got: src[idx])) }
    return nil
}

@inlinable func _nextChar(_ src: String, index idx: inout String.Index, position pos: inout TextPosition, test: (Character, TextPosition) throws -> Bool) throws -> Character? {
    guard idx < src.endIndex else { throw SAXError.MalformedElementDecl(position: pos, description: "Unclosed content list.") }
    let ch = src[idx]
    guard try test(ch, pos) else { return nil }
    src.advance(index: &idx, position: &pos)
    return ch
}

@usableFromInline func _msg(_ msg: String, expected c1: Character..., got c2: Character) -> String { __msg(msg, expected: c1.map { String($0) }, got: String(c2)) }

@usableFromInline func _msg(_ msg: String, expected c1: [Character], got c2: Character) -> String { __msg(msg, expected: c1.map { String($0) }, got: String(c2)) }

@usableFromInline func _msg(_ msg: String, expected c1: String..., got c2: String) -> String { __msg(msg, expected: c1, got: c2) }

@usableFromInline func __msg(_ msg: String, expected c1: [String], got c2: String) -> String {
    let cc          = c1.count
    var out: String = "\(msg) -"

    guard cc > 0 else { return "\(out) did not expect \"\(c2)\"." }

    out += "expected \"\(c1[0])\""

    if cc > 1 {
        let x = (c1.endIndex - 1)
        for i in (1 ..< x) { out += ", \"\(c1[i])\"" }
        out += ", or \"\(c1[x])\""
    }

    return "\(out) but got \"\(c2)\" instead."
}
