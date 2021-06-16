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

public enum SAXError: Error {
    case MalformedURL(position: TextPosition, description: String)
    case UnexpectedEndOfInput(position: TextPosition, description: String)
    case UnknownEncoding(position: TextPosition, description: String)
    case NoHandler(position: TextPosition, description: String)
    case MalformedDocument(position: TextPosition, description: String)
    case MalformedParameter(position: TextPosition, description: String)
    case MalformedXmlDecl(position: TextPosition, description: String)
    case MalformedComment(position: TextPosition, description: String)
    case MalformedProcInst(position: TextPosition, description: String)
    case MalformedCDATASection(position: TextPosition, description: String)
    case MissingWhitespace(position: TextPosition, description: String)
    case MalformedDocType(position: TextPosition, description: String)

    @inlinable static func getMalformedDocType(_ inputStream: SAXCharInputStream, description: String) -> SAXError {
        return SAXError.MalformedDocType(position: inputStream.position, description: description)
    }

    @inlinable static func getMalformedURL(_ inputStream: SAXCharInputStream, description: String) -> SAXError {
        return SAXError.MalformedURL(position: inputStream.position, description: description)
    }

    @inlinable static func getMalformedURL(description: String) -> SAXError {
        return SAXError.MalformedURL(position: TextPosition(lineNumber: 0, columnNumber: 0), description: description)
    }

    @inlinable static func getUnexpectedEndOfInput(description: String = "Unexpected end-of-input.") -> SAXError {
        return SAXError.UnexpectedEndOfInput(position: TextPosition(lineNumber: 0, columnNumber: 0), description: description)
    }

    @inlinable static func getUnknownEncoding(description: String) -> SAXError {
        return SAXError.UnknownEncoding(position: TextPosition(lineNumber: 0, columnNumber: 0), description: description)
    }

    @inlinable static func getNoHandler(_ inputStream: SAXCharInputStream, description: String) -> SAXError {
        return SAXError.NoHandler(position: inputStream.position, description: description)
    }

    @inlinable static func getMalformedDocument(_ inputStream: SAXCharInputStream, description: String) -> SAXError {
        return SAXError.MalformedDocument(position: inputStream.position, description: description)
    }

    @inlinable static func getMalformedParameter(_ inputStream: SAXCharInputStream, description: String) -> SAXError {
        return SAXError.MalformedParameter(position: inputStream.position, description: description)
    }

    @inlinable static func getMalformedXmlDecl(_ inputStream: SAXCharInputStream, description: String) -> SAXError {
        return SAXError.MalformedXmlDecl(position: inputStream.position, description: description)
    }

    @inlinable static func getMalformedComment(_ inputStream: SAXCharInputStream, description: String) -> SAXError {
        return SAXError.MalformedComment(position: inputStream.position, description: description)
    }

    @inlinable static func getMalformedProcInst(_ inputStream: SAXCharInputStream, description: String) -> SAXError {
        return SAXError.MalformedProcInst(position: inputStream.position, description: description)
    }

    @inlinable static func getMalformedCDATASection(_ inputStream: SAXCharInputStream, description: String) -> SAXError {
        return SAXError.MalformedCDATASection(position: inputStream.position, description: description)
    }

    @inlinable static func getMissingWhitespace(_ inputStream: SAXCharInputStream, description: String = "Whitespace was expected.") -> SAXError {
        return SAXError.MissingWhitespace(position: inputStream.position, description: description)
    }
}
