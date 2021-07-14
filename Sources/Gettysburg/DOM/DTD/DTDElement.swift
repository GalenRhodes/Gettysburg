/*****************************************************************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: DTDElement.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: July 13, 2021
 *
  * Permission to use, copy, modify, and distribute this software for any purpose with or without fee is hereby granted, provided
 * that the above copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR
 * CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT,
 * NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *//*****************************************************************************************************************************/

import Foundation
import CoreFoundation
import Rubicon

public class DTDElement: DOMNode {

    public enum AllowedContent { case Empty, `Any`, Elements(content: ContentList), Mixed(content: ContentList) }

    //@f:0
    public override      var nodeType:       NodeType       { .DTDElement }
    public               var name:           String         { nodeName    }
    public               let allowedContent: AllowedContent
    public               var contentList:    ContentList?   { allowedContent.contentList }
    public internal(set) var attributes:     [DTDAttribute]
    //@f:1

    convenience init<S: StringProtocol>(owningDocument: DOMDocument, name: String, content str: S, docPosition pos: DocPosition, attributes: [DTDAttribute] = []) throws {
        try self.init(owningDocument: owningDocument, name: name, allowedContent: try .getAllowedContent(content: str, docPosition: pos), attributes: attributes)
    }

    convenience init<S: StringProtocol>(owningDocument: DOMDocument, name: String, content str: S, url: URL? = nil, line: Int32 = 1, column: Int32 = 1, attributes: [DTDAttribute] = []) throws {
        let pos = DocPosition(url: url, line: line, column: column)
        try self.init(owningDocument: owningDocument, name: name, allowedContent: try .getAllowedContent(content: str, docPosition: pos), attributes: attributes)
    }

    init(owningDocument: DOMDocument, name: String, allowedContent: AllowedContent = .Empty, attributes: [DTDAttribute] = []) throws {
        self.allowedContent = allowedContent
        self.attributes = attributes
        super.init(owningDocument: owningDocument, qName: name, uri: nil)
        self.attributes.forEach { $0.element = self }
    }

    public class Content {
        public enum Multiplicity: String { case Once = "", OneOrMore = "+", Optional = "?", ZeroOrMore = "*" }

        public enum ContentType { case Element, CData, List }

        public let type:         ContentType
        public let multiplicity: Multiplicity

        init(type: ContentType, multiplicity: Multiplicity) {
            self.type = type
            self.multiplicity = multiplicity
        }
    }

    public class ContentList: Content {
        public enum Conjunction: Character { case And = ",", Or = "|" }

        public private(set) var content: [Content]
        public let conjunction: Conjunction

        init(content: [Content], conjunction: Conjunction, multiplicity: Multiplicity) {
            self.content = content
            self.conjunction = conjunction
            super.init(type: .List, multiplicity: multiplicity)
        }
    }

    public class ElementContent: Content {
        public let name: String

        init(name: String, multiplicity: Multiplicity) {
            self.name = name
            super.init(type: .Element, multiplicity: multiplicity)
        }
    }

    public class CharacterContent: Content {
        init() { super.init(type: .CData, multiplicity: .Once) }
    }
}

extension DTDElement.AllowedContent {
    @inlinable static func getAllowedContent<S: StringProtocol>(content str: S, url: URL? = nil, line: Int32 = 1, column: Int32 = 1) throws -> DTDElement.AllowedContent {
        try getAllowedContent(content: str, docPosition: DocPosition(url: url, line: line, column: column))
    }

    @usableFromInline static func getAllowedContent<S: StringProtocol>(content str: S, docPosition pos: DocPosition) throws -> DTDElement.AllowedContent {
        switch str {
            case "EMPTY":
                return .Empty
            case "ANY":
                return .Any
            case "(#PCDATA)":
                return .Mixed(content: DTDElement.ContentList(content: [ DTDElement.CharacterContent() ], conjunction: .And, multiplicity: .Once))
            default:
                var idx  = str.startIndex
                let list = try parse(content: str, index: &idx, isRoot: true, docPosition: pos)
                return (str.hasPrefix("(#PCDATA") ? .Mixed(content: list) : .Elements(content: list))
        }
    }

    private static func parse<S: StringProtocol>(content str: S, url: URL? = nil, line: Int32 = 1, column: Int32 = 1) throws -> DTDElement.ContentList {
        try parse(content: str, docPosition: DocPosition(url: url, line: line, column: column))
    }

    private static func parse<S: StringProtocol>(content str: S, docPosition pos: DocPosition) throws -> DTDElement.ContentList {
        var idx = str.startIndex
        return try parse(content: str, index: &idx, isRoot: true, docPosition: pos)
    }

    private static func parse<S: StringProtocol>(content str: S, index idx: inout String.Index, isRoot: Bool, docPosition pos: DocPosition) throws -> DTDElement.ContentList {
        guard idx < str.endIndex else { throw SAXError.getUnexpectedEndOfInput() }
        guard str[idx] == "(" else { throw SAXError.IllegalCharacter(position: DocPosition(startPosition: pos, string: str, upTo: idx), description: ExpMsg(expected: "(", got: str[idx])) }
        str.formIndex(after: &idx)

        var list: [DTDElement.Content]                = []
        var conj: DTDElement.ContentList.Conjunction? = nil

        while idx < str.endIndex {
            let ch = try str.skipWhitespace(&idx)

            switch ch {
                case ")":
                    guard list.isNotEmpty else { throw SAXError.MalformedElementDecl(position: errpos(pos, str, idx), description: "Empty content list.") }
                    str.formIndex(after: &idx)
                    let mult = getMultiplicity(content: str, index: &idx)
                    return DTDElement.ContentList(content: list, conjunction: conj ?? .And, multiplicity: mult)
                case "(":
                    list <+ try parse(content: str, index: &idx, isRoot: false, docPosition: pos)
                    try testConjuction(content: str, index: &idx, docPosition: pos, char: try str.skipWhitespace(&idx), conjunction: &conj)
                case "#":
                    let x = idx
                    try nextIdx(str, &idx)
                    let (name, mult) = try getElementName(content: str, index: &idx)
                    guard name == "PCDATA" else { throw SAXError.MalformedElementDecl(position: errpos(pos, str, x), description: "Unknown element content: \(str[x ..< idx])") }
                    guard mult == .Once else { throw SAXError.MalformedElementDecl(position: errpos(pos, str, str.index(before: idx)), description: "#PCDATA cannot have a multiplicity index.") }
                    guard isRoot && list.isEmpty else { throw SAXError.MalformedElementDecl(position: errpos(pos, str, x), description: "#PCDATA not allowed here.") }
                    list <+ DTDElement.CharacterContent()
                    try testConjuction(content: str, index: &idx, docPosition: pos, char: try str.skipWhitespace(&idx), conjunction: &conj)
                default:
                    list <+ try getElementContent(content: str, index: &idx, docPosition: pos, conjunction: &conj)
            }
        }

        throw SAXError.getUnexpectedEndOfInput()
    }

    private static func getElementContent<S: StringProtocol>(content str: S, index idx: inout String.Index, docPosition pos: DocPosition, conjunction conj: inout DTDElement.ContentList.Conjunction?) throws -> DTDElement.ElementContent {
        guard CharacterSet.XMLNameStartChar.contains(char: str[idx]) else { throw SAXError.IllegalCharacter(position: errpos(pos, str, idx), description: ExpMsg(got: str[idx])) }
        let (name, mult) = try getElementName(content: str, index: &idx)
        try testConjuction(content: str, index: &idx, docPosition: pos, char: try str.skipWhitespace(&idx), conjunction: &conj)
        return DTDElement.ElementContent(name: name, multiplicity: mult)
    }

    private static func testConjuction<S: StringProtocol>(content str: S, index idx: inout String.Index, docPosition pos: DocPosition, char ch: Character, conjunction conj: inout DTDElement.ContentList.Conjunction?) throws {
        guard ch != ")" else { return }
        if let conj = conj {
            guard conj == ch else { throw SAXError.IllegalCharacter(position: errpos(pos, str, idx), description: ExpMsg(expected: conj.rawValue, got: ch)) }
        }
        else {
            guard value(ch, isOneOf: "|", ",") else { throw SAXError.IllegalCharacter(position: errpos(pos, str, idx), description: ExpMsg(expected: "|", ",", got: ch)) }
            conj = DTDElement.ContentList.Conjunction.init(rawValue: ch)
        }
        str.formIndex(after: &idx)
    }

    private static func getElementName<S: StringProtocol>(content str: S, index idx: inout String.Index) throws -> (String, DTDElement.Content.Multiplicity) {
        var out: String = ""
        while str[idx].isXmlNameChar {
            out.append(str[idx])
            str.formIndex(after: &idx)
            guard idx < str.endIndex else { throw SAXError.getUnexpectedEndOfInput() }
        }
        return (out, getMultiplicity(content: str, index: &idx))
    }

    private static func getMultiplicity<S: StringProtocol>(content str: S, index idx: inout String.Index) -> DTDElement.Content.Multiplicity {
        guard idx < str.endIndex else { return .Once }

        switch String(str[idx]) {
            case DTDElement.Content.Multiplicity.OneOrMore.rawValue:
                str.formIndex(after: &idx)
                return .OneOrMore
            case DTDElement.Content.Multiplicity.ZeroOrMore.rawValue:
                str.formIndex(after: &idx)
                return .ZeroOrMore
            case DTDElement.Content.Multiplicity.Optional.rawValue:
                str.formIndex(after: &idx)
                return .Optional
            default:
                return .Once
        }
    }

    public var contentList: DTDElement.ContentList? {
        switch self {
            case .Elements(content: let c): return c
            case .Mixed(content: let c): return c
            default: return nil
        }
    }

    @inlinable static func errpos<S: StringProtocol>(_ p: DocPosition, _ s: S, _ i: String.Index) -> DocPosition { DocPosition(startPosition: p, string: s, upTo: i) }

    @inlinable static func nextIdx<S: StringProtocol>(_ str: S, _ idx: inout String.Index) throws {
        str.formIndex(after: &idx)
        guard idx < str.endIndex else { throw SAXError.getUnexpectedEndOfInput() }
    }
}

extension DTDElement.ContentList.Conjunction {
    @inlinable public static func == (lhs: Self, rhs: Character) -> Bool { (lhs.rawValue == rhs) }

    @inlinable public static func == (lhs: Character, rhs: Self) -> Bool { (lhs == rhs.rawValue) }

    @inlinable public static func != (lhs: Self, rhs: Character) -> Bool { (lhs.rawValue != rhs) }

    @inlinable public static func != (lhs: Character, rhs: Self) -> Bool { (lhs != rhs.rawValue) }
}

extension DTDElement.Content: CustomStringConvertible {
    public var description: String {
        switch type {
            case .Element:
                let e = self as! DTDElement.ElementContent
                return "\(e.name)\(e.multiplicity.rawValue)"
            case .CData:
                return "#PCDATA"
            case .List:
                let l = self as! DTDElement.ContentList
                return "(\(l.content.map({ $0.description }).joined(separator: String(l.conjunction.rawValue))))\(l.multiplicity.rawValue)"
        }
    }
}
