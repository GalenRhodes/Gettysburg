/*******************************************************************************************************************************************************************************//*
 *     PROJECT: Gettysburg
 *    FILENAME: XMLDeclData.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 6/1/21
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

@frozen public struct XMLDeclData: Hashable, Comparable, CustomStringConvertible {
    public let            version:     String?
    public let            encoding:    String?
    public let            standalone:  Bool?
    @inlinable public var description: String {
        var s: String = "<xml?"
        if let v = version { s.append(" version=\"\(v)\"") }
        if let e = encoding { s.append(" encoding=\"\(e)\"") }
        if let a = standalone { s.append(" standalone=\"\(a)\"") }
        s.append("?>")
        return s
    }

    public init(version: String?, encoding: String?, standalone: Bool?) {
        self.version = version
        self.encoding = encoding
        self.standalone = standalone
    }

    @inlinable public func hash(into hasher: inout Hasher) {
        hasher.combine(version)
        hasher.combine(encoding)
        hasher.combine(standalone)
    }

    @inlinable public static func == (lhs: XMLDeclData, rhs: XMLDeclData) -> Bool { ((lhs.version == rhs.version) && (lhs.encoding == rhs.encoding) && (lhs.standalone == rhs.standalone)) }

    @inlinable public static func < (lhs: XMLDeclData, rhs: XMLDeclData) -> Bool { (lhs.description < rhs.description) }
}
