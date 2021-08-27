/*****************************************************************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: XMLDecl.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: July 30, 2021
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

struct XMLDecl: Hashable, Codable, CustomStringConvertible {
    enum Version: String, Codable { case v1_0 = "1.0", v1_1 = "1.1", v1_2 = "1.2" }

    enum Standalone: String, Codable { case yes, no }

    var version:     Version
    var encoding:    String
    var standalone:  Standalone
    var description: String { "<?xml version=\"\(version)\" encoding=\"\(encoding)\" standalone=\"\(standalone)\"?>" }

    init(version: Version, encoding: String, standalone: Standalone) {
        self.version = version
        self.encoding = encoding
        self.standalone = standalone
    }

    init?(inputStream: MarkInputStream, encodingName: String) throws {
        do {
            inputStream.markSet()
            defer { inputStream.markReturn() }
            var pos = DocPosition()
            let ins = SimpleIConvCharInputStream(inputStream: inputStream, encodingName: encodingName, autoClose: false)
            guard let xd = try XMLDecl.setup(inputStream: ins, position: &pos) else { return nil }
            (version, encoding, standalone) = xd
        }
        catch {
            return nil
        }
    }

    init?(charStream: SAXCharInputStream) throws {
        do {
            charStream.markSet()
            var pos = charStream.docPosition
            guard let xd = try XMLDecl.setup(inputStream: charStream, position: &pos) else {
                charStream.markReturn()
                return nil
            }
            (version, encoding, standalone) = xd
            charStream.markRelease()
        }
        catch let e {
            throw e
        }
    }

    private static func setup(inputStream: SimpleCharInputStream, position pos: inout DocPosition) throws -> (Version, String, Standalone)? {
        // Read the first 5 characters and see if we have an XML Decl...
        var chars:      [Character] = []
        var version:    Version     = .v1_0
        var encoding:   String      = inputStream.encodingName
        var standalone: Standalone  = .yes

        if try (inputStream.read(chars: &chars, maxLength: 6) == 6) && (chars[..<5] == "<?xml".getCharacters()) && chars[5].isXmlWhitespace {
            repeat {
                guard chars.count < (1024 * 1024) else { throw SAXError.RunawayInput(position: pos.update(chars)) }
                guard let ch = try inputStream.read() else { throw SAXError.getUnexpectedEndOfInput() }
                chars <+ ch
            } while chars.last(count: 2) != [ "?", ">" ]

            let rx  = RegularExpression(pattern: RX_XML_DECL)!
            let str = String(chars)

            guard let match = rx.firstMatch(in: str) else { throw SAXError.MalformedXmlDecl(position: pos, description: "Malformed XML Declaration.") }

            if let r = match[1].range {
                let s = String(str[r]).unQuoted().trimmed
                guard let v = Version(rawValue: s) else { throw SAXError.MalformedXmlDecl(position: pos.update(str[..<r.lowerBound]), description: "Invalid version: \(s)") }
                version = v
            }

            if let s = match[2].subString?.unQuoted().trimmed, s.isNotEmpty {
                encoding = s
            }

            if let r = match[3].range {
                let s = String(str[r]).unQuoted().trimmed
                guard let sa = Standalone(rawValue: s) else { throw SAXError.MalformedXmlDecl(position: pos.update(str[..<r.lowerBound]), description: "Invalid standalone value: \(s)") }
                standalone = sa
            }

            pos.update(chars)
            return (version, encoding, standalone)
        }
        else {
            return nil
        }
    }
}
