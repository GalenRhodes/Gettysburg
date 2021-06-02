/*******************************************************************************************************************************************************************************//*
 *     PROJECT: Gettysburg
 *    FILENAME: SAXCharInputStream.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 6/2/21
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

public protocol SAXCharInputStream: CharInputStream, AnyObject {
    var url:         URL { get }
    var baseURL:     URL { get }
    var filename:    String { get }
    var docPosition: DocPosition { get }
}

open class SAXIConvCharInputStream: IConvCharInputStream, SAXCharInputStream {
    public let            url:         URL
    public let            baseURL:     URL
    public let            filename:    String
    @inlinable public var docPosition: DocPosition { DocPosition(position: position) }

    public init(inputStream: InputStream, url: URL? = nil) throws {
        (self.url, self.baseURL, self.filename) = try GetBaseURLAndFilename(url: url ?? GetFileURL(filename: "temp_\(UUID().uuidString).xml"))
        let _inputStream = ((inputStream as? MarkInputStream) ?? MarkInputStream(inputStream: inputStream, autoClose: true))
        let encodingName = try getEncodingName(inputStream: _inputStream)
        super.init(inputStream: _inputStream, encodingName: encodingName, autoClose: true)
    }
}

open class SAXStringCharInputStream: StringCharInputStream, SAXCharInputStream {
    public let            url:         URL
    public let            baseURL:     URL
    public let            filename:    String
    @inlinable public var docPosition: DocPosition { DocPosition(position: position) }

    public init(string: String, url: URL? = nil) throws {
        (self.url, self.baseURL, self.filename) = try GetBaseURLAndFilename(url: url ?? GetFileURL(filename: "temp_\(UUID().uuidString).xml"))
        super.init(string: string)
    }
}

@frozen public struct DocPosition: Hashable, Comparable, CustomStringConvertible {
    public var            line:        UInt32
    public var            column:      UInt32
    @inlinable public var description: String { "(\(line), \(column)" }

    @inlinable public init(line: UInt32, column: UInt32) {
        self.line = line
        self.column = column
    }

    @inlinable public init(position pos: TextPosition) {
        self.line = UInt32(bitPattern: pos.lineNumber)
        self.column = UInt32(bitPattern: pos.columnNumber)
    }

    @inlinable public func hash(into hasher: inout Hasher) {
        hasher.combine(line)
        hasher.combine(column)
    }

    @inlinable public static func == (lhs: DocPosition, rhs: DocPosition) -> Bool { return lhs.line == rhs.line && lhs.column == rhs.column }

    @inlinable public static func < (lhs: DocPosition, rhs: DocPosition) -> Bool { ((lhs.line < rhs.line) || ((lhs.line == rhs.line) && (lhs.column < rhs.column))) }
}
