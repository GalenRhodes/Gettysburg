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

    func markSet()

    func markRelease()

    func markReturn()

    func markUpdate()

    func markReset()

    @discardableResult func markBackup(count: Int) -> Int
}

extension SAXCharInputStream {
    public static func GetCharInputStream(fileAtPath filename: String, tabSize: Int8 = 4) throws -> SAXCharInputStream {
        try SAXIConvCharInputStream(fileAtPath: filename, tabSize: tabSize)
    }

    public static func GetCharInputStream(url: URL, options: URLInputStreamOptions = [], authenticate: AuthenticationCallback? = nil, tabSize: Int8 = 4) throws -> SAXCharInputStream {
        try SAXIConvCharInputStream(url: url, options: options, authenticate: authenticate, tabSize: tabSize)
    }

    public static func GetCharInputStream(data: Data, url: URL? = nil, tabSize: Int8 = 4) throws -> SAXCharInputStream {
        try SAXIConvCharInputStream(data: data, url: url, tabSize: tabSize)
    }

    public static func GetCharInputStream(string: String, url: URL? = nil, tabSize: Int8 = 4) throws -> SAXCharInputStream {
        SAXStringCharInputStream(string: string, url: url, tabSize: tabSize)
    }

    @inlinable @discardableResult public func markBackup() -> Int { markBackup(count: 1) }
}


