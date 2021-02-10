/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: SAXError.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 1/15/21
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
#if os(Windows)
    import WinSDK
#endif

public let DEF_MISSING_HANDLER      = "The SAX parsing handler was not set before the parsing began."
public let DEF_INVALID_XML_VER      = "Invalid XML version in the XML declaration. Valid values are \"1.0\" and \"1.1\"."
public let DEF_HANDLER_ALREADY_SET  = "The SAX parsing handler was already set."
public let DEF_INVALID_XML_ENCODING = "Invalid XML file encoding."
public let DEF_INVALID_XML_DECL     = "The XML declaration was invalid."
public let DEF_END_OF_INPUT         = "The end-of-input was reached before it was expected."

public class SAXError: Error, CustomStringConvertible {
    public let line:                 Int
    public let column:               Int
    public let description:          String
    public var localizedDescription: String { description }

    public init(_ line: Int, _ column: Int, description: String) {
        self.line = line
        self.column = column
        self.description = description
    }

    public init(_ chStream: CharInputStream, description: String) {
        line = chStream.lineNumber
        column = chStream.columnNumber
        self.description = description
    }

    public class MissingHandler: SAXError {
        public override init(_ chStream: CharInputStream, description desc: String = DEF_MISSING_HANDLER) { super.init(chStream, description: desc) }

        public override init(_ line: Int = 0, _ column: Int = 0, description: String = DEF_MISSING_HANDLER) { super.init(line, column, description: description) }
    }

    public class InvalidXMLVersion: SAXError {
        public override init(_ chStream: CharInputStream, description desc: String = DEF_INVALID_XML_VER) { super.init(chStream, description: desc) }

        public override init(_ line: Int = 1, _ column: Int = 1, description: String = DEF_INVALID_XML_VER) { super.init(line, column, description: description) }
    }

    public class HandlerAlreadySet: SAXError {
        public override init(_ chStream: CharInputStream, description desc: String = DEF_HANDLER_ALREADY_SET) { super.init(chStream, description: desc) }

        public override init(_ line: Int = 0, _ column: Int = 0, description: String = DEF_HANDLER_ALREADY_SET) { super.init(line, column, description: description) }
    }

    public class InvalidFileEncoding: SAXError {
        public override init(_ chStream: CharInputStream, description desc: String = DEF_INVALID_XML_ENCODING) { super.init(chStream, description: desc) }

        public override init(_ line: Int = 1, _ column: Int = 1, description: String = DEF_INVALID_XML_ENCODING) { super.init(line, column, description: description) }
    }

    public class InvalidXMLDeclaration: SAXError {
        public override init(_ chStream: CharInputStream, description desc: String = DEF_INVALID_XML_DECL) { super.init(chStream, description: desc) }

        public override init(_ line: Int = 1, _ column: Int = 1, description: String = DEF_INVALID_XML_DECL) { super.init(line, column, description: description) }
    }

    public class UnexpectedEndOfInput: SAXError {
        public override init(_ chStream: CharInputStream, description desc: String = DEF_END_OF_INPUT) { super.init(chStream, description: desc) }

        public override init(_ line: Int, _ column: Int, description: String = DEF_END_OF_INPUT) { super.init(line, column, description: description) }
    }

    public class InvalidCharacter: SAXError {}

    public class UnexpectedElement: SAXError {}

    public class MalformedNumber: SAXError {}

    public class NamespaceError: SAXError {}

    public class DuplicateAttribute: SAXError {}

    public class InvalidEntityReference: SAXError {}

    public class MalformedDTD: SAXError {}
}

extension SAXParser {
    /*===========================================================================================================================================================================*/
    /// Returns a message about a bad character.
    /// 
    /// - Parameter ch: the character.
    /// - Returns: the message
    ///
    @inlinable final func getBadCharMsg(_ ch: Character) -> String { "Character not allowed here: \"\(ch)\"" }

    /*===========================================================================================================================================================================*/
    /// Returns a message about a bad character.
    /// 
    /// - Parameters:
    ///   - ch1: the expected character.
    ///   - ch2: the character we got.
    /// - Returns: the message.
    ///
    @inlinable final func getBadCharMsg2(expected ch1: Character, found ch2: Character) -> String { "Expected \"\(ch1)\" but found \"\(ch2)\" instead." }

    /*===========================================================================================================================================================================*/
    /// Returns a message about a bad character.
    /// 
    /// - Parameters:
    ///   - ch1: the expected characters.
    ///   - ch2: the character we got.
    /// - Returns: the message.
    ///
    @inlinable final func getBadCharMsg3(expected ch1: Character..., found ch2: Character) -> String {
        guard ch1.count > 0 else { return getBadCharMsg(ch2) }
        guard ch1.count > 1 else { return getBadCharMsg2(expected: ch1[0], found: ch2) }

        var msg:  String = ""
        let eIdx: Int    = (ch1.endIndex - 1)
        for x in (ch1.startIndex ..< eIdx) { msg += "\"\(ch1[x])\", " }
        msg += "or \"\(ch1[eIdx])\""
        return "Expected one of \(msg) but found \"\(ch2)\" instead."
    }

    /*===========================================================================================================================================================================*/
    /// Returns a message about a bad character.
    /// 
    /// - Parameters:
    ///   - ch1: the expected characters.
    ///   - ch2: the character we got.
    /// - Returns: the message.
    ///
    @inlinable final func getBadCharMsg3(expected ch1: [Character], found ch2: Character) -> String {
        guard ch1.count > 0 else { return getBadCharMsg(ch2) }
        guard ch1.count > 1 else { return getBadCharMsg2(expected: ch1[0], found: ch2) }

        var msg:  String = ""
        let eIdx: Int    = (ch1.endIndex - 1)
        for x in (ch1.startIndex ..< eIdx) { msg += "\"\(ch1[x])\", " }
        msg += "or \"\(ch1[eIdx])\""
        return "Expected one of \(msg) but found \"\(ch2)\" instead."
    }
}
