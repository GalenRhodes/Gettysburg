/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: Tools.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 2/16/21
 *
 * Copyright © 2021 Galen Rhodes. All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *//************************************************************************/

import Foundation
import CoreFoundation
import Rubicon

@inlinable func tabCalc(pos i: Int, tabSize sz: Int = 4) -> Int { (((((i - 1) + sz) / sz) * sz) + 1) }

@inlinable func == <T: Equatable>(lhs: ArraySlice<T>, rhs: [T]) -> Bool { ((lhs.count == rhs.count) && (lhs == rhs[rhs.startIndex ..< rhs.endIndex])) }

@inlinable func == <T: Equatable>(lhs: [T], rhs: ArraySlice<T>) -> Bool { ((lhs.count == rhs.count) && (lhs[lhs.startIndex ..< lhs.endIndex] == rhs)) }

@inlinable func getCurrDirURL() -> URL { URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true) }

@inlinable func getFileURL(filename: String) -> URL { URL(fileURLWithPath: filename, relativeTo: getCurrDirURL()) }

@inlinable func getURL(string: String) throws -> URL {
    guard let url = URL(string: string, relativeTo: getCurrDirURL()) else { throw SAXError.MalformedURL(string) }
    return url
}

@inlinable func printArray(_ strings: [String?]) {
    var idx = 0
    for s in strings {
        if let s = s {
            print("\(idx++)> \"\(s)\"")
        }
        else {
            print("\(idx++)> NIL")
        }
    }
}

@inlinable func getSubStringAndPos(_ string: String, range: Range<String.Index>, position pos: (Int, Int), charStream chStream: SAXCharInputStream) -> (String, (Int, Int)) {
    (String(string[range.lowerBound ..< range.upperBound]), string.positionOfIndex(range.lowerBound, startingLine: pos.0, startingColumn: pos.1, tabSize: chStream.tabWidth))
}

@inlinable func regexError(_ err: Error?) -> Error { err ?? SAXError.InternalError(description: "Malformed regex pattern.") }

extension SAXParser {

    @inlinable func getCharStreamFor(systemId: String) throws -> SAXCharInputStream { try getCharStreamFor(systemId: systemId, sourceCharStream: charStream) }

    @inlinable func getCharStreamFor(systemId: String, sourceCharStream chStream: SAXCharInputStream) throws -> SAXCharInputStream {
        let url = try getParserURL(string: systemId)
        guard let inStream = MarkInputStream(url: url) else { throw SAXError.IOError(chStream, description: "Failed to open URL \"\(systemId)\".") }
        return try skipOverXmlDeclaration(try SAXCharInputStream(inputStream: inStream, url: url))
    }

    @inlinable func getCharStreamFor(inputStream: InputStream, systemId: String) throws -> SAXCharInputStream {
        let url = try getParserURL(string: systemId)
        return try skipOverXmlDeclaration(try SAXCharInputStream(inputStream: MarkInputStream(inputStream: inputStream), url: url))
    }

    @inlinable func skipOverXmlDeclaration(_ chStream: SAXCharInputStream) throws -> SAXCharInputStream {
        chStream.open()
        chStream.markSet()
        defer { chStream.markReturn() }

        let str = try chStream.readString(count: 6)

        if try str.matches(pattern: "\\A\\<\\?(?i)xml\\s") {
            var lch: Character = " "

            while let ch = try chStream.read() {
                if ch == ">" && lch == "?" {
                    chStream.markUpdate()
                    return chStream
                }
                lch = ch
            }

            throw SAXError.UnexpectedEndOfInput(chStream)
        }

        return chStream
    }

    @inlinable func getParserURL(string: String) throws -> URL {
        guard let url = URL(string: string, relativeTo: baseURL) else { throw SAXError.MalformedURL(charStream, url: string) }
        return url
    }
}
