/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: Entities.swift
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
    /// Read the entity reference and resolve it.
    /// 
    /// - Returns: the resolved entity reference.
    /// - Throws: if the entity reference is malformed or there is an error during resolution.
    ///
    func readAndResolveEntityReference() throws -> String { try readAndResolveEntityReference(charStream) }

    /*===========================================================================================================================================================================*/
    /// Read the entity reference and resolve it.
    /// 
    /// - Parameter chStream: the [input stream](http://goober/Rubicon/Protocols/CharInputStream.html) to read from.
    /// - Returns: the resolved entity reference.
    /// - Throws: if the entity reference is malformed or there is an error during resolution.
    ///
    func readAndResolveEntityReference(_ chStream: CharInputStream) throws -> String {
        chStream.markSet()
        defer { chStream.markDelete() }
        var ch = try readChar(chStream)

        if ch == "#" {
            ch = try readChar(chStream)
            let hex = (ch == "x")
            if hex { ch = try readChar(chStream) }
            return try String(readCharacterEntityReference_Dec(chStream, char: ch, isHexadecimal: hex))
        }
        else if ch.isXmlNameStartChar {
            let entity = try doReadUntil(chStream) { c, _ in
                guard c.isXmlNameChar else {
                    chStream.markBackup()
                    throw SAXError.InvalidCharacter(chStream, description: getBadCharMsg(ch))
                }
                return (c == ";")
            }
            switch entity {
                case "amp":  return "&"
                case "lt":   return "<"
                case "gt":   return ">"
                case "quot": return "\""
                case "apos": return "'"
                default:
                    do { if let e = try resolveEntityReference(chStream, entityName: entity) { return e } }
                    catch let e { chStream.markReset(); throw SAXError.InvalidEntityReference(chStream, description: e.localizedDescription) }
                    if let e = XML_ENTITY_MAP[entity] { return e }
                    if let e = XML_ENTITY_MAP[entity.lowercased()] { return e }
                    return "&\(entity);"
            }
        }
        else {
            chStream.markBackup()
            throw SAXError.InvalidCharacter(chStream, description: getBadCharMsg(ch))
        }
    }

    /*===========================================================================================================================================================================*/
    /// Read the scalar value for the <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> entity reference.
    /// 
    /// - Parameters:
    ///   - chStream: the [input stream](http://goober/Rubicon/Protocols/CharInputStream.html) to read from.
    ///   - ch: the first <code>[Character](https://developer.apple.com/documentation/swift/Character)</code> of the scalar.
    ///   - hex: `true` if the scalar is in hexadecimal format or `false` if it is in decimal format.
    /// - Returns: the resolved <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>.
    /// - Throws: if the scalar is malformed.
    ///
    private func readCharacterEntityReference_Dec(_ chStream: CharInputStream, char ch: Character, isHexadecimal hex: Bool) throws -> Character {
        var chars: [Character] = []
        var ch:    Character   = ch

        chStream.markSet()
        defer { chStream.markDelete() }

        repeat {
            if ch == ";" {
                let str = String(chars)
                if let i = UInt32(str, radix: hex ? 16 : 10) { return Character(scalar: UnicodeScalar(i)) }
                chStream.markReset()
                throw SAXError.MalformedNumber(chStream, description: "The \(hex ? "hexadecimal" : "decimal") number \"\(str)\" is too large.")
            }
            else if !(hex ? ch.isXmlHex : ((ch >= "0") && (ch <= "9"))) {
                chStream.markBackup()
                throw SAXError.InvalidCharacter(chStream, description: getBadCharMsg(ch))
            }
            chars <+ ch
            ch = try readChar(chStream)
        }
        while true
    }

    /*===========================================================================================================================================================================*/
    /// Resolve Entity Reference...
    /// 
    /// - Parameters:
    ///   - chStream: the [input stream](http://goober/Rubicon/Protocols/CharInputStream.html) to read from.
    ///   - ent: the entity name.
    /// - Returns: the text of the entity.
    /// - Throws: if an error occurs.
    ///
    private func resolveEntityReference(_ chStream: CharInputStream, entityName ent: String) throws -> String? {
        // TODO: Resolve Entity Reference...
        "&\(ent);"
    }
}
