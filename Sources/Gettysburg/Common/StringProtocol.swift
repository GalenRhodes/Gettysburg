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

    @inlinable func skipWS(_ idx: inout Self.Index, position pos: inout DocPosition, peek: Bool = false) -> Character? {
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

    @inlinable var asString: String {
        guard let s = (self as? String) else { return String(self) }
        return s
    }

    @usableFromInline func decodeEntities() -> String {
        var out: String     = ""
        var idx: Self.Index = startIndex

        while idx < endIndex {
            let ch = self[idx]
            formIndex(after: &idx)

            if ch == "&" {
                var i1 = idx
                while self[i1] != ";" && i1 < endIndex { formIndex(after: &i1) }

                if idx < endIndex, let rep: Character = StandardEntities1[self[idx ..< i1].asString] {
                    out.append(rep)
                    idx = index(after: i1)
                }
                else {
                    out.append(ch)
                }
            }
            else {
                out.append(ch)
            }
        }

        return out
    }

    @usableFromInline func encodeEntities() -> String {
        var out: String = ""
        for ch in self {
            if let rep = StandardEntities2[ch] { out += rep }
            else { out.append(ch) }
        }
        return out
    }

    @inlinable func surroundedWith(_ s: String) -> String { "\(s)\(self)\(s)" }

    @inlinable func surroundedWith(_ s1: String, _ s2: String) -> String { "\(s1)\(self)\(s2)" }

    @inlinable func quoted(quote: Character = "\"") -> String { "\(quote)\(encodeEntities())\(quote)" }

    /*===========================================================================================================================*/
    /// If this character collection starts and ends with either a single or double quote then those quotes are remove from the
    /// returned string.
    /// 
    /// - Precondition: The starting and ending character must be the same. If, for example, the string is "Robert' then the quotes
    ///                 *are not* removed.
    /// - Returns: A string with the quotes removed.
    ///
    @usableFromInline func unQuoted() -> String {
        guard count > 1 else { return asString }

        let firstChar = self[startIndex]
        let lastIdx = lastIndex

        guard value(firstChar, isOneOf: "\"", "'") && self[lastIdx] == firstChar else { return asString }
        return String(self[index(after: startIndex) ..< lastIdx])
    }

    @inlinable var lastIndex: Self.Index {
        var i = startIndex
        if i < endIndex {
            var j = index(after: i)
            while j < endIndex {
                i = j
                formIndex(after: &j)
            }
        }
        return i
    }

    /*===========================================================================================================================*/
    /// Returns the first character in the collection.
    /// 
    /// - Precondition: There has to be at least one character in the collection of a fatal error will be thrown.
    ///
    @inlinable var firstChar: Character { self[startIndex] }
}

private let StandardEntities1: [String: Character] = [ "amp": "&", "lt": "<", "gt": ">", "apos": "'", "quot": "\"" ]
private let StandardEntities2: [Character: String] = [ "&": "amp", "<": "lt", ">": "gt", "'": "apos", "\"": "quot" ]
