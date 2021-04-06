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

open class SAXError: Error, CustomStringConvertible {
    public let position:             TextPosition
    public var description:          String { "(\(position.lineNumber), \(position.columnNumber)) - \(_description)" }
    public var localizedDescription: String { description }

    private let _description: String

    public init(_ lineNumber: Int32, _ columnNumber: Int32, description: String) {
        position = (lineNumber, columnNumber)
        _description = description
    }

    public init(_ pos: TextPosition, description: String) {
        position = pos
        _description = description
    }

    public init(_ charStream: CharInputStream, description: String) {
        position = charStream.position
        _description = description
    }

    public class IOError: SAXError {}

    public class InternalError: SAXError { public init(description: String) { super.init(0, 0, description: description) } }

    public class UnexpectedEndOfInput: SAXError {
        public init(_ charStream: CharInputStream) { super.init(charStream, description: EOFMessage) }

        public init(_ pos: TextPosition) { super.init(pos, description: EOFMessage) }

        public init(_ line: Int32, _ column: Int32) { super.init(line, column, description: EOFMessage) }
    }

    public class InvalidCharacter: SAXError {
        public override init(_ chStream: CharInputStream, description: String) { super.init(chStream, description: description) }

        public init(_ pos: TextPosition, found ch: Character, expected chars: [Character]) { super.init(pos, description: buildMessage(ch, chars)) }

        public convenience init(_ pos: TextPosition, found ch: Character, expected chars: Character...) { self.init(pos, found: ch, expected: chars) }

        public convenience init(_ chStream: CharInputStream, found ch: Character, expected chars: Character...) { self.init(chStream.position, found: ch, expected: chars) }

        public convenience init(_ chStream: CharInputStream, found ch: Character, expected chars: [Character]) { self.init(chStream.position, found: ch, expected: chars) }

        public convenience init(_ lineNumber: Int32, _ columnNumber: Int32, found ch: Character, expected chars: Character...) { self.init((lineNumber, columnNumber), found: ch, expected: chars) }

        public convenience init(_ lineNumber: Int32, _ columnNumber: Int32, found ch: Character, expected chars: [Character]) { self.init((lineNumber, columnNumber), found: ch, expected: chars) }

        public class func ws(_ chStream: CharInputStream, found ch: Character) -> SAXError { InvalidCharacter(chStream, description: "Expected a whitespace character but found \"\(ch)\" instead.") }
    }

    public class MalformedURL: SAXError {
        public init(_ url: String) { super.init(0, 0, description: malformedURLMessage(url)) }

        public init(_ charStream: CharInputStream, url: String) { super.init(charStream, description: malformedURLMessage(url)) }

        public init(_ pos: TextPosition, url: String) { super.init(pos, description: malformedURLMessage(url)) }

        public init(_ line: Int32, _ column: Int32, url: String) { super.init(line, column, description: malformedURLMessage(url)) }
    }

    public class MalformedXMLDecl: SAXError {}

    public class MalformedProcessingInstruction: SAXError {}

    public class MalformedDocument: SAXError {}

    public class MalformedDTD: SAXError {}

    public class MissingName: SAXError {}

    public class UnsupportedCharacterEncoding: SAXError {}

    public class EntityError: SAXError {}
}

fileprivate func buildList(_ chars: [Character]) -> String {
    var str = ""
    for i in (chars.startIndex ..< (chars.endIndex - 1)) { str += "\"\(chars[i])\", " }
    str += "or \"\(chars[(chars.endIndex - 1)])\""
    return str
}

fileprivate func buildMessage(_ ch: Character, _ chars: [Character]) -> String {
    if chars.isEmpty { return "Character \"\(ch)\" not expected here." }
    if chars.count == 1 { return "Expected \"\(chars[chars.startIndex])\" but found \"\(ch)\" instead." }
    if chars.count == 2 { return "Expected \"\(chars[chars.startIndex])\" or \"\(chars[chars.startIndex + 1])\" but found \"\(ch)\" instead." }
    return "Expected \(buildList(chars)) but found \"\(ch)\" instead."
}

fileprivate func malformedURLMessage(_ url: String) -> String { "Malformed URL: \"\(url)\"" }

fileprivate let EOFMessage = "Unexpected End-Of-Input"
