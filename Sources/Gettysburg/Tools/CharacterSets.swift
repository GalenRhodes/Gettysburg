/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: CharacterSets.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 11/14/20
 *
 * Copyright © 2020 Galen Rhodes. All rights reserved.
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

let Letters: String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
let CRLF:    String = "\r\n"
let Nums:    String = "0123456789"

extension CharacterSet {
    public static var xmlWhiteSpace:      CharacterSet = CharacterSet(charactersIn: " \t\(CRLF)")
    public static var xmlPublicIdChar:    CharacterSet = CharacterSet(charactersIn: " \(CRLF)\(Letters)\(Nums)-'()+,./:=?;!*#@$_%")
    public static var xmlNameStartChar:   CharacterSet = getXmlNameStartChar()
    public static var xmlNameChar:        CharacterSet = getXmlNameChar()
    public static var xmlChar:            CharacterSet = getXmlChar()
    public static var xmlNsNameStartChar: CharacterSet = getXmlNsNameStartChar()
    public static var xmlNsNameChar:      CharacterSet = getXmlNsNameChar()

    private static func getXmlNsNameStartChar() -> CharacterSet {
        var cs = CharacterSet(bitmapRepresentation: xmlNameStartChar.bitmapRepresentation)
        cs.remove(charactersIn: ":")
        return cs
    }

    private static func getXmlNsNameChar() -> CharacterSet {
        var cs = CharacterSet(bitmapRepresentation: xmlNameChar.bitmapRepresentation)
        cs.remove(charactersIn: ":")
        return cs
    }

    private static func getXmlNameStartChar() -> CharacterSet {
        var cs = CharacterSet(charactersIn: ":_\(Letters)")
        cs.insert(charactersIn: UnicodeScalar(UInt8(0xc0)) ... UnicodeScalar(UInt8(0xd6)))
        cs.insert(charactersIn: UnicodeScalar(UInt8(0xd8)) ... UnicodeScalar(UInt8(0xf6)))
        cs.insert(charactersIn: UnicodeScalar(UInt8(0xf8)) ... UnicodeScalar(UInt16(0x02ff))!)
        cs.insert(charactersIn: UnicodeScalar(UInt16(0x0370))! ... UnicodeScalar(UInt16(0x037d))!)
        cs.insert(charactersIn: UnicodeScalar(UInt16(0x037f))! ... UnicodeScalar(UInt16(0x1fff))!)
        cs.insert(charactersIn: UnicodeScalar(UInt16(0x200c))! ... UnicodeScalar(UInt16(0x200d))!)
        cs.insert(charactersIn: UnicodeScalar(UInt16(0x2070))! ... UnicodeScalar(UInt16(0x218f))!)
        cs.insert(charactersIn: UnicodeScalar(UInt16(0x2c00))! ... UnicodeScalar(UInt16(0x2fef))!)
        cs.insert(charactersIn: UnicodeScalar(UInt16(0x3001))! ... UnicodeScalar(UInt16(0xd7ff))!)
        cs.insert(UnicodeScalar(UInt16(0xf900))!)
        cs.insert(charactersIn: UnicodeScalar(UInt32(0x10000))! ... UnicodeScalar(UInt32(0xefffd))!)
        cs.remove(charactersIn: UnicodeScalar(UInt32(0x1fffe))! ... UnicodeScalar(UInt32(0x1ffff))!)
        cs.remove(charactersIn: UnicodeScalar(UInt32(0x2fffe))! ... UnicodeScalar(UInt32(0x2ffff))!)
        cs.remove(charactersIn: UnicodeScalar(UInt32(0x3fffe))! ... UnicodeScalar(UInt32(0x3ffff))!)
        cs.remove(charactersIn: UnicodeScalar(UInt32(0x4fffe))! ... UnicodeScalar(UInt32(0x4ffff))!)
        cs.remove(charactersIn: UnicodeScalar(UInt32(0x5fffe))! ... UnicodeScalar(UInt32(0x5ffff))!)
        cs.remove(charactersIn: UnicodeScalar(UInt32(0x6fffe))! ... UnicodeScalar(UInt32(0x6ffff))!)
        cs.remove(charactersIn: UnicodeScalar(UInt32(0x7fffe))! ... UnicodeScalar(UInt32(0x7ffff))!)
        cs.remove(charactersIn: UnicodeScalar(UInt32(0x8fffe))! ... UnicodeScalar(UInt32(0x8ffff))!)
        cs.remove(charactersIn: UnicodeScalar(UInt32(0x9fffe))! ... UnicodeScalar(UInt32(0x9ffff))!)
        cs.remove(charactersIn: UnicodeScalar(UInt32(0xafffe))! ... UnicodeScalar(UInt32(0xaffff))!)
        cs.remove(charactersIn: UnicodeScalar(UInt32(0xbfffe))! ... UnicodeScalar(UInt32(0xbffff))!)
        cs.remove(charactersIn: UnicodeScalar(UInt32(0xcfffe))! ... UnicodeScalar(UInt32(0xcffff))!)
        cs.remove(charactersIn: UnicodeScalar(UInt32(0xdfffe))! ... UnicodeScalar(UInt32(0xdffff))!)
        return cs
    }

    private static func getXmlNameChar() -> CharacterSet {
        var cs = CharacterSet(bitmapRepresentation: xmlNameStartChar.bitmapRepresentation)
        cs.insert(charactersIn: "-.\(Nums)")
        cs.insert(UnicodeScalar(UInt8(0xb7)))
        cs.insert(charactersIn: UnicodeScalar(UInt16(0x0300))! ... UnicodeScalar(UInt16(0x036f))!)
        cs.insert(charactersIn: UnicodeScalar(UInt16(0x203f))! ... UnicodeScalar(UInt16(0x2040))!)
        return cs
    }

    private static func getXmlChar() -> CharacterSet {
        var cs = CharacterSet(bitmapRepresentation: xmlWhiteSpace.bitmapRepresentation)
        cs.insert(charactersIn: UnicodeScalar(UInt8(0x21)) ... UnicodeScalar(UInt16(0xd7ff))!)
        cs.insert(charactersIn: UnicodeScalar(UInt16(0xe000))! ... UnicodeScalar(UInt16(0xf900))!)
        cs.insert(charactersIn: UnicodeScalar(UInt32(0x10000))! ... UnicodeScalar(UInt32(0x10fffd))!)
        cs.remove(charactersIn: UnicodeScalar(UInt8(0x7f)) ... UnicodeScalar(UInt8(0x84)))
        cs.remove(charactersIn: UnicodeScalar(UInt8(0x86)) ... UnicodeScalar(UInt8(0x9f)))
        cs.remove(charactersIn: UnicodeScalar(UInt32(0x1fffe))! ... UnicodeScalar(UInt32(0x1ffff))!)
        cs.remove(charactersIn: UnicodeScalar(UInt32(0x2fffe))! ... UnicodeScalar(UInt32(0x2ffff))!)
        cs.remove(charactersIn: UnicodeScalar(UInt32(0x3fffe))! ... UnicodeScalar(UInt32(0x3ffff))!)
        cs.remove(charactersIn: UnicodeScalar(UInt32(0x4fffe))! ... UnicodeScalar(UInt32(0x4ffff))!)
        cs.remove(charactersIn: UnicodeScalar(UInt32(0x5fffe))! ... UnicodeScalar(UInt32(0x5ffff))!)
        cs.remove(charactersIn: UnicodeScalar(UInt32(0x6fffe))! ... UnicodeScalar(UInt32(0x6ffff))!)
        cs.remove(charactersIn: UnicodeScalar(UInt32(0x7fffe))! ... UnicodeScalar(UInt32(0x7ffff))!)
        cs.remove(charactersIn: UnicodeScalar(UInt32(0x8fffe))! ... UnicodeScalar(UInt32(0x8ffff))!)
        cs.remove(charactersIn: UnicodeScalar(UInt32(0x9fffe))! ... UnicodeScalar(UInt32(0x9ffff))!)
        cs.remove(charactersIn: UnicodeScalar(UInt32(0xafffe))! ... UnicodeScalar(UInt32(0xaffff))!)
        cs.remove(charactersIn: UnicodeScalar(UInt32(0xbfffe))! ... UnicodeScalar(UInt32(0xbffff))!)
        cs.remove(charactersIn: UnicodeScalar(UInt32(0xcfffe))! ... UnicodeScalar(UInt32(0xcffff))!)
        cs.remove(charactersIn: UnicodeScalar(UInt32(0xdfffe))! ... UnicodeScalar(UInt32(0xdffff))!)
        cs.remove(charactersIn: UnicodeScalar(UInt32(0xefffe))! ... UnicodeScalar(UInt32(0xeffff))!)
        cs.remove(charactersIn: UnicodeScalar(UInt32(0xffffe))! ... UnicodeScalar(UInt32(0xfffff))!)
        return cs
    }
}

extension Character {
    @usableFromInline func test(isNot other: Character...) -> Bool {
        for c in other { if self == c { return false } }
        return true
    }

    @usableFromInline func test(is other: Character...) -> Bool {
        for c in other { if self == c { return true } }
        return false
    }

    @usableFromInline func test(is other: CharacterSet) -> Bool {
        for scalar in unicodeScalars { if other.contains(scalar) { return true } }
        return false
    }

    @usableFromInline func test(isNot other: CharacterSet) -> Bool {
        for scalar in unicodeScalars { if other.contains(scalar) { return false } }
        return true
    }
}
