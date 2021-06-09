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
    public let position:    DocPosition
    public let description: String

    public init(_ p: DocPosition, description d: String) {
        self.position = p
        self.description = d
    }

    public convenience init(_ p: TextPosition, description d: String) { self.init(DocPosition(position: p), description: d) }

    public convenience init(_ i: SAXCharInputStream, description d: String) { self.init(i.docPosition, description: d) }

    public convenience init(description d: String) { self.init(DocPosition(line: 0, column: 0), description: d) }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(position)
        hasher.combine(description)
    }

    public static func == (lhs: SAXError, rhs: SAXError) -> Bool { ((type(of: lhs) == type(of: rhs)) && (lhs.position == rhs.position) && (lhs.description == rhs.description)) }

    public class MalformedURL: SAXError {}

    public class UnexpectedEndOfInput: SAXError { public convenience init() { self.init(description: "Unexpected End-of-Input.") } }

    public class UnknownEncoding: SAXError {}

    public class NoHandler: SAXError {}

    public class MalformedDocument: SAXError {}

    public class MalformedParameter: SAXError {}

    public class MalformedXmlDecl: SAXError {}

    public class MalformedComment: SAXError {}

    public class MalformedProcessingInstruction: SAXError {}
}
