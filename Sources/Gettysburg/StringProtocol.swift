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

extension StringProtocol {

    @inlinable func splitPrefix() -> SAXName { SAXName(qName: self) }

    @usableFromInline func encodeEntities() -> String {
        var out: String       = ""
        let ins: String       = String(self)
        var idx: String.Index = ins.startIndex

        RegularExpression(pattern: "\\&(\\w+);")?.forEachMatch(in: ins) { m, _, _ in
            guard let m = m, let r = m[1].range else { return }

            out += ins[idx ..< r.lowerBound]
            idx = r.upperBound

            switch ins[r] {
                case "amp":  out += "&"
                case "lt":   out += "<"
                case "gt":   out += ">"
                case "apos": out += "'"
                case "quot": out += "\""
                default:     out += m.subString
            }
        }

        out += ins[idx ..< ins.endIndex]
        return out
    }

    @inlinable func quoted(quote: Character = "\"") -> String { "\(quote)\(encodeEntities())\(quote)" }
}