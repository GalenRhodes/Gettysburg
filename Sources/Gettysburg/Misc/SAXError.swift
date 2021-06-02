/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: SAXError.swift
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

open class SAXError: Error, CustomStringConvertible, Hashable {
    public let position: DocPosition
    public let description: String

    public init(position: DocPosition, description: String) {
        self.position = position
        self.description = description
    }

    public init(position: TextPosition, description: String) {
        self.position = DocPosition(position: position)
        self.description = description
    }

    public convenience init(description: String) { self.init(position: DocPosition(line: 0, column: 0), description: description) }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(position)
        hasher.combine(description)
    }

    public static func == (lhs: SAXError, rhs: SAXError) -> Bool { ((type(of: lhs) == type(of: rhs)) && (lhs.position == rhs.position) && (lhs.description == rhs.description)) }

    public class MalformedURL: SAXError {}

    public class UnexpectedEndOfInput: SAXError {}

    public class UnknownEncoding: SAXError {}
}
