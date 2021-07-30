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
import Chadakoin

public protocol SAXCharInputStream: SimpleCharInputStream {
    var baseURL:     URL { get }
    var filename:    String { get }
    var docPosition: DocPosition { get }
    var markCount:   Int { get }

    /// Sets a mark point in the input stream.
    ///
    func markSet()

    /// Releases the mark point.
    ///
    func markRelease()

    /// Returns the input stream to the last mark point. If there is no mark point then nothing is done.
    func markReturn()

    /// Effectively the same as calling `markRelease()` followed by `markSet()`.
    ///
    func markUpdate()

    /// Effectively the same as calling `markReturn()` followed by `markSet()`.
    ///
    func markReset()

    /// Returns up to `count` previously read characters from the last mark point to the input stream. Must have called `markSet()` first. If the number of characters
    /// read since `markSet()` was called is less then `count` then this is effectively the same as calling `markReset()`.
    ///
    /// - Parameter count: The number of characters to return to the input stream.
    /// - Returns: The number of characters actually returned to the input stream.
    @discardableResult func markBackup(count: Int) -> Int
}

extension SAXCharInputStream {
    public static func GetCharInputStream(fileAtPath filename: String, tabSize: Int8 = 4) throws -> SAXCharInputStream {
        try SAXIConvCharInputStream(fileAtPath: filename, tabSize: tabSize)
    }

    public static func GetCharInputStream(url: URL, options: URLInputStreamOptions = [], authenticate: AuthenticationCallback? = nil, tabSize: Int8 = 4) throws -> SAXCharInputStream {
        try SAXIConvCharInputStream(url: url, tabSize: tabSize, options: options, authenticate: authenticate)
    }

    public static func GetCharInputStream(data: Data, url: URL? = nil, tabSize: Int8 = 4) throws -> SAXCharInputStream {
        try SAXIConvCharInputStream(data: data, url: url, tabSize: tabSize)
    }

    public static func GetCharInputStream(string: String, url: URL? = nil, tabSize: Int8 = 4) throws -> SAXCharInputStream {
        SAXStringCharInputStream(string: string, url: url, tabSize: tabSize)
    }

    @inlinable @discardableResult public func markBackup() -> Int { markBackup(count: 1) }

    @discardableResult @usableFromInline func append(to chars: inout [Character], until body: (inout [Character]) throws -> SuffixOption?) throws -> Int {
        markSet()
        defer { markRelease() }

        let sIdx = chars.endIndex

        while let ch = try read() {
            chars <+ ch
            if let r = try body(&chars), chars.endIndex > sIdx {
                let cc = (chars.endIndex - sIdx)
                switch r {
                    case .Peek(count: let count):
                        markBackup(count: min(count, cc))
                    case .Keep:
                        break
                    case .Leave(count: let count):
                        markBackup(count: min(count, cc))
                        _ = chars.dropLast(min(count, cc))
                    case .Drop(count: let count):
                        _ = chars.dropLast(min(count, cc))
                }
                return (chars.endIndex - sIdx)
            }

            guard (chars.endIndex - sIdx) < (1024 * 1024) else { throw SAXError.RunawayInput(position: docPosition, description: "Too many characters read before the end condition.") }
        }

        throw SAXError.getUnexpectedEndOfInput()
    }

    @discardableResult @inlinable func read(to chars: inout [Character], until body: (inout [Character]) throws -> SuffixOption?) throws -> Int {
        chars.removeAll(keepingCapacity: true)
        return try append(to: &chars, until: body)
    }

    @inlinable func read(until body: (inout [Character]) throws -> SuffixOption?) throws -> [Character] {
        var chars: [Character] = []
        _ = try append(to: &chars, until: body)
        return chars
    }
}
