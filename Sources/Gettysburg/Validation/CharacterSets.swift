/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: CharacterSets.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 2/3/21
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

//@f:0
/*===============================================================================================================================================================================*/
/// A regular expression pattern to validate a starting character for an XML name.
///
let rxNameStartCharSet:  String          = "a-zA-Z_:\\u00c0-\\u00d6\\u00d8-\\u00f6\\u00f8-\\u02ff\\u0370-\\u037d\\u037f-\\u1fff\\u200c-\\u200d\\u2070-\\u218f\\u2c00-\\u2fef\\u3001-\\ud7ff\\uf900-\\ufdcf\\ufdf0-\\ufffd\\U00010000-\\U000effff"
/*===============================================================================================================================================================================*/
/// A regular expression patther to validate a character for an XML name.
///
let rxNameCharSet:       String          = "\(rxNameStartCharSet)0123456789\\u002e\\u00b7\\u0300-\\u036f\\u203f-\\u2040\\u002d"

let rxNamePattern:       String          = "(?:[\(rxNameStartCharSet)][\(rxNameCharSet)]*)"
let rxNMTokenPattern:    String          = "(?:[\(rxNameCharSet)]+)"
let rxWhitespacePattern: String          = "(?:[\\u0000-\\u0020\\u007f]*)"

/*===============================================================================================================================================================================*/
/// Array of unicode scalars for hexadecimal characters.
///
let HEX_1:               [UnicodeScalar] = "0123456789abcdefABCDEF".unicodeScalars.map { $0 }
/*===============================================================================================================================================================================*/
/// Array of unicode scalars for
///
let XML_1:               [UnicodeScalar] = ":ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_".unicodeScalars.map { $0 }
let XML_2:               [UnicodeScalar] = [ UnicodeScalar(UInt8(0xb7)) ] + XML_1 + "-.0123456789".unicodeScalars.map { $0 }
let XML_3:               [Range<UInt32>] = [ (UInt32(0xc0)   ..< UInt32(0xd7)),    (UInt32(0xd8)   ..< UInt32(0xf7)),   (UInt32(0xf8)   ..< UInt32(0x300)),  (UInt32(0x370)   ..< UInt32(0x37e)),
                                             (UInt32(0x37f)  ..< UInt32(0x2000)),  (UInt32(0x200c) ..< UInt32(0x200e)), (UInt32(0x2070) ..< UInt32(0x2190)), (UInt32(0x2c00)  ..< UInt32(0x2ff0)),
                                             (UInt32(0x3001) ..< UInt32(0xd800)),  (UInt32(0xf900) ..< UInt32(0xfdd0)), (UInt32(0xfdf0) ..< UInt32(0xfffe)), (UInt32(0x10000) ..< UInt32(0xf0000)) ]
let XML_4:               [Range<UInt32>] = [ (UInt32(0x0300) ..< UInt32(0x0370)),  (UInt32(0x203f) ..< UInt32(0x2041)) ] + XML_3

extension Unicode.Scalar {
    var isXmlNameStartChar: Bool { XML_1.contains(self) || XML_3.isAny(predicate: { $0.contains(value) }) }
    var isXmlNameChar:      Bool { XML_2.contains(self) || XML_4.isAny(predicate: { $0.contains(value) }) }
    var isXmlWhitespace:    Bool { (value <= UInt32(0x20)) || (value == UInt32(0x7f)) } // Anything less than or equal to the space character will be considered whitespace.
    var isXmlHex:           Bool { HEX_1.contains(self) }
}

extension Character {
    var isXmlNameStartChar: Bool { unicodeScalars.count == 1 && unicodeScalars.areAll { $0.isXmlNameStartChar } }
    var isXmlNameChar:      Bool { unicodeScalars.areAll { $0.isXmlNameChar }                                   }
    var isXmlWhitespace:    Bool { unicodeScalars.areAll { $0.isXmlWhitespace }                                 }
    var isXmlHex:           Bool { unicodeScalars.areAll { $0.isXmlHex }                                        }
}

extension String {
    var isXmlName:  Bool { !isEmpty && (unicodeScalars.first?.isXmlNameStartChar ?? false) && unicodeScalars.areAll { $0.isXmlNameChar } }
    var isXmlToken: Bool { !isEmpty && unicodeScalars.areAll { $0.isXmlNameChar } }
    var isXmlHex:   Bool { !isEmpty && unicodeScalars.areAll { $0.isXmlHex } }

    func getXmlPrefixAndLocalName() -> (prefix: String?, localName: String) {
        let parts = split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return (prefix: nil, localName: self) }
        let pfx = String(parts[0]).trimmed
        return (prefix: pfx.isEmpty ? nil : pfx, localName: String(parts[1]).trimmed)
    }
}
//@f:1

extension CharacterSet {
    static var XMLWhitespace: CharacterSet { CharacterSet(charactersIn: UnicodeScalar(0) ..< UnicodeScalar(0x21)).union(CharacterSet(charactersIn: UnicodeScalar(0x7f) ..< UnicodeScalar(0x80))) }
}
