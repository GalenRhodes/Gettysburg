/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: Text.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 2/18/21
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

extension SAXParser {

    /*===========================================================================================================================================================================*/
    /// Parse and handle a CDATA Section.
    /// 
    /// - Throws: if an I/O error occurs.
    ///
    @inlinable func parseCDATASection() throws {
        _ = try charStream.readChars(mustBe: "<![CDATA[")
        try parseCDATASection(charStream)
    }

    /*===========================================================================================================================================================================*/
    /// Parse and handle a CDATA Section.
    /// 
    /// - Parameter chStream: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code> to read the CDATA section from.
    /// - Throws: if an I/O error occurs.
    ///
    @usableFromInline func parseCDATASection(_ chStream: SAXCharInputStream) throws {
        var cont:   Bool        = false
        var buffer: [Character] = []
        let end:    [Character] = "]]>".getCharacters()
        let ecc:    Int         = end.endIndex

        while let ch = try chStream.read() {
            buffer <+ ch
            let bcc: Int = buffer.endIndex
            let xcc: Int = (bcc - ecc)

            if xcc >= 0 && buffer[xcc ..< bcc] == end {
                if !(cont && (xcc == 0)) { handler.cdataSection(self, content: String(buffer[0 ..< xcc]), continued: cont) }
                return
            }
            else if bcc >= memLimit {
                let r = (0 ..< (bcc - 2))
                handler.cdataSection(self, content: String(buffer[r]), continued: cont)
                buffer.removeSubrange(r)
                cont = true
            }
        }

        throw SAXError.UnexpectedEndOfInput(chStream)
    }

    /*===========================================================================================================================================================================*/
    /// Parse and handle Comment.
    /// 
    /// - Throws: if an I/O error occurs or the comment is malformed.
    ///
    @inlinable func parseComment() throws {
        _ = try charStream.readChars(mustBe: "<!--")
        try parseComment(charStream)
    }

    /*===========================================================================================================================================================================*/
    /// Parse and handle a comment.
    /// 
    /// - Parameter charStream: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    /// - Throws: if there was an I/O error or the comment was malformed.
    ///
    @usableFromInline func parseComment(_ chStream: SAXCharInputStream) throws {
        var buffer: [Character]           = []
        let end:    [Character]           = "-->".getCharacters()
        let ecc:    Int                   = end.endIndex
        let xcc:    Int                   = (ecc - 1)
        let epfx:   ArraySlice<Character> = end[0 ..< xcc]
        var cont:   Bool                  = false

        while let ch = try chStream.read() {
            buffer <+ ch
            let bcc: Int = buffer.endIndex
            let ycc: Int = (bcc - ecc)

            if ycc >= 0 {
                if buffer[ycc ..< bcc] == end {
                    if !(cont && (ycc == 0)) { handler.cdataSection(self, content: String(buffer[0 ..< ycc]), continued: cont) }
                    return
                }
                else if buffer[ycc ..< (bcc - 1)] == epfx {
                    throw SAXError.InvalidCharacter(chStream, found: ch, expected: end[xcc])
                }
            }
            if bcc >= memLimit {
                let r = (0 ..< (bcc - 2))
                handler.cdataSection(self, content: String(buffer[r]), continued: cont)
                buffer.removeSubrange(r)
                cont = true
            }
        }

        throw SAXError.UnexpectedEndOfInput(chStream)
    }
}
