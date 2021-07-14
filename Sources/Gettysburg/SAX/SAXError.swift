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

public enum SAXErrorSelect {
    case FileNotFound
    case IllegalCharacter
    case InternalStateError
    case MalformedAttListDecl
    case MalformedCDATASection
    case MalformedComment
    case MalformedDocType
    case MalformedDocument
    case MalformedElement
    case MalformedElementDecl
    case MalformedEntityDecl
    case MalformedEntityRef
    case MalformedNotationDecl
    case MalformedParameter
    case MalformedProcInst
    case MalformedURL
    case MalformedXmlDecl
    case MissingWhitespace
    case NoHandler
    case UnexpectedEndOfInput
    case UnknownEncoding
}

public enum SAXError: Error {
    case FileNotFound(position: DocPosition, description: String)
    case IllegalCharacter(position: DocPosition, description: String)
    case InternalStateError(description: String)
    case MalformedAttListDecl(position: DocPosition, description: String)
    case MalformedCDATASection(position: DocPosition, description: String)
    case MalformedComment(position: DocPosition, description: String)
    case MalformedDocType(position: DocPosition, description: String)
    case MalformedDocument(position: DocPosition, description: String)
    case MalformedElement(position: DocPosition, description: String)
    case MalformedElementDecl(position: DocPosition, description: String)
    case MalformedEntityDecl(position: DocPosition, description: String)
    case MalformedEntityRef(position: DocPosition, description: String)
    case MalformedNotationDecl(position: DocPosition, description: String)
    case MalformedParameter(position: DocPosition, description: String)
    case MalformedProcInst(position: DocPosition, description: String)
    case MalformedURL(position: DocPosition, description: String)
    case MalformedXmlDecl(position: DocPosition, description: String)
    case MissingWhitespace(position: DocPosition, description: String)
    case NoHandler(position: DocPosition, description: String)
    case UnexpectedEndOfInput(position: DocPosition, description: String)
    case UnknownEncoding(position: DocPosition, description: String)

    @inlinable static func get(_ selector: SAXErrorSelect, inputStream: SAXCharInputStream, description: String) -> SAXError {
        switch selector {
            case .MalformedURL: return SAXError.MalformedURL(position: inputStream.docPosition, description: description)
            case .UnexpectedEndOfInput: return SAXError.UnexpectedEndOfInput(position: inputStream.docPosition, description: description)
            case .UnknownEncoding: return SAXError.UnknownEncoding(position: inputStream.docPosition, description: description)
            case .NoHandler: return SAXError.NoHandler(position: inputStream.docPosition, description: description)
            case .MalformedDocument: return SAXError.MalformedDocument(position: inputStream.docPosition, description: description)
            case .MalformedParameter: return SAXError.MalformedParameter(position: inputStream.docPosition, description: description)
            case .MalformedXmlDecl: return SAXError.MalformedXmlDecl(position: inputStream.docPosition, description: description)
            case .MalformedComment: return SAXError.MalformedComment(position: inputStream.docPosition, description: description)
            case .MalformedProcInst: return SAXError.MalformedProcInst(position: inputStream.docPosition, description: description)
            case .MalformedCDATASection: return SAXError.MalformedCDATASection(position: inputStream.docPosition, description: description)
            case .MissingWhitespace: return SAXError.MissingWhitespace(position: inputStream.docPosition, description: description)
            case .MalformedDocType: return SAXError.MalformedDocType(position: inputStream.docPosition, description: description)
            case .MalformedNotationDecl: return SAXError.MalformedNotationDecl(position: inputStream.docPosition, description: description)
            case .MalformedElementDecl: return SAXError.MalformedElementDecl(position: inputStream.docPosition, description: description)
            case .MalformedAttListDecl: return SAXError.MalformedAttListDecl(position: inputStream.docPosition, description: description)
            case .MalformedEntityDecl: return SAXError.MalformedEntityDecl(position: inputStream.docPosition, description: description)
            case .FileNotFound: return SAXError.FileNotFound(position: inputStream.docPosition, description: description)
            case .InternalStateError: return SAXError.InternalStateError(description: description)
            case .MalformedElement: return SAXError.MalformedElement(position: inputStream.docPosition, description: description)
            case .MalformedEntityRef: return SAXError.MalformedEntityRef(position: inputStream.docPosition, description: description)
            case .IllegalCharacter: return SAXError.IllegalCharacter(position: inputStream.docPosition, description: description)
        }
    }

    @inlinable static func getIllegalCharacter(_ inputStream: SAXCharInputStream, message msg: String, expected c1: Character..., got c2: Character) -> SAXError {
        SAXError.IllegalCharacter(position: inputStream.docPosition, description: ExpMsg(msg, expected: c1, got: c2))
    }

    @inlinable static func getMalformedEntityRef(_ inputStream: SAXCharInputStream, description: String) -> SAXError {
        SAXError.MalformedEntityRef(position: inputStream.docPosition, description: description)
    }

    @inlinable static func getMalformedElement(_ inputStream: SAXCharInputStream, description: String) -> SAXError {
        SAXError.MalformedElement(position: inputStream.docPosition, description: description)
    }

    @inlinable static func getFileNotFound(_ inputStream: SAXCharInputStream, description: String) -> SAXError {
        SAXError.FileNotFound(position: inputStream.docPosition, description: description)
    }

    @inlinable static func getMalformedNotationDecl(_ inputStream: SAXCharInputStream, description: String) -> SAXError {
        SAXError.MalformedNotationDecl(position: inputStream.docPosition, description: description)
    }

    @inlinable static func getMalformedElementDecl(_ inputStream: SAXCharInputStream, description: String) -> SAXError {
        SAXError.MalformedElementDecl(position: inputStream.docPosition, description: description)
    }

    @inlinable static func getMalformedAttListDecl(_ inputStream: SAXCharInputStream, description: String) -> SAXError {
        SAXError.MalformedAttListDecl(position: inputStream.docPosition, description: description)
    }

    @inlinable static func getMalformedEntityDecl(_ inputStream: SAXCharInputStream, description: String) -> SAXError {
        SAXError.MalformedEntityDecl(position: inputStream.docPosition, description: description)
    }

    @inlinable static func getMalformedDocType(_ inputStream: SAXCharInputStream, description: String) -> SAXError {
        SAXError.MalformedDocType(position: inputStream.docPosition, description: description)
    }

    @inlinable static func getMalformedURL(_ inputStream: SAXCharInputStream, description: String) -> SAXError {
        SAXError.MalformedURL(position: inputStream.docPosition, description: description)
    }

    @inlinable static func getMalformedURL(description: String) -> SAXError {
        SAXError.MalformedURL(position: DocPosition(url: URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true), line: 0, column: 0), description: description)
    }

    @inlinable static func getUnexpectedEndOfInput(description: String = ERRMSG_EOF) -> SAXError {
        SAXError.UnexpectedEndOfInput(position: DocPosition(url: URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true), line: 0, column: 0), description: description)
    }

    @inlinable static func getUnknownEncoding(description: String) -> SAXError {
        SAXError.UnknownEncoding(position: DocPosition(url: URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true), line: 0, column: 0), description: description)
    }

    @inlinable static func getNoHandler(_ inputStream: SAXCharInputStream, description: String) -> SAXError {
        SAXError.NoHandler(position: inputStream.docPosition, description: description)
    }

    @inlinable static func getMalformedDocument(_ inputStream: SAXCharInputStream, description: String) -> SAXError {
        SAXError.MalformedDocument(position: inputStream.docPosition, description: description)
    }

    @inlinable static func getMalformedParameter(_ inputStream: SAXCharInputStream, description: String) -> SAXError {
        SAXError.MalformedParameter(position: inputStream.docPosition, description: description)
    }

    @inlinable static func getMalformedXmlDecl(_ inputStream: SAXCharInputStream, description: String) -> SAXError {
        SAXError.MalformedXmlDecl(position: inputStream.docPosition, description: description)
    }

    @inlinable static func getMalformedComment(_ inputStream: SAXCharInputStream, description: String) -> SAXError {
        SAXError.MalformedComment(position: inputStream.docPosition, description: description)
    }

    @inlinable static func getMalformedProcInst(_ inputStream: SAXCharInputStream, description: String) -> SAXError {
        SAXError.MalformedProcInst(position: inputStream.docPosition, description: description)
    }

    @inlinable static func getMalformedCDATASection(_ inputStream: SAXCharInputStream, description: String) -> SAXError {
        SAXError.MalformedCDATASection(position: inputStream.docPosition, description: description)
    }

    @inlinable static func getMissingWhitespace(_ inputStream: SAXCharInputStream, description: String = "Whitespace was expected.") -> SAXError {
        SAXError.MissingWhitespace(position: inputStream.docPosition, description: description)
    }
}

@inlinable func ExpMsg(_ msg: String = "Unexpected character", expected c1: Character..., got c2: Character) -> String { ExpMsg(msg, expected: c1, got: c2) }

@inlinable func ExpMsg(_ msg: String = "Unexpected character", expected c1: [Character], got c2: Character) -> String {
    switch c1.count {
        case 0: return "\(msg): \"\(c2)\""
        case 1: return "\(msg) - expected \"\(c1[0])\" but got \"\(c2)\" instead."
        case 2: return "\(msg) - expected \"\(c1[0])\" or \"\(c1[1])\" but got \"\(c2)\" instead."
        default:
            var out = "\(msg) - expected "
            for ch in c1[0 ..< (c1.endIndex - 1)] { out += "\"\(ch)\", " }
            return " or \"\(c1[c1.endIndex - 1])\" but got \"\(c2)\" instead."
    }
}

public let ERRMSG_EOF: String = "Unexpected End-of-Input"
