/*****************************************************************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: DTDAttribute.swift
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

public class DTDAttribute: DOMNode {
    public enum DefaultType { case Required, Implied(value: String?), Fixed(value: String) }

    public enum AttributeType { case CData, ID, IDRef, IDRefs, Entity, Entities, NMToken, NMTokens, Notation, Enumerated(values: [String]) }

    //@f:0
    public override      var nodeType:     NodeType      { .DTDAttribute }
    public               var name:         String        { nodeName }
    public internal(set) var element:      DTDElement?   = nil
    public               let type:         AttributeType
    public               let defaultType:  DefaultType
    public               var defaultValue: String?       { defaultType.defaultValue }
    //@f:1

    init(owningDocument: DOMDocument?, name: String, type: AttributeType = .CData, element: DTDElement? = nil, defaultType: DefaultType = .Required) {
        self.defaultType = defaultType
        self.type = type
        self.element = element
        super.init(owningDocument: owningDocument, qName: name, uri: nil)
        if let e = element { e.attributes <+ self }
    }

    public convenience required init(from decoder: Decoder) throws { try self.init(from: try decoder.container(keyedBy: CodingKeys.self)) }

    override init(from container: KeyedDecodingContainer<CodingKeys>) throws {
        element = try container.decodeIfPresent(DTDElement.self, forKey: .element)
        type = try container.decode(AttributeType.self, forKey: .type)
        defaultType = try container.decode(DefaultType.self, forKey: .defaultType)
        try super.init(from: container)
    }

    override func encode(to container: inout KeyedEncodingContainer<CodingKeys>) throws {
        try super.encode(to: &container)
        try container.encodeIfPresent(element, forKey: .element)
        try container.encode(type, forKey: .type)
        try container.encode(defaultType, forKey: .defaultType)
    }
}

extension DTDAttribute.AttributeType: CustomStringConvertible {
    public var description: String {
        switch self {
            case .CData:                          return "CDATA"
            case .ID:                             return "ID"
            case .IDRef:                          return "IDREF"
            case .IDRefs:                         return "IDREFS"
            case .Entity:                         return "ENTITY"
            case .Entities:                       return "ENTITIES"
            case .NMToken:                        return "NMTOKEN"
            case .NMTokens:                       return "NMTOKENS"
            case .Notation:                       return "NOTATION"
            case .Enumerated(values: let values): return "(\(values.joined(separator: "|")))"
        }
    }

    public var enumValues: [String]? {
        switch self {
            case .Enumerated(values: let values): return values
            default: return nil
        }
    }
}

extension DTDAttribute.DefaultType: CustomStringConvertible {
    public var description: String {
        switch self {
            case .Required:                   return "#REQUIRED"
            case .Implied(value: let value):  return (value?.quoted() ?? "#IMPLIED")
            case .Fixed(value: let value):    return "#FIXED \(value.quoted())"
        }
    }

    public var defaultValue: String? {
        switch self {
            case .Required:                   return nil
            case .Implied(value: let value):  return value
            case .Fixed(value: let value):    return value
        }
    }
}

extension DTDAttribute.AttributeType: Codable {
    private enum CodingKeys: String, CodingKey { case name, values }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let name      = try container.decode(String.self, forKey: .name)
        switch name {
            case "CDATA":    self = .CData
            case "ID":       self = .ID
            case "IDREF":    self = .IDRef
            case "IDREFS":   self = .IDRefs
            case "ENTITY":   self = .Entity
            case "ENTITIES": self = .Entities
            case "NMTOKEN":  self = .NMToken
            case "NMTOKENS": self = .NMTokens
            case "NOTATION": self = .Notation
            default:         self = .Enumerated(values: try container.decode(Array<String>.self, forKey: .values))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
            case .CData:    try container.encode("CDATA", forKey: .name)
            case .ID:       try container.encode("ID", forKey: .name)
            case .IDRef:    try container.encode("IDREF", forKey: .name)
            case .IDRefs:   try container.encode("IDREFS", forKey: .name)
            case .Entity:   try container.encode("ENTITY", forKey: .name)
            case .Entities: try container.encode("ENTITIES", forKey: .name)
            case .NMToken:  try container.encode("NMTOKEN", forKey: .name)
            case .NMTokens: try container.encode("NMTOKENS", forKey: .name)
            case .Notation: try container.encode("NOTATION", forKey: .name)
            case .Enumerated(values: let values):
                try container.encode("ENUMERATED", forKey: .name)
                try container.encode(values, forKey: .values)
        }
    }
}

extension DTDAttribute.DefaultType: Codable {
    private enum CodingKeys: String, CodingKey { case name, value }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let name      = try container.decode(String.self, forKey: .name)
        switch name {
            case "#IMPLIED": self = .Implied(value: try container.decodeIfPresent(String.self, forKey: .value))
            case "#FIXED":   self = .Fixed(value: try container.decode(String.self, forKey: .value))
            default:        self = .Required
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
            case .Required:
                try container.encode("#REQUIRED", forKey: .name)
            case .Implied(value: let value):
                try container.encode("#IMPLIED", forKey: .name)
                try container.encodeIfPresent(value, forKey: .value)
            case .Fixed(value: let value):
                try container.encode("#FIXED", forKey: .name)
                try container.encode(value, forKey: .value)
        }
    }
}
