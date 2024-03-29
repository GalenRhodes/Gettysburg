/*===============================================================================================================================================================================*
 *     PROJECT: Gettysburg
 *    FILENAME: SimpleIConvCharInputStream.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 9/11/21
 *
 * Copyright © 2021. All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software for any purpose with or without fee is hereby granted, provided that the above copyright notice and this
 * permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO
 * EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN
 * AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *===============================================================================================================================================================================*/

import Foundation
import CoreFoundation
import Rubicon

public class SAXError: Error, Codable, CustomStringConvertible {
    private enum CodingKeys: String, CodingKey { case docPosition, description }

    public let description: String
    public let docPosition: DocPosition

    public init(position: DocPosition, description: String) {
        self.docPosition = position
        self.description = description
    }

    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        description = try container.decode(String.self, forKey: .description)
        docPosition = try container.decode(DocPosition.self, forKey: .docPosition)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(description, forKey: .description)
        try container.encode(docPosition, forKey: .docPosition)
    }

    //@f:0
    public final class RunawayInput: SAXError {
        public init(position p: DocPosition) { super.init(position: p, description: "Runaway Input") }
        required public init(from decoder: Decoder) throws { try super.init(from: decoder) }
    }
    public final class UnexpectedEndOfInput: SAXError {
        public init() { super.init(position: DocPosition(), description: "Unexpected End of Input") }
        public init(position p: DocPosition) { super.init(position: p, description: "Unexpected End of Input") }
        required public init(from decoder: Decoder) throws { try super.init(from: decoder) }
    }
    public final class MalformedXmlDecl: SAXError {
        public override init(position: DocPosition, description: String) { super.init(position: position, description: description) }
        required public init(from decoder: Decoder) throws { try super.init(from: decoder) }
    }
    public final class MalformedElementDecl: SAXError {
        public override init(position: DocPosition, description: String) { super.init(position: position, description: description) }
        required public init(from decoder: Decoder) throws { try super.init(from: decoder) }
    }
    //@f:1
}

@inlinable func errorMessage(prefix p: String, found f: Character, expected e: Character...) -> String { errorMessage(prefix: p, found: f, expected: e) }

@inlinable func errorMessage(prefix p: String, found f: Character, expected e: [Character]) -> String { errorMessage(prefix: p, found: "\(f)", expected: e.map({ (c) -> String in "\(c)" })) }

@inlinable func errorMessage(prefix: String, found: String, expected: String...) -> String { errorMessage(prefix: prefix, found: found, expected: expected) }

@usableFromInline func errorMessage(prefix p: String, found f: String, expected e: [String]) -> String {
    var msg: String = p

    if e.count == 0 {
        msg += ": \"\(f)\""
    }
    else if e.count == 1 {
        msg += ". Expected \"\(e[0])\" but found \"\(f)\" insteaad."
    }
    else {
        let j = (e.endIndex - 1)

        msg += ". Expected "
        for i in (e.startIndex ..< j) {
            msg += "\"\(e[i])\", "
        }
        msg += "or \"\(e[j])\" but found \"\(f)\" insteaad."
    }

    return msg
}
