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
    public let  lineNumber:           Int
    public let  columnNumber:         Int
    public var  description:          String { "(\(lineNumber), \(columnNumber)) - \(_description)" }
    public var  localizedDescription: String { description }
    private let _description:         String

    public init(_ lineNumber: Int, _ columnNumber: Int, description: String) {
        self.lineNumber = lineNumber
        self.columnNumber = columnNumber
        self._description = description
    }

    public init(_ charStream: CharInputStream, description: String) {
        lineNumber = charStream.lineNumber
        columnNumber = charStream.columnNumber
        _description = description
    }

    public class UnexpectedEndOfInput: SAXError { public init(_ charStream: CharInputStream) { super.init(charStream, description: "Unexpected End-Of-Input") } }

    public class InvalidCharacter: SAXError {
        public convenience init(_ charStream: CharInputStream, found ch: Character, expected chars: Character...) { self.init(charStream, found: ch, expected: chars) }

        public override init(_ charStream: CharInputStream, description: String) { super.init(charStream, description: description) }

        public init(_ charStream: CharInputStream, found ch: Character, expected chars: [Character]) {
            if chars.count <= 0 {
                super.init(charStream, description: "Character \"\(ch)\" not expected here.")
            }
            else {
                let sIdx = chars.startIndex
                if chars.count == 1 {
                    super.init(charStream, description: "Expected \"\(chars[sIdx])\" but found \"\(ch)\" instead.")
                }
                else if chars.count == 2 {
                    super.init(charStream, description: "Expected \"\(chars[sIdx])\" or \"\(chars[sIdx + 1])\" but found \"\(ch)\" instead.")
                }
                else {
                    let eIdx = (chars.endIndex - 1)
                    var str  = ""
                    for i in (sIdx ..< eIdx) { str += "\"\(chars[i])\", " }
                    super.init(charStream, description: "Expected \(str), or \"\(chars[eIdx])\" but found \"\(ch)\" instead.")
                }
            }
        }

        public class func ws(_ charStream: CharInputStream, found ch: Character) -> SAXError { InvalidCharacter(charStream, description: "Expected a whitespace character but found \"\(ch)\" instead.") }
    }

    public class UnsupportedCharacterEncoding: SAXError {}

    public class MalformedURL: SAXError {
        public init(_ url: String) { super.init(0, 0, description: "Malformed URL: \"\(url)\"") }

        public init(_ charStream: CharInputStream, url: String) { super.init(charStream, description: "Malformed URL: \"\(url)\"") }
    }

    public class MalformedXMLDecl: SAXError {}

    public class IOError: SAXError {}

    public class MalformedProcessingInstruction: SAXError {}

    public class MalformedDocument: SAXError {}

    public class MissingName: SAXError {}

    public class MalformedDTD: SAXError {}
}
