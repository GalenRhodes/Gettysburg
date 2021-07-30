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

struct XMLDecl: Hashable {
    var version:    String
    var encoding:   String
    var standalone: Bool

    static func processXMLDecl(inputStream: SimpleCharInputStream, position: DocPosition = DocPosition(line: 1, column: 1, tabSize: 4)) throws -> XMLDecl? {
        // Read the first 5 characters and see if we have an XML Decl...
        var chars: [Character] = []
        var pos:   DocPosition = position

        if try (inputStream.read(chars: &chars, maxLength: 6) == 6) && (chars[..<5] == "<?xml".getCharacters()) && chars[5].isXmlWhitespace {
            repeat {
                guard chars.count < (1024 * 1024) else { throw SAXError.RunawayInput(position: pos.update(chars)) }
                guard let ch = try inputStream.read() else { throw SAXError.getUnexpectedEndOfInput() }
                chars <+ ch
            } while chars.last(count: 2) != [ "?", ">" ]

            var xmlDecl: XMLDecl = XMLDecl(version: "1.0", encoding: inputStream.encodingName, standalone: true)
            let rx               = RegularExpression(pattern: RX_XML_DECL)!
            let str              = String(chars)

            guard let match = rx.firstMatch(in: str) else { throw SAXError.MalformedXmlDecl(position: pos, description: "Malformed XML Declaration.") }

            if let r = match[1].range {
                let s = String(str[r]).unQuoted().trimmed
                guard value(s, isOneOf: "1.0", "1.1") else { throw SAXError.MalformedXmlDecl(position: pos.update(str[..<r.lowerBound]), description: "Invalid version: \(s)") }
                xmlDecl.version = s
            }

            if let s = match[2].subString?.unQuoted().trimmed, s.isNotEmpty {
                xmlDecl.encoding = s
            }

            if let r = match[3].range {
                let s = String(str[r]).unQuoted().trimmed
                guard value(s, isOneOf: "yes", "no") else { throw SAXError.MalformedXmlDecl(position: pos.update(str[..<r.lowerBound]), description: "Invalid standalone value: \(s)") }
                xmlDecl.standalone = (s == "yes")
            }

            return xmlDecl
        }

        return nil
    }
}
