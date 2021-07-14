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
