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
    /// - Parameter chStream: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code> to read the CDATA section from.
    /// - Throws: if an I/O error occurs.
    ///
    func parseCDATASection(_ chStream: SAXCharInputStream) throws {
        _ = try chStream.readChars(mustBe: "<![CDATA[")
        try parseCDATASectionBody(chStream)
    }

    /*===========================================================================================================================================================================*/
    /// Parse and handle a CDATA Section body.
    /// 
    /// - Parameter chStream: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code> to read the CDATA section from.
    /// - Throws: if an I/O error occurs.
    ///
    func parseCDATASectionBody(_ chStream: SAXCharInputStream) throws {
        var buffer: [Character] = []
        var l1:     Character?  = nil
        var l2:     Character?  = nil
        var cont:   Bool        = false

        while let ch = try chStream.read() {
            if l1 == "]" && l2 == "]" && ch == ">" {
                if buffer.count > 2 || !cont {
                    buffer.removeLast(2)
                    handler.cdataSection(self, content: String(buffer), continued: cont)
                }
                return
            }

            buffer <+ ch
            l1 = l2
            l2 = ch
            let bcc = buffer.count

            if bcc > memLimit {
                let r = (0 ..< (bcc - 2))
                handler.cdataSection(self, content: String(buffer[r]), continued: cont)
                cont = true
                buffer.removeSubrange(r)
            }
        }

        throw SAXError.UnexpectedEndOfInput(chStream)
    }

    /*===========================================================================================================================================================================*/
    /// Parse and handle a comment.
    /// 
    /// - Parameter charStream: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    /// - Throws: if there was an I/O error or the comment was malformed.
    ///
    func parseComment(_ chStream: SAXCharInputStream) throws {
        _ = try chStream.readChars(mustBe: "<!--")
        try parseCommentBody(chStream)
    }

    /*===========================================================================================================================================================================*/
    /// Parse and handle a comment body.
    /// 
    /// - Parameter charStream: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    /// - Throws: if there was an I/O error or the comment was malformed.
    ///
    func parseCommentBody(_ chStream: SAXCharInputStream) throws {
        var buffer: [Character] = []
        var l1:     Character?  = nil
        var l2:     Character?  = nil
        var cont:   Bool        = false

        chStream.markSet()
        defer { chStream.markDelete() }

        while let ch = try chStream.read() {
            if l1 == "-" && l2 == "-" {
                if ch == ">" {
                    if buffer.count > 2 || !cont {
                        buffer.removeLast(2)
                        handler.comment(self, content: String(buffer), continued: cont)
                    }
                    return
                }

                chStream.markBackup()
                throw SAXError.InvalidCharacter(chStream, found: ch, expected: ">")
            }

            buffer <+ ch
            l1 = l2
            l2 = ch
            chStream.markUpdate()
            let bcc = buffer.count

            if bcc >= memLimit {
                let r = (0 ..< (bcc - 2))
                handler.comment(self, content: String(buffer[r]), continued: cont)
                cont = true
                buffer.removeSubrange(r)
            }
        }

        throw SAXError.UnexpectedEndOfInput(chStream)
    }
}
