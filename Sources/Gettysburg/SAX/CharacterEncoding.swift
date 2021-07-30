/*****************************************************************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: CharacterEncoding.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: July 15, 2021
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
import Chadakoin

@usableFromInline let FourBytes: [([UInt8], String)] = [
    ([ 0x00, 0x00, 0xfe, 0xff ], "UTF-32"),
    ([ 0xff, 0xfe, 0x00, 0x00 ], "UTF-32"),
    ([ 0xdd, 0x73, 0x66, 0x73 ], "UTF-EBCDIC"),
    ([ 0x84, 0x31, 0x95, 0x33 ], "GB-18030"),
]

@usableFromInline let ThreeBytes: [([UInt8], String)] = [
    ([ 0xef, 0xbb, 0xbf ], "UTF-8"),
    ([ 0x2b, 0x2f, 0x76 ], "UTF-7"),
    ([ 0xf7, 0x64, 0x4c ], "UTF-1"),
    ([ 0x0E, 0xFE, 0xFF ], "SCSU"),
    ([ 0xFB, 0xEE, 0x28 ], "BOCU-1"),
]

@usableFromInline let TwoBytes: [([UInt8], String)] = [
    ([ 0xfe, 0xff ], "UTF-16"),
    ([ 0xff, 0xfe ], "UTF-16"),
]

public func getEncodingName(data: Data) throws -> String {
    try getEncodingName(byteStream: MarkInputStream(data: data))
}

public func getEncodingName(filename: String) throws -> String {
    guard let byteStream = MarkInputStream(fileAtPath: filename) else { throw StreamError.FileNotFound(description: filename) }
    defer { byteStream.close() }
    return try getEncodingName(byteStream: byteStream)
}

public func getEncodingName(url: URL, options: URLInputStreamOptions = [], authenticate: AuthenticationCallback? = nil) throws -> String {
    guard let byteStream = MarkInputStream(url: url, options: options, authenticate: authenticate) else { throw StreamError.FileNotFound(description: url.absoluteString) }
    defer { byteStream.close() }
    return try getEncodingName(byteStream: byteStream)
}

public func getEncodingName(inputStream: InputStream) throws -> (String, InputStream) {
    if let byteStream = inputStream as? MarkInputStream { return (try getEncodingName(byteStream: byteStream), byteStream) }
    let byteStream = MarkInputStream(inputStream: inputStream)
    return (try getEncodingName(byteStream: byteStream), byteStream)
}

private func getEncodingName(byteStream: MarkInputStream) throws -> String {
    byteStream.open()

    do {
        byteStream.markSet()
        defer { byteStream.markDelete() }

        // See if a web server is telling is what it thinks it is...
        var bytes: [UInt8] = Array<UInt8>(repeating: 0, count: 4)

        let res = byteStream.read(&bytes, maxLength: 4)
        if res < 0 { throw byteStream.streamError ?? StreamError.UnknownError() }
        if res < 4 { throw StreamError.UnexpectedEndOfInput() }

        for t in FourBytes { if bytes == t.0 { return t.1 } }
        if bytes[0] == 0 && bytes[1] == 0 && bytes[2] == 0 && bytes[3] != 0 { return "UTF-32BE" }
        if bytes[0] != 0 && bytes[1] == 0 && bytes[2] == 0 && bytes[3] == 0 { return "UTF-32LE" }

        bytes.removeLast()
        _ = byteStream.markBackup()
        for t in ThreeBytes { if bytes == t.0 { return t.1 } }

        bytes.removeLast()
        _ = byteStream.markBackup()
        for t in TwoBytes { if bytes == t.0 { return t.1 } }
        if bytes[0] == 0 && bytes[1] != 0 { return "UTF-16BE" }
        if bytes[0] != 0 && bytes[1] == 0 { return "UTF-16LE" }

        // We'll do this the hard way.  We'll start out assuming UTF-8
        do {
            byteStream.markReset()
            defer { byteStream.markReset() }
            let charStream = SimpleIConvCharInputStream(inputStream: byteStream, encodingName: "UTF-8", autoClose: false)
            charStream.open()
            defer { charStream.close() }

            var buffer: [Character] = []

            guard try charStream.read(chars: &buffer, maxLength: 5) == 5 else { throw StreamError.UnexpectedEndOfInput() }
            guard String(buffer) == "<?xml" else { return "UTF-8" }

            while let ch = try charStream.read() {
                buffer <+ ch
                if buffer.last(count: 2) == [ "?", ">" ] {
                    let decl = String(buffer)
                    if RegularExpression(pattern: "^\\<\\?xml\\s")?.firstMatch(in: decl) != nil {
                        if let m = RegularExpression(pattern: "\\sencoding=((?:\"[^\"]+\")|(?:'[^']+'))(?:\\s|\\?)")?.firstMatch(in: decl), let enc = m[1].subString {
                            return enc.unQuoted().uppercased()
                        }
                    }
                    // This is the default case...
                    return "UTF-8"
                }
            }

            throw StreamError.UnexpectedEndOfInput()
        }
    }
    catch let err {
        byteStream.close()
        throw err
    }
}

@inlinable func getBOMForName(name: String) -> [UInt8] {
    if let bom = FourBytes.first(where: { $0.1 == name }) { return bom.0 }
    if let bom = ThreeBytes.first(where: { $0.1 == name }) { return bom.0 }
    if let bom = TwoBytes.first(where: { $0.1 == name }) { return bom.0 }
    return []
}

@inlinable func shouldRemoveBOM(read: [UInt8], bom: [UInt8]) -> Bool { (bom.isNotEmpty && (read.first(count: bom.count) == bom)) }

func removeBOM(inputStream: MarkInputStream, encodingName: String) throws {
    #if REMOVEBOM
        inputStream.open()
        inputStream.markSet()
        defer { inputStream.markReturn() }
        var bytes: [UInt8] = Array<UInt8>(repeating: 0, count: 4)

        let res = inputStream.read(&bytes, maxLength: 4)
        if res < 0 { throw inputStream.streamError ?? StreamError.UnknownError() }
        if res < 4 { throw StreamError.UnexpectedEndOfInput() }

        switch encodingName {
          // 4 bytes
            case "UTF-EBCDIC": if shouldRemoveBOM(read: bytes, bom: getBOMForName(name: encodingName)) { inputStream.markClear() }
            case "GB-18030":   if shouldRemoveBOM(read: bytes, bom: getBOMForName(name: encodingName)) { inputStream.markClear() }
          // 3 bytes
            case "UTF-8":      if shouldRemoveBOM(read: bytes, bom: getBOMForName(name: encodingName)) { _ = inputStream.markBackup(); inputStream.markClear() }
            case "UTF-7":      if shouldRemoveBOM(read: bytes, bom: getBOMForName(name: encodingName)) { _ = inputStream.markBackup(); inputStream.markClear() }
            case "UTF-1":      if shouldRemoveBOM(read: bytes, bom: getBOMForName(name: encodingName)) { _ = inputStream.markBackup(); inputStream.markClear() }
            case "SCSU":       if shouldRemoveBOM(read: bytes, bom: getBOMForName(name: encodingName)) { _ = inputStream.markBackup(); inputStream.markClear() }
            case "BOCU-1":     if shouldRemoveBOM(read: bytes, bom: getBOMForName(name: encodingName)) { _ = inputStream.markBackup(); inputStream.markClear() }
          // Otherwise leave the bytes at the beginning...
            default:           break
        }
    #endif
}

