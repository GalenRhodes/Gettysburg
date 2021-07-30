/*****************************************************************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: DocPosition.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: July 14, 2021
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

@frozen public struct DocPosition: Hashable {
    //@f:0
    public   let url:      URL
    public   var line:     Int32 { position.lineNumber }
    public   var column:   Int32 { position.columnNumber }
    public   let tabSize:  Int8
    internal var position: TextPosition
    //@f:1

    public init(url: URL? = nil, line: Int32 = 1, column: Int32 = 1, tabSize: Int8 = 4) {
        self.url = (url ?? URL.bogusURL())
        self.tabSize = tabSize
        self.position = TextPosition(lineNumber: line, columnNumber: column)
    }

    public init<S: StringProtocol>(url: URL? = nil, startLine: Int32 = 1, startColumn: Int32 = 1, tabSize: Int8 = 4, string str: S, upTo idx: String.Index) {
        self.init(url: url, startLine: startLine, startColumn: startColumn, string: str, range: (str.startIndex ..< idx))
    }

    public init<S: StringProtocol>(url: URL? = nil, startLine line: Int32 = 1, startColumn column: Int32 = 1, tabSize: Int8 = 4, string str: S, range: Range<String.Index>) {
        self.url = (url ?? URL.bogusURL())
        self.tabSize = tabSize
        self.position = TextPosition(lineNumber: line, columnNumber: column)
        for ch in str[range] { textPositionUpdate(ch, pos: &position, tabWidth: tabSize) }
    }

    public init<S: StringProtocol>(startPosition pos: DocPosition, string str: S, upTo idx: String.Index) {
        self.init(startPosition: pos, string: str, range: (str.startIndex ..< idx))
    }

    public init<S: StringProtocol>(startPosition pos: DocPosition, string str: S, range: Range<String.Index>) {
        self.url = pos.url
        self.tabSize = pos.tabSize
        self.position = pos.position
        for ch in str[range] { textPositionUpdate(ch, pos: &self.position, tabWidth: pos.tabSize) }
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(url)
        hasher.combine(tabSize)
        hasher.combine(position.lineNumber)
        hasher.combine(position.columnNumber)
    }

    public static func == (lhs: DocPosition, rhs: DocPosition) -> Bool {
        (lhs.url == rhs.url) && (lhs.tabSize == rhs.tabSize) && (lhs.position == rhs.position)
    }

    @discardableResult mutating func update(_ char: Character) -> DocPosition {
        textPositionUpdate(char, pos: &position, tabWidth: tabSize)
        return self
    }

    @discardableResult mutating func update<C>(_ collection: C) -> DocPosition where C: Collection, C.Element == Character {
        for char: Character in collection {
            textPositionUpdate(char, pos: &position, tabWidth: tabSize)
        }
        return self
    }

    @discardableResult mutating func update<S: StringProtocol>(_ str: S) -> DocPosition {
        for char: Character in str {
            textPositionUpdate(char, pos: &position, tabWidth: tabSize)
        }
        return self
    }
}
