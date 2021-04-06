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
            case .Internal: return ""
            case .Public:   return "PUBLIC"
            case .System:   return "SYSTEM"
        }
    }

    static func valueFor(description desc: String?) -> SAXExternalType {
        switch desc {
            case "SYSTEM": return .System
            case "PUBLIC": return .Public
            case nil:      return .Public
            default:       return .Internal
        }
    }
}

extension SAXAttributeDefaultType: CustomStringConvertible {
    public var description: String {
        switch self {
            case .Optional: return "Optional"
            case .Required: return "Required"
            case .Implied:  return "Implied"
            case .Fixed:    return "Fixed"
        }
    }

    static func valueFor(description desc: String?) -> SAXAttributeDefaultType {
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
    public var description: String {
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

    static func valueFor(description desc: String) -> SAXAttributeType {
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
    public var description: String {
        switch self {
            case .General:   return "General"
            case .Parameter: return "Parameter"
            case .Unparsed:  return "Unparsed"
        }
    }

    static func valueFor(description desc: String) -> SAXEntityType {
        switch desc {
            case "General":   return .General
            case "Parameter": return .Parameter
            default:          return .Unparsed
        }
    }
}

extension SAXElementAllowedContent: CustomStringConvertible {
    public var description: String {
        switch self {
            case .Empty:    return "Empty"
            case .Elements: return "Elements"
            case .Mixed:    return "Mixed"
            case .Any:      return "Any"
            case .PCData:   return "#PCDATA"
        }
    }

    static func valueFor(description desc: String?) -> SAXElementAllowedContent {
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
    public var description: String {
        switch self {
            case .Element: return "Element"
            case .List:    return "List"
            case .PCData:  return "PCData"
        }
    }

    static func valueFor(description desc: String) -> SAXDTDElementContentItem.ItemType {
        switch desc {
            case "Element": return .Element
            case "List":    return .List
            default:        return .PCData
        }
    }
}

extension SAXDTDElementContentItem.ItemMultiplicity: CustomStringConvertible {
    public var description: String {
        switch self {
            case .Optional: return "Optional"
            case .Once: return "Once"
            case .ZeroOrMore: return "ZeroOrMore"
            case .OneOrMore: return "OneOrMore"
        }
    }

    public var symbolChar: String {
        switch self {
            case .Optional:   return "?"
            case .Once:       return ""
            case .ZeroOrMore: return "*"
            case .OneOrMore:  return "+"
        }
    }

    static func valueFor(description desc: String) -> SAXDTDElementContentItem.ItemMultiplicity {
        switch desc {
            case "Optional":   return .Optional
            case "Once":       return .Once
            case "ZeroOrMore": return .ZeroOrMore
            default:           return .OneOrMore
        }
    }
}

extension SAXDTDElementContentList.ItemConjunction: CustomStringConvertible {
    public var description: String {
        switch self {
            case .And: return "And"
            case .Or:  return "Or"
        }
    }

    static func valueFor(description desc: String) -> SAXDTDElementContentList.ItemConjunction {
        switch desc {
            case "And": return .And
            default:    return .Or
        }
    }
}

extension String {

    /*===========================================================================================================================================================================*/
    /// Assuming this string is a fully qualified name, return a tuple containing the prefix and local name from this string.
    /// 
    /// - Returns: the prefix and local name.  `nil` is returned for the prefix if none is found.
    ///
    func splitPrefix() -> (String?, String) {
        guard let idx = firstIndex(of: ":") else { return (nil, self) }
        guard idx > startIndex else { return (nil, String(self[index(after: startIndex) ..< endIndex])) }
        return (String(self[startIndex ..< idx]), String(self[index(after: idx) ..< endIndex]))
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
    func positionOfIndex(_ idx: Index, position pos: TextPosition, charStream strm: SAXCharInputStream) -> TextPosition {
        positionOfIndex(idx, position: pos, tabSize: strm.tabWidth)
    }

    /*===========================================================================================================================================================================*/
    /// Given a range of characters within this string, return both the substring and it's starting position (line, column).
    /// 
    /// - Parameters:
    ///   - range: the range.
    ///   - pos: the starting position of this string.
    ///   - chStream: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code> this string came from. Used to get the tab width.
    /// - Returns: a tuple containing the substring and (line, column) tuple.
    ///
    func subStringAndPos(range: Range<String.Index>, position pos: TextPosition, charStream chStream: SAXCharInputStream) -> (String, TextPosition) {
        (String(self[range.lowerBound ..< range.upperBound]), positionOfIndex(range.lowerBound, position: pos, charStream: chStream))
    }

}
