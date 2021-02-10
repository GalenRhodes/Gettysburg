/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: ParseOther.swift
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
    /// Parse out a non-CDATA text node.
    /// 
    /// - Parameter handler: the handler.
    /// - Throws: if an I/O error occurs.
    ///
    func parseTextNode(_ handler: H) throws {
        markSet()
        defer { markDelete() }

        var data: [Character] = []

        while let ch = try charStream.read() {
            switch ch {
                case "<":
                    markBackup()
                    handler.text(parser: self, content: String(data), isWhitespace: false)
                    return
                case "&":
                    try data.append(contentsOf: readAndResolveEntityReference())
                default:
                    data <+ ch
            }
        }

        throw SAXError.UnexpectedEndOfInput(charStream)
    }

    /*===========================================================================================================================================================================*/
    /// Parse out a CDATA text node.
    /// 
    /// - Parameter handler: the handler.
    /// - Throws: if an I/O error occurs.
    ///
    func parseCDataNode(_ handler: H) throws {
        markSet()
        defer { markDelete() }

        var data: [Character] = []

        while let ch = try charStream.read() {
            data <+ ch

            if cmpSuffix(suffix: [ "]", "]", ">" ], source: data) {
                data.removeLast(3)
                handler.cdataSection(parser: self, content: String(data))
                return
            }
        }

        throw SAXError.UnexpectedEndOfInput(charStream)
    }

    /*===========================================================================================================================================================================*/
    /// Parse out a text node comprised of nothing but whitespace.
    /// 
    /// - Parameter handler: the handler.
    /// - Throws: if an I/O error occurs.
    ///
    func parseWhitespaceNode(_ handler: H) throws {
        handler.text(parser: self, content: try readWhitespace(), isWhitespace: true)
    }

    /*===========================================================================================================================================================================*/
    /// Parse an encountered comment.
    /// 
    /// - Parameter handler: the handler.
    /// - Throws: if an I/O error occurs or the comment is malformed.
    ///
    func parseComment(_ handler: H) throws { try parseComment(handler, charInputStream: charStream) }

    /*===========================================================================================================================================================================*/
    /// Parse an encountered comment.
    /// 
    /// - Parameters:
    ///   - handler: the handler.
    ///   - chStream: the character input stream.
    /// - Throws: if an I/O error occurs or the comment is malformed.
    ///
    func parseComment(_ handler: H, charInputStream chStream: CharInputStream) throws {
        let c = try doRead(charInputStream: chStream) { ch, cm in
            if cmpSuffix(suffix: [ "-", "-" ], source: cm) {
                if ch == ">" {
                    cm.removeLast(2)
                    return true
                }
                throw SAXError.InvalidCharacter(charStream, description: getBadCharMsg2(expected: ">", found: ch))
            }
            cm <+ ch
            return false
        }
        handler.comment(parser: self, comment: c)
    }

    /*===========================================================================================================================================================================*/
    /// Read and parse the processing instruction.
    /// 
    /// - Parameter handler: the handler.
    /// - Throws: if an I/O error occurs or if the EOF was encountered before the end of the processing instruction node.
    ///
    func parseProcessingInstruction(_ handler: H) throws {
        markSet()
        defer { markDelete() }
        var target: [Character] = []
        var ch:     Character   = try readChar()
        //------------------
        // Read the target.
        //------------------
        repeat {
            if ch.isXmlWhitespace {
                //---------------
                // Read the data
                //---------------
                var data: [Character] = [ ch ]
                repeat {
                    ch = try readChar()
                    if ch == "?" {
                        ch = try readChar()
                        if ch == ">" {
                            handler.processingInstruction(parser: self, target: String(target), data: String(data))
                            return
                        }
                        data <+ "?"
                    }
                    data <+ ch
                }
                while true
            }

            guard ch.isXmlNameChar else {
                markBackup()
                throw SAXError.InvalidCharacter(charStream, description: getBadCharMsg(ch))
            }
            target <+ ch
            ch = try readChar()
        }
        while true
    }
}
