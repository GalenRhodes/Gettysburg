/*******************************************************************************************************************************************************************************//*
 *     PROJECT: Gettysburg
 *    FILENAME: KVPair.swift
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

@frozen public struct KVPair: Hashable, CustomStringConvertible, Comparable {
    public let            key:         String
    public let            value:       String
    @inlinable public var description: String { "(\"\(key)\", \"(value)\"" }

    public init(key: String, value: String) {
        self.key = key
        self.value = value
    }

    @inlinable public func hash(into hasher: inout Hasher) {
        hasher.combine(key)
        hasher.combine(value)
    }

    @inlinable public static func == (lhs: KVPair, rhs: KVPair) -> Bool { ((lhs.key == rhs.key) && (lhs.value == rhs.value)) }

    @inlinable public static func < (lhs: KVPair, rhs: KVPair) -> Bool { ((lhs.key < rhs.key) || ((lhs.key == rhs.key) && (lhs.value < rhs.value))) }
}
