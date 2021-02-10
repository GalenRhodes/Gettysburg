/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: Enums.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 2/8/21
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
#if os(Windows)
    import WinSDK
#endif

extension SAXParser {
    /*===========================================================================================================================================================================*/
    /// Byte-order.
    ///
    public enum Endian {
        /*=======================================================================================================================================================================*/
        /// No byte-order or none detected.
        ///
        case None
        /*=======================================================================================================================================================================*/
        /// Little Endian byte-order.
        ///
        case LittleEndian
        /*=======================================================================================================================================================================*/
        /// Big Endian byte-order.
        ///
        case BigEndian
    }

    /*===========================================================================================================================================================================*/
    /// DTD Entity Types
    ///
    public enum DTDEntityType {
        /*=======================================================================================================================================================================*/
        /// General entity.
        ///
        case General
        /*=======================================================================================================================================================================*/
        /// Parameter entity.
        ///
        case Parameter
    }

    /*===========================================================================================================================================================================*/
    /// The type of external resource.
    ///
    public enum DTDExternalType {
        /*=======================================================================================================================================================================*/
        /// Private resource.
        ///
        case System
        /*=======================================================================================================================================================================*/
        /// Public resource.
        ///
        case Public
    }

    /*===========================================================================================================================================================================*/
    /// The DTD attribute value types.
    ///
    public enum DTDAttrType {
        /*=======================================================================================================================================================================*/
        /// <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> data.
        ///
        case CDATA
        /*=======================================================================================================================================================================*/
        /// ID attribute.
        ///
        case ID
        /*=======================================================================================================================================================================*/
        /// ID reference.
        ///
        case IDREF
        /*=======================================================================================================================================================================*/
        /// ID references.
        ///
        case IDREFS
        /*=======================================================================================================================================================================*/
        /// Entity
        ///
        case ENTITY
        /*=======================================================================================================================================================================*/
        /// Entities
        ///
        case ENTITIES
        /*=======================================================================================================================================================================*/
        /// NMToken
        ///
        case NMTOKEN
        /*=======================================================================================================================================================================*/
        /// NMTokens
        ///
        case NMTOKENS
        /*=======================================================================================================================================================================*/
        /// Notation
        ///
        case NOTATION
        /*=======================================================================================================================================================================*/
        /// Enumerated
        ///
        case ENUMERATED
    }

    /*===========================================================================================================================================================================*/
    /// DTD Attribute Value Requirement Types
    ///
    public enum DTDAttrRequirementType {
        /*=======================================================================================================================================================================*/
        /// The attribute is required.
        ///
        case Required
        /*=======================================================================================================================================================================*/
        /// The attribute is optional.
        ///
        case Optional
        /*=======================================================================================================================================================================*/
        /// The attribute has a fixed value.
        ///
        case Fixed
    }
}

extension SAXParser.DTDEntityType: CustomStringConvertible {
    /*===========================================================================================================================================================================*/
    /// A description of the entity type.
    ///
    public var description: String {
        switch self {
            case .General:   return "General"
            case .Parameter: return "Parameter"
        }
    }
}

extension SAXParser.DTDAttrType: CustomStringConvertible {
    /*===========================================================================================================================================================================*/
    /// A description of the attribute value type.
    ///
    public var description: String {
        switch self {
            case .CDATA:      return "CDATA"
            case .ID:         return "ID"
            case .IDREF:      return "IDREF"
            case .IDREFS:     return "IDREFS"
            case .ENTITY:     return "ENTITY"
            case .ENTITIES:   return "ENTITIES"
            case .NMTOKEN:    return "NMTOKEN"
            case .NMTOKENS:   return "NMTOKENS"
            case .NOTATION:   return "NOTATION"
            case .ENUMERATED: return "ENUMERATED"
        }
    }
}

extension SAXParser.DTDAttrRequirementType: CustomStringConvertible {
    /*===========================================================================================================================================================================*/
    /// A description of the attribute requirement type.
    ///
    public var description: String {
        switch self {
            case .Required: return "Required"
            case .Optional: return "Optional"
            case .Fixed:    return "Fixed"
        }
    }
}

extension SAXParser.Endian: CustomStringConvertible {
    /*===========================================================================================================================================================================*/
    /// A description of the byte-order.
    ///
    public var description: String {
        switch self {
            case .None:         return "N/A"
            case .LittleEndian: return "Little Endian"
            case .BigEndian:    return "Big Endian"
        }
    }

    /*===========================================================================================================================================================================*/
    /// Get the byte-order for it's description. Big endian values are `BE`, `BIG`, `BIGENDIAN`, `BIG ENDIAN`. Little endian values are `LE`, `LITTLE`, `LITTLEENDIAN`, `LITTLE
    /// ENDIAN`. Anything else returns `SAXParser.Endian.None`.
    ///
    @inlinable static func getEndianBOM(_ str: String?) -> Self {
        guard let str = str else { return .None }
        switch str.uppercased() {
            case "BE", "BIG", "BIGENDIAN", "BIG ENDIAN": return .BigEndian
            case "LE", "LITTLE", "LITTLEENDIAN", "LITTLE ENDIAN": return .LittleEndian
            default: return .None
        }
    }

    /*===========================================================================================================================================================================*/
    /// Get the endian by the encoding name's suffix. `LE` returns little endian, `BE` returns big endian, and anything else returns `SAXParser.Endian.None`.
    /// 
    /// - Parameter str: the suffix.
    /// - Returns: the endian.
    ///
    @inlinable static func getEndianBySuffix(_ str: String?) -> Self {
        guard let str = str else { return .None }
        let s = str.uppercased()
        return (s.hasSuffix("BE") ? .BigEndian : (s.hasSuffix("LE") ? .LittleEndian : .None))
    }
}

extension SAXParser.DTDExternalType: CustomStringConvertible {
    /*===========================================================================================================================================================================*/
    /// A description of the external type.
    ///
    public var description: String {
        switch self {
            case .System: return "System"
            case .Public: return "Public"
        }
    }
}
