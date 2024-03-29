/*****************************************************************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: StringProtocol.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: July 11, 2021
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

extension Collection where Element == Character {

    @discardableResult @inlinable func skipWS(_ idx: inout Self.Index, position pos: inout DocPosition, peek: Bool = false) -> Character? {
        while idx < endIndex && self[idx].isXmlWhitespace {
            pos.update(self[idx])
            formIndex(after: &idx)
        }
        guard idx < endIndex else { return nil }
        let ch = self[idx]
        if !peek {
            pos.update(ch)
            formIndex(after: &idx)
        }
        return ch
    }

    @inlinable func splitPrefix() -> QName { QName(qName: asString) }

    @inlinable func noLF() -> String {
        let str = asString
        return RegularExpression(pattern: "\\R+")?.stringByReplacingMatches(in: str, using: { _ in " " }).0 ?? str
    }

    @inlinable func collapeWS() -> String {
        let str = asString
        return RegularExpression(pattern: "\\s+")?.stringByReplacingMatches(in: str, using: { _ in " " }).0 ?? str
    }
}

extension Collection where Element == Character, Index == String.Index {

    @inlinable func nextChar(index idx: inout String.Index, position pos: inout DocPosition, peek: Bool = false) throws -> Character {
        guard idx < endIndex else { throw SAXError.MalformedElementDecl(position: pos, description: "Unexpected end of content list.") }
        let ch: Character = self[idx]
        if !peek { advanceIndex(index: &idx, position: &pos) }
        return ch
    }

    @inlinable func advanceIndex(index idx: inout String.Index, position pos: inout DocPosition) {
        pos.update(self[idx])
        formIndex(after: &idx)
    }
}

extension Collection where Element: CustomStringConvertible {
    @inlinable func componentsJoined(by separator: String) -> String {
        var idx = startIndex
        var str: String = ""

        if idx < endIndex {
            str += self[idx].description
            formIndex(after: &idx)

            while idx < endIndex {
                str += separator
                str += self[idx].description
                formIndex(after: &idx)
            }
        }

        return str
    }
}
