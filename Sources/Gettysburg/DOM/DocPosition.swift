/*******************************************************************************************************************************************************************************//*
 *     PROJECT: Gettysburg
 *    FILENAME: DocPosition.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 6/22/21
 *
 * Copyright © 2021 Galen Rhodes. All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software for any purpose with or without fee is hereby granted, provided that the above copyright notice and this
 * permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO
 * EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN
 * AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *//******************************************************************************************************************************************************************************/

import Foundation
import CoreFoundation
import Rubicon

public protocol DocPosition: CustomStringConvertible, AnyObject {
    var line:     UInt32 { get set }
    var column:   UInt32 { get set }
    var url:      URL { get }
    var filename: String { get }
    /*===========================================================================================================================================================================*/
    /// The position within the document.
    ///
    var position: TextPosition { get set }

    func positionUpdate(_ ch: Character)

    func mutableCopy() -> DocPosition
}

extension DocPosition {
    @inlinable public func positionUpdate(_ ch: Character) { textPositionUpdate(ch, pos: &position, tabWidth: 4) }

    @inlinable public func mutableCopy() -> DocPosition { ((self as? StringPosition) ?? StringPosition(pos: self)) }
}

public class StringPosition: DocPosition, Hashable {
    public var line:   UInt32 = 0
    public var column: UInt32 = 0
    public let url:    URL

    @inlinable public var filename:    String { url.lastPathComponent }
    @inlinable public var description: String { "(\(line), \(column)" }

    public var position: TextPosition {
        get { TextPosition(lineNumber: Int32(bitPattern: line), columnNumber: Int32(bitPattern: column)) }
        set { line = UInt32(bitPattern: newValue.lineNumber); column = UInt32(bitPattern: newValue.columnNumber) }
    }

    public init() {
        self.url = GetCurrDirURL()
        self.line = 0
        self.column = 0
    }

    public init(pos: DocPosition) {
        self.url = pos.url
        self.line = pos.line
        self.column = pos.column
    }

    public init(url: URL, line: UInt32, column: UInt32) {
        self.url = url
        self.line = line
        self.column = column
    }

    public init(url: URL, position pos: TextPosition) {
        self.url = url
        self.line = UInt32(bitPattern: pos.lineNumber)
        self.column = UInt32(bitPattern: pos.columnNumber)
    }

    @inlinable public func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }

    @inlinable public static func == (lhs: StringPosition, rhs: StringPosition) -> Bool { lhs.url == rhs.url && lhs.line == rhs.line && lhs.column == rhs.column }
}

public class StreamPosition: DocPosition, Hashable {
    //@f:0
    @inlinable public var line:        UInt32       { get { UInt32(bitPattern: inputStream?.position.lineNumber ?? 0) } set {} }
    @inlinable public var column:      UInt32       { get { UInt32(bitPattern: inputStream?.position.columnNumber ?? 0) } set {} }
    @inlinable public var url:         URL          { inputStream?.url ?? GetCurrDirURL() }
    @inlinable public var filename:    String       { inputStream?.filename ?? "" }
    @inlinable public var description: String       { "(\(line), \(column)" }
    @inlinable public var position:    TextPosition { get { inputStream?.position ?? TextPosition(lineNumber: 0, columnNumber: 0) } set {} }

    @usableFromInline let inputStream: SAXCharInputStream?
    //@f:1

    @inlinable public init() { self.inputStream = nil }

    @inlinable public init(inputStream: SAXCharInputStream) { self.inputStream = inputStream }

    @inlinable public func hash(into hasher: inout Hasher) {
        hasher.combine(inputStream?.url)
    }

    @inlinable public static func == (lhs: StreamPosition, rhs: StreamPosition) -> Bool { lhs.inputStream === rhs.inputStream }
}
