/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: ParseRoot.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 2/8/21
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

extension SAXParser {

    /*===========================================================================================================================================================================*/
    /// Parse out the main body of the XML Document that includes the root element and DOCTYPES as well as any processing instructions, whitespace, and comments that might exist
    /// at the root level.
    /// 
    /// - Throws: `SAXError` or any I/O errors.
    ///
    func parseDocumentRoot(_ handler: H) throws {
        markSet()
        defer { markDelete() }

        while let ch = try charStream.read() {
            if ch == "<" {
                markDelete()
                defer { markSet() }
                try parseRootDelimitedNode(handler)
            }
            else if ch.isXmlWhitespace {
                markDelete()
                defer { markSet() }
                try parseWhitespaceNode(handler)
            }
            else {
                markBackup()
                throw SAXError.InvalidCharacter(charStream, description: getBadCharMsg(ch))
            }
            //-----------------------------------------------
            // At this point we don't care what's behind us.
            //-----------------------------------------------
            markUpdate()
        }
    }

    /*===========================================================================================================================================================================*/
    /// Parse a DocType or Comment.
    /// 
    /// - Parameters:
    ///   - handler: The SAX Handler.
    ///   - noDTD: `true` if the DTD has already been parsed or is not allowed at this point.
    /// - Throws: if an I/O error occurs or there is an invalid <code>[Character](https://developer.apple.com/documentation/swift/Character)</code>.
    ///
    fileprivate func parseDocTypeOrComment(_ handler: H) throws {
        markSet()
        defer { markDelete() }
        //-------------------------------------------------------
        // Read the next 8 characters and see what we have here.
        //-------------------------------------------------------
        let str = try readString(count: 8)

        if str.hasPrefix("DOCTYPE") {
            let lastChar = str[str.index(before: str.endIndex)]

            guard lastChar.isXmlWhitespace else {
                markBackup()
                throw SAXError.InvalidCharacter(charStream, description: getBadCharMsg(lastChar))
            }
            guard !(foundDTD || foundRootElement) else {
                markReset()
                throw SAXError.UnexpectedElement(charStream, description: "A DOCTYPE declaration is not expected here.")
            }
            //-------------------------
            // This is a doctype node.
            //-------------------------
            try parseDocType(handler)
            foundDTD = true
        }
        else if str.hasPrefix("--") {
            markBackup(count: 6)
            //-------------------------
            // This is a comment node.
            //-------------------------
            try parseComment(handler)
        }
        else {
            markReset()
            throw SAXError.InvalidCharacter(charStream, description: "Unexpected characters \"\(str)\".")
        }
    }

    /*===========================================================================================================================================================================*/
    /// Parse a delimited node such as an element, comment, processing instruction, or DTD.
    /// 
    /// - Parameters:
    ///   - handler: the handler.
    ///   - noDTD: if set to `true` then DTD nodes are not allowed. DTD nodes are only allowed before the root element is encountered.
    ///   - noElement: if set to `true` then no element nodes are allowed. This might be the case at the document root where only one root element is allowed.
    /// - Throws: if an I/O error occurs, if the node is malformed, or if a DTD was encountered when `noDTD` was set to `true`.
    ///
    fileprivate func parseRootDelimitedNode(_ handler: H) throws {
        let ch = try readChar()
        switch ch {
            case "!": try parseDocTypeOrComment(handler)
            case "?": try parseProcessingInstruction(handler)
            default:
                //------------------------------------------------------
                // It should be an element then in which case the first
                // character should be a valid starting character.
                //------------------------------------------------------
                markBackup()
                if !ch.isXmlNameStartChar { throw SAXError.InvalidCharacter(charStream, description: "Invalid element name starting character: \"\(ch)\"") }
                if foundRootElement { throw SAXError.UnexpectedElement(charStream, description: "An element is not expected here.") }
                try parseElement(handler)
                foundRootElement = true
        }
    }
}
