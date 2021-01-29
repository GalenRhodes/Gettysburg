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

public enum SAXError: Error {
    case MissingHandler(_ line: Int = 0, _ column: Int = 0, description: String = "The SAX parsing handler was not set before the parsing began.")
    case HandlerAlreadySet(_ line: Int = 0, _ column: Int = 0, description: String = "The SAX parsing handler was already set.")
    case InvalidXMLVersion(_ line: Int = 1, _ column: Int = 1, description: String = "Invalid XML version in the XML declaration. Valid values are \"1.0\" and \"1.1\".")
    case InvalidFileEncoding(_ line: Int = 1, _ column: Int = 1, description: String = "Invalid XML file encoding.")
    case InvalidXMLDeclaration(_ line: Int = 1, _ column: Int = 1, description: String = "The XML declaration was invalid.")
    case UnexpectedEndOfInput(_ line: Int, _ column: Int, description: String = "The end-of-input was reached before it was expected.")
    case InvalidCharacter(_ line: Int, _ column: Int, description: String)
    case UnexpectedElement(_ line: Int, _ column: Int, description: String)
}
