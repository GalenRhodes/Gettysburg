/*******************************************************************************************************************************************************************************//*
 *     PROJECT: Gettysburg
 *    FILENAME: SAXDTDElementContentItem.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 6/1/21
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

func ParseDTDElementContentList(position pos: TextPosition, list src: String) throws -> SAXDTDElemContList {
    var idx: String.Index = src.startIndex
    var pos: TextPosition = pos
    return try _parseDTDElementContentList(isRoot: true, list: src, startIndex: &idx, position: &pos)
}

public class SAXDTDElemCont: Hashable {
    public enum ItemMultiplicity { case Optional, Once, ZeroOrMore, OneOrMore }

    public enum ItemType { case Element, List, PCData }

    public let type:         ItemType
    public let multiplicity: ItemMultiplicity

    public init(type: ItemType, multiplicity: ItemMultiplicity) {
        self.type = type
        self.multiplicity = multiplicity
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(type)
        hasher.combine(multiplicity)
    }

    @inlinable public static func == (lhs: SAXDTDElemCont, rhs: SAXDTDElemCont) -> Bool { equals(lhs: lhs, rhs: rhs) }

    @inlinable static func equals(lhs: SAXDTDElemCont, rhs: SAXDTDElemCont) -> Bool {
        ((Swift.type(of: lhs) == Swift.type(of: rhs)) && (lhs.type == rhs.type) && (lhs.multiplicity == rhs.multiplicity))
    }
}

public class SAXDTDElemContList: SAXDTDElemCont {
    public enum ItemConjunction { case And, Or }

    public let conjunction: ItemConjunction
    public var items:       [SAXDTDElemCont] = []

    public init(multiplicity: ItemMultiplicity, conjunction: ItemConjunction, items: [SAXDTDElemCont] = []) {
        self.conjunction = conjunction
        super.init(type: .List, multiplicity: multiplicity)
        self.items.append(contentsOf: items)
    }

    @inlinable public static func <+ (lhs: SAXDTDElemContList, rhs: SAXDTDElemCont) { lhs.items <+ rhs }

    @inlinable public static func <+ (lhs: SAXDTDElemContList, rhs: [SAXDTDElemCont]) { lhs.items.append(contentsOf: rhs) }

    @inlinable public static func == (lhs: SAXDTDElemContList, rhs: SAXDTDElemContList) -> Bool {
        (equals(lhs: lhs, rhs: rhs) && (lhs.conjunction == rhs.conjunction) && (lhs.items == rhs.items))
    }
}

public class SAXDTDElemContElement: SAXDTDElemCont {
    public let name: String

    public init(name: String, multiplicity: ItemMultiplicity) {
        self.name = name
        super.init(type: .Element, multiplicity: multiplicity)
    }

    public override func hash(into hasher: inout Hasher) {
        super.hash(into: &hasher)
        hasher.combine(name)
    }

    public static func == (lhs: SAXDTDElemContElement, rhs: SAXDTDElemContElement) -> Bool { (equals(lhs: lhs, rhs: rhs) && (lhs.name == rhs.name)) }
}

public class SAXDTDElemContPCData: SAXDTDElemCont {
    public convenience init() { self.init(type: .PCData, multiplicity: .Optional) }
}

fileprivate func _parseDTDElementContentList(isRoot: Bool, list src: String, startIndex idx: inout String.Index, position pos: inout TextPosition) throws -> SAXDTDElemContList {
    // The first character needs to be "("!
    guard src[idx] == "(" else { throw SAXError.MalformedElementDecl(position: pos, description: _msg(msg: "Not an allowed content list or sublist", expected: "(", got: src[idx])) }

    // And it can't be the last character.
    try nextPos(list: src, startIndex: &idx, position: &pos)

    var arr: [SAXDTDElemCont] = []

    // Is this an empty list?
    let ch1                   = src[idx]
    guard ch1 != ")" else {
        return SAXDTDElemContList(multiplicity: try _getMultiplicity(list: src, startIndex: &idx, position: &pos), conjunction: .And, items: arr)
    }

    // Parse the first item in the list.
    arr <+ try _parseItem(pcDataAllowed: isRoot, list: src, startIndex: &idx, position: &pos)

    // Get the next character which should be ")", ",", or "|".
    let cChar: Character = src[idx]

    // Are we done with our list?
    if cChar != ")" {
        // If cChar wasn't a list closer, ")", then it needs to be either "," or "|".
        guard value(cChar, isOneOf: ",", "|") else { throw SAXError.MalformedElementDecl(position: pos, description: _msg(msg: "Not a valid combining character", expected: ",", "|", got: cChar)) }

        // Keep parsing items as long as they are all separated by the same character.
        repeat {
            try nextPos(list: src, startIndex: &idx, position: &pos)
            arr <+ try _parseItem(pcDataAllowed: false, list: src, startIndex: &idx, position: &pos)
        } while src[idx] == cChar

        // If the last character wasn't the same as the combining character then it better be the list closing character.
        guard src[idx] == ")" else { throw SAXError.MalformedElementDecl(position: pos, description: _msg(msg: "Unexpected character", expected: cChar, ")", got: src[idx])) }
    }

    // Return our list.
    return SAXDTDElemContList(multiplicity: try _getMultiplicity(list: src, startIndex: &idx, position: &pos), conjunction: ((cChar == ",") ? .And : .Or), items: arr)
}

fileprivate func _parseItem(pcDataAllowed: Bool, list src: String, startIndex idx: inout String.Index, position pos: inout TextPosition) throws -> SAXDTDElemCont {
    let ch = src[idx]
    if ch == "(" {
        return try _parseDTDElementContentList(isRoot: false, list: src, startIndex: &idx, position: &pos)
    }
    else {
        let (item, m, p) = try _getElement(list: src, position: &pos, startIndex: &idx)

        if item.first == "#" {
            guard item == PCDATA else { throw SAXError.MalformedElementDecl(position: p, description: "Unknown metaitem: \"\(item)\"") }
            guard pcDataAllowed else { throw SAXError.MalformedElementDecl(position: p, description: "\(PCDATA) not allowed here.") }
            guard m == .Once else { throw SAXError.MalformedElementDecl(position: p, description: "\(PCDATA) cannot have a multiplicity character: \(m)") }
            return SAXDTDElemContPCData()
        }
        else {
            guard item.isValidXMLName else { throw SAXError.MalformedElementDecl(position: p, description: "Not a valid XML name: \"\(item)\"") }
            return SAXDTDElemContElement(name: item, multiplicity: m)
        }
    }
}

fileprivate func _getElement(list src: String, position pos: inout TextPosition, startIndex idx: inout String.Index) throws -> (String, SAXDTDElemCont.ItemMultiplicity, TextPosition) {
    let p: TextPosition = pos
    var b: [Character]  = []

    while !value(src[idx], isOneOf: "(", ")", ",", "|", "+", "?", "*") {
        b <+ src[idx]
        try nextPos(list: src, startIndex: &idx, position: &pos)
    }

    let m = SAXDTDElemCont.ItemMultiplicity.valueFor(char: src[idx])
    if m != .Once { try nextPos(list: src, startIndex: &idx, position: &pos) }
    return (String(b), m, p)
}

fileprivate func nextPos(list src: String, startIndex idx: inout String.Index, position pos: inout TextPosition) throws {
    var idx = idx
    var pos = pos
    guard src.advance(index: &idx, position: &pos) else { throw SAXError.MalformedElementDecl(position: pos, description: "Unclosed content list.") }
}

fileprivate func _getMultiplicity(list src: String, startIndex idx: inout String.Index, position pos: inout TextPosition) throws -> SAXDTDElemCont.ItemMultiplicity {
    // Advance to the next character and see if we have a multiplicity character.
    try nextPos(list: src, startIndex: &idx, position: &pos)
    let m = SAXDTDElemCont.ItemMultiplicity.valueFor(char: src[idx])
    if m != .Once { try nextPos(list: src, startIndex: &idx, position: &pos) }
    return m
}

fileprivate func _msg(msg: String, expected c1: String..., got c2: String) -> String { __msg(msg: msg, expected: c1, got: c2) }

fileprivate func _msg(msg: String, expected c1: Character..., got c2: Character) -> String { __msg(msg: msg, expected: c1.map { String($0) }, got: String(c2)) }

fileprivate func __msg(msg: String, expected c1: [String], got c2: String) -> String {
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
