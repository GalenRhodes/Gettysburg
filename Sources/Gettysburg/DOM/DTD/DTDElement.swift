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

    public convenience required init(from decoder: Decoder) throws { try self.init(from: try decoder.container(keyedBy: CodingKeys.self)) }

    override init(from container: KeyedDecodingContainer<CodingKeys>) throws {
        allowedContent = try container.decode(AllowedContent.self, forKey: .allowedContent)
        attributes = try container.decode(Array<DTDAttribute>.self, forKey: .attributes)
        try super.init(from: container)
    }

    override func encode(to container: inout KeyedEncodingContainer<CodingKeys>) throws {
        try super.encode(to: &container)
        try container.encode(allowedContent, forKey: .allowedContent)
        try container.encode(attributes, forKey: .attributes)
    }

    public class Content: Codable {
        public enum Multiplicity: String, Codable { case Once = "", OneOrMore = "+", Optional = "?", ZeroOrMore = "*" }

        public enum ContentType: String, Codable { case Element, CData, List }

        public let type:         ContentType
        public let multiplicity: Multiplicity

        init(type: ContentType, multiplicity: Multiplicity) {
            self.type = type
            self.multiplicity = multiplicity
        }

        enum CodingKeys: String, CodingKey { case type, multiplicity, content, conjunction, name }

        public required convenience init(from decoder: Decoder) throws { try self.init(from: try decoder.container(keyedBy: CodingKeys.self)) }

        init(from container: KeyedDecodingContainer<CodingKeys>) throws {
            type = try container.decode(ContentType.self, forKey: .type)
            multiplicity = try container.decode(Multiplicity.self, forKey: .multiplicity)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try encode(to: &container)
        }

        func encode(to container: inout KeyedEncodingContainer<CodingKeys>) throws {
            try container.encode(type, forKey: .type)
            try container.encode(multiplicity, forKey: .multiplicity)
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

        public required convenience init(from decoder: Decoder) throws { try self.init(from: try decoder.container(keyedBy: CodingKeys.self)) }

        override init(from container: KeyedDecodingContainer<CodingKeys>) throws {
            conjunction = try container.decode(Conjunction.self, forKey: .conjunction)
            content = []
            try super.init(from: container)
            var list: UnkeyedDecodingContainer = try container.nestedUnkeyedContainer(forKey: .content)
            while !list.isAtEnd {
                let subContainer = try list.nestedContainer(keyedBy: CodingKeys.self)
                let subType      = try subContainer.decode(ContentType.self, forKey: .type)

                switch subType {
                    case .Element: content <+ try ElementContent(from: subContainer)
                    case .List:    content <+ try ContentList(from: subContainer)
                    case .CData:   content <+ try CharacterContent(from: subContainer)
                }
            }
        }

        override func encode(to container: inout KeyedEncodingContainer<Content.CodingKeys>) throws {
            try super.encode(to: &container)
            try container.encode(conjunction, forKey: .conjunction)
            var list = container.nestedUnkeyedContainer(forKey: .content)
            for c in content {
                var subContainer = list.nestedContainer(keyedBy: CodingKeys.self)
                try c.encode(to: &subContainer)
            }
        }
    }

    public class ElementContent: Content {
        public let name: String

        init(name: String, multiplicity: Multiplicity) {
            self.name = name
            super.init(type: .Element, multiplicity: multiplicity)
        }

        public required convenience init(from decoder: Decoder) throws { try self.init(from: try decoder.container(keyedBy: CodingKeys.self)) }

        override init(from container: KeyedDecodingContainer<CodingKeys>) throws {
            name = try container.decode(String.self, forKey: .name)
            try super.init(from: container)
        }

        override func encode(to container: inout KeyedEncodingContainer<CodingKeys>) throws {
            try super.encode(to: &container)
            try container.encode(name, forKey: .name)
        }
    }

    public class CharacterContent: Content {
        init() { super.init(type: .CData, multiplicity: .Once) }

        public required convenience init(from decoder: Decoder) throws { try self.init(from: try decoder.container(keyedBy: CodingKeys.self)) }

        override init(from container: KeyedDecodingContainer<CodingKeys>) throws { try super.init(from: container) }

        override func encode(to container: inout KeyedEncodingContainer<CodingKeys>) throws { try super.encode(to: &container) }
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

extension DTDElement.AllowedContent: Codable {
    private enum CodingKeys: String, CodingKey { case name, content }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let name      = try container.decode(String.self, forKey: .name)
        switch name {
            case "Any":      self = .Any
            case "Empty":    self = .Empty
            case "Elements": self = .Elements(content: try container.decode(DTDElement.ContentList.self, forKey: .content))
            default:         self = .Mixed(content: try container.decode(DTDElement.ContentList.self, forKey: .content))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
            case .Any:
                try container.encode("Any", forKey: .name)
            case .Empty:
                try container.encode("Empty", forKey: .name)
            case .Elements(content: let list):
                try container.encode("Elements", forKey: .name)
                var mcc = container.nestedContainer(keyedBy: DTDElement.Content.CodingKeys.self, forKey: .content)
                try list.encode(to: &mcc)
            case .Mixed(content: let list):
                try container.encode("Mixed", forKey: .name)
                var mcc = container.nestedContainer(keyedBy: DTDElement.Content.CodingKeys.self, forKey: .content)
                try list.encode(to: &mcc)
        }
    }
}

extension DTDElement.ContentList.Conjunction: Codable {
    private enum CodingKeys: String, CodingKey { case symbol }

    public init(from decoder: Decoder) throws {
        let container  = try decoder.container(keyedBy: CodingKeys.self)
        let ch: String = try container.decode(String.self, forKey: .symbol)
        switch ch {
            case ",": self = .And
            default:  self = .Or
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(String(self.rawValue), forKey: .symbol)
    }
}
