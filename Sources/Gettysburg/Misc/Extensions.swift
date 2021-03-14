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
            case .Internal: return ""
            case .Public:   return "PUBLIC"
            case .System:   return "SYSTEM"
        }
    }

    @inlinable static func valueFor(description desc: String?) -> SAXExternalType {
        switch desc {
            case "SYSTEM": return .System
            case "PUBLIC": return .Public
            case nil:      return .Public
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
            case .Unparsed:  return "Unparsed"
        }
    }

    @inlinable static func valueFor(description desc: String) -> SAXEntityType {
        switch desc {
            case "General":   return .General
            case "Parameter": return .Parameter
            default:          return .Unparsed
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
            case "Optional":   return .Optional
            case "Once":       return .Once
            case "ZeroOrMore": return .ZeroOrMore
            default:           return .OneOrMore
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

extension String {

    @inlinable func splitPrefix() -> (String?, String) {
        guard let m = RegularExpression(pattern: "\\A([^:]*)\\:(.+)")?.firstMatch(in: self) else { return (nil, self.trimmed) }
        guard let p = m[1].subString?.trimmed, let n = m[2].subString?.trimmed else { return (nil, self.trimmed) }
        if p.isEmpty { return (nil, n) }
        return (p, n)
    }

    /*===========================================================================================================================================================================*/
    /// Get the position (line, column) of the index in the given string relative to the given starting position (line, column).
    /// 
    /// - Parameters:
    ///   - idx: the index.
    ///   - position: the starting position.
    ///   - strm: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code> the string was read from to get the tab size.
    /// - Returns: the position (line, column) of the index within the string.
    ///
    @inlinable func positionOfIndex(_ idx: Index, position pos: (Int, Int), charStream strm: SAXCharInputStream) -> (Int, Int) {
        positionOfIndex(idx, position: pos, tabSize: strm.tabWidth)
    }

}
