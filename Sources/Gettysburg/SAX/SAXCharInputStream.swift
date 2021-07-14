/*****************************************************************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: SAXCharInputStream.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: July 13, 2021
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
import Rubicon

public protocol SAXCharInputStream {
    var docPosition: DocPosition { get }
}

@frozen public struct DocPosition: Hashable {
    public let url:    URL
    public let line:   Int32
    public let column: Int32

    public init(url: URL? = nil, line: Int32 = 1, column: Int32 = 1) {
        self.url = (url ?? bogusURL())
        self.line = line
        self.column = column
    }

    public init<S: StringProtocol>(url: URL? = nil, startLine: Int32 = 1, startColumn: Int32 = 1, string str: S, range: Range<String.Index>) {
        self.url = (url ?? bogusURL())
        var p = TextPosition(lineNumber: startLine, columnNumber: startColumn)
        for ch in str[range] { textPositionUpdate(ch, pos: &p, tabWidth: 4) }
        (self.line, self.column) = p
    }

    public init<S: StringProtocol>(url: URL? = nil, startLine: Int32 = 1, startColumn: Int32 = 1, string str: S, upTo idx: String.Index) {
        self.init(url: url, startLine: startLine, startColumn: startColumn, string: str, range: (str.startIndex ..< idx))
    }

    public init<S: StringProtocol>(startPosition pos: DocPosition, string str: S, range: Range<String.Index>) {
        self.init(url: pos.url, startLine: pos.line, startColumn: pos.column, string: str, range: range)
    }

    public init<S: StringProtocol>(startPosition pos: DocPosition, string str: S, upTo idx: String.Index) {
        self.init(url: pos.url, startLine: pos.line, startColumn: pos.column, string: str, range: (str.startIndex ..< idx))
    }
}
