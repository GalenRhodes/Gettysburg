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
    func parseCDATASection() throws {
        _ = try charStream.readChars(mustBe: "<![CDATA[")
        let text = try charStream.readUntil(found: "]]>", excludeFound: true)
        handler.cdataSection(self, content: text)
    }

    /*===========================================================================================================================================================================*/
    /// Parse and handle Comment.
    /// 
    /// - Throws: if an I/O error occurs or the comment is malformed.
    ///
    func parseComment() throws {
        _ = try charStream.readChars(mustBe: "<!--")
        try parseComment(charStream: charStream)
    }

    /*===========================================================================================================================================================================*/
    /// Parse and handle a comment.
    /// 
    /// - Parameter charStream: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    /// - Throws: if there was an I/O error or the comment was malformed.
    ///
    func parseComment(charStream: SAXCharInputStream) throws {
        let end = "-->".getCharacters()
        let ecc = end.count

        let comment = try charStream.readUntil(errorOnEOF: true) { chars, bc in
            if chars.count >= ecc {
                let last3 = chars.last(count: ecc)

                if last3 == end {
                    bc = ecc
                    return true
                }
                else if last3[last3.startIndex] == "-" && last3[last3.startIndex + 1] == "-" {
                    throw SAXError.InvalidCharacter(charStream, found: chars.last!, expected: ">")
                }
            }

            return false
        }

        handler.comment(self, content: comment)
    }
}
