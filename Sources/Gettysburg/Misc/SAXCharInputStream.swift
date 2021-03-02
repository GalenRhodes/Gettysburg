/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: SAXCharInputStream.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 2/17/21
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

@usableFromInline class SAXCharInputStream: IConvCharInputStream {
    @usableFromInline let baseURL:  URL
    @usableFromInline let url:      URL
    @usableFromInline let filename: String

    @usableFromInline init(inputStream: MarkInputStream, url: URL) throws {
        self.url = url

        let burl = try getURL(string: self.url.absoluteString)
        baseURL = burl.deletingLastPathComponent()
        filename = burl.lastPathComponent

        let enc = try getFileEncoding(inputStream)
        super.init(inputStream: inputStream, autoClose: true, encodingName: enc)
    }

    @inlinable @discardableResult override func markBackup(count cc: Int = 1) -> Int { super.markBackup(count: cc) }
}

@usableFromInline let BOM32BE:                 [UInt8] = [ 0, 0, 0xfe, 0xff ]
@usableFromInline let BOM32LE:                 [UInt8] = [ 0xff, 0xfe, 0, 0 ]
@usableFromInline let XML_DECL_PREFIX_PATTERN: String  = "\\<\\?(?i:xml)\\s"

@inlinable func getFileEncoding(_ istr: MarkInputStream) throws -> String {
    let e1 = try determineEncoding(istr)
    let e2 = try checkXMLDecl(istr, guessedEncoding: e1)
    return e2
}

@inlinable func determineEncoding(_ inputStream: MarkInputStream) throws -> String {
    if inputStream.streamStatus == .notOpen { inputStream.open() }
    inputStream.markSet()
    defer { inputStream.markReturn() }

    var buffer: [UInt8] = [ 0, 0, 0, 0 ]
    guard inputStream.read(&buffer, maxLength: 4) == 4 else { throw inputStream.streamError ?? StreamError.UnexpectedEndOfInput() }

    if buffer == BOM32BE || buffer == BOM32LE { return "UTF-32" }
    if buffer[0 ..< 2] == BOM32BE[2 ..< 4] || buffer[0 ..< 2] == BOM32LE[0 ..< 2] { return "UTF-16" }

    if buffer[0] == 0 && buffer[1] == 0 && buffer[3] != 0 { return "UTF-32BE" }
    if buffer[0] != 0 && buffer[2] == 0 && buffer[3] == 0 { return "UTF-32LE" }

    if buffer[0] == 0 && buffer[1] != 0 && buffer[2] == 0 && buffer[3] != 0 { return "UTF-16BE" }
    if buffer[0] != 0 && buffer[1] == 0 && buffer[2] != 0 && buffer[3] == 0 { return "UTF-16LE" }

    return "UTF-8"
}

@inlinable func checkXMLDecl(_ inputStream: MarkInputStream, guessedEncoding: String) throws -> String {
    inputStream.markSet()
    defer { inputStream.markReturn() }
    let charStream = IConvCharInputStream(inputStream: inputStream, autoClose: false, encodingName: guessedEncoding)
    charStream.open()
    defer { charStream.close() }

    let str = try charStream.readString(count: 6, errorOnEOF: false)

    if try str.matches(pattern: XML_DECL_PREFIX_PATTERN) {
        let xmlDecl = try charStream.readUntil(found: "?>")

        if let regex = RegularExpression(pattern: "\\s(?:encoding)=\"([^\"]+)\"") {

            if let match = regex.firstMatch(in: xmlDecl), let enc = match[1].subString?.uppercased(), enc != guessedEncoding {
                let fin = getFinalEncoding(inferredEnc: guessedEncoding, xmlDeclEnc: enc)
                guard IConv.getEncodingsList().contains(fin) else { throw SAXError.UnsupportedCharacterEncoding(1, 1, description: "Unsupported Character Encoding: \(fin)") }
                return fin
            }
        }
    }

    return guessedEncoding
}

@inlinable func getFinalEncoding(inferredEnc: String, xmlDeclEnc: String) -> String {
    switch inferredEnc {
        case "UTF-32", "UTF-32BE", "UTF-32LE": if !xmlDeclEnc.hasPrefix("UTF-32") { return xmlDeclEnc }
        case "UTF-16", "UTF-16BE", "UTF-16LE": if !xmlDeclEnc.hasPrefix("UTF-16") { return xmlDeclEnc }
        default: return xmlDeclEnc
    }
    return inferredEnc
}
