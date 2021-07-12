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
extension Unicode.Scalar {
    @inlinable var isXmlNameStartChar: Bool { CharacterSet.XMLNameStartChar.contains(self) }
    @inlinable var isXmlNameChar:      Bool { CharacterSet.XMLNameChar.contains(self) }
    @inlinable var isXmlWhitespace:    Bool { CharacterSet.XMLWhitespace.contains(self) }
    @inlinable var isXmlHex:           Bool { CharacterSet.XMLHex.contains(self) }
}

extension Character {
    @inlinable var isXmlNameStartChar: Bool { unicodeScalars.count == 1 && unicodeScalars.areAll(predicate: { $0.isXmlNameStartChar }) }
    @inlinable var isXmlNameChar:      Bool { unicodeScalars.areAll(predicate: { $0.isXmlNameChar }) }
    @inlinable var isXmlWhitespace:    Bool { unicodeScalars.areAll(predicate: { $0.isXmlWhitespace }) }
    @inlinable var isXmlHex:           Bool { unicodeScalars.areAll(predicate: { $0.isXmlHex }) }
}

extension String {
    @inlinable var isXmlName:          Bool { !isEmpty && (unicodeScalars.first?.isXmlNameStartChar ?? false) && unicodeScalars.areAll(predicate: { $0.isXmlNameChar }) }
    @inlinable var isXmlToken:         Bool { !isEmpty && unicodeScalars.areAll(predicate: { $0.isXmlNameChar }) }
    @inlinable var isXmlHex:           Bool { !isEmpty && unicodeScalars.areAll(predicate: { $0.isXmlHex }) }

    @inlinable func getXmlPrefixAndLocalName() -> (prefix: String?, localName: String) {
        let parts = split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return (prefix: nil, localName: self) }
        let pfx = String(parts[0]).trimmed
        return (prefix: pfx.isEmpty ? nil : pfx, localName: String(parts[1]).trimmed)
    }
}
//@f:1

extension CharacterSet {
    static public let XMLHex: CharacterSet = CharacterSet(charactersIn: "0123456789abcdefABCDEF")

    static public let XMLWhitespace: CharacterSet = {
        // Anything less than or equal to the space character will be considered whitespace.
        CharacterSet(charactersIn: UnicodeScalar(0) ... UnicodeScalar(0x20)).union(CharacterSet(charactersIn: UnicodeScalar(0x7f) ... UnicodeScalar(0x7f)))
    }()

    static public let XMLNameStartChar: CharacterSet = {
        var cs = CharacterSet(charactersIn: ":ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_")
        [ (UInt32(0x000c0) ..< UInt32(0x000d7)), (UInt32(0x000d8) ..< UInt32(0x000f7)), (UInt32(0x000f8) ..< UInt32(0x00300)) ].forEach { cs.formUnion(CharacterSet(range: $0)) }
        [ (UInt32(0x00370) ..< UInt32(0x0037e)), (UInt32(0x0037f) ..< UInt32(0x02000)), (UInt32(0x0200c) ..< UInt32(0x0200e)) ].forEach { cs.formUnion(CharacterSet(range: $0)) }
        [ (UInt32(0x02070) ..< UInt32(0x02190)), (UInt32(0x02c00) ..< UInt32(0x02ff0)), (UInt32(0x03001) ..< UInt32(0x0d800)) ].forEach { cs.formUnion(CharacterSet(range: $0)) }
        [ (UInt32(0x0f900) ..< UInt32(0x0fdd0)), (UInt32(0x0fdf0) ..< UInt32(0x0fffe)), (UInt32(0x10000) ..< UInt32(0xf0000)) ].forEach { cs.formUnion(CharacterSet(range: $0)) }
        return cs
    }()

    static public let XMLNameChar: CharacterSet = {
        var cs = XMLNameStartChar.union(CharacterSet(charactersIn: "-.0123456789")).union(CharacterSet(charactersIn: UnicodeScalar(0xb7) ... UnicodeScalar(0xb7)))
        [ (UInt32(0x0300) ..< UInt32(0x0370)), (UInt32(0x203f) ..< UInt32(0x2041)) ].forEach { cs.formUnion(CharacterSet(range: $0)) }
        return cs
    }()

    public init(range: Range<UInt32>) {
        if range.isEmpty { self.init() }
        else { self.init(range: range.lowerBound ... (range.upperBound - 1)) }
    }

    public init(range: ClosedRange<UInt32>) {
        guard let lo = UnicodeScalar(range.lowerBound) else { fatalError("Not a valid Unicode Scalar: \(range.lowerBound)") }
        guard let hi = UnicodeScalar(range.upperBound) else { fatalError("Not a valid Unicode Scalar: \(range.upperBound)") }
        self.init(charactersIn: lo ... hi)
    }

    @inlinable public func contains(char: Character) -> Bool {
        for s in char.unicodeScalars { guard contains(s) else { return false } }
        return true
    }
}
