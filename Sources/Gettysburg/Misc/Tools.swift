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

@inlinable func == <T: Equatable>(lhs: ArraySlice<T>, rhs: [T]) -> Bool { ((lhs.count == rhs.count) && (lhs == rhs[rhs.startIndex ..< rhs.endIndex])) }

@inlinable func == <T: Equatable>(lhs: [T], rhs: ArraySlice<T>) -> Bool { ((lhs.count == rhs.count) && (lhs[lhs.startIndex ..< lhs.endIndex] == rhs)) }

@inlinable func getCurrDirURL() -> URL { URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true) }

@inlinable func getFileURL(filename: String) -> URL { URL(fileURLWithPath: filename, relativeTo: getCurrDirURL()) }

@inlinable func getURL(string: String) throws -> URL {
    guard let url = URL(string: string, relativeTo: getCurrDirURL()) else { throw SAXError.MalformedURL(string) }
    return url
}

