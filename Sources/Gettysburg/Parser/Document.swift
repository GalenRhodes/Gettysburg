/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: Document.swift
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
    /// Parse the document.
    /// 
    /// - Parameter chStream: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    /// - Throws: if an I/O error occurs or the document is malformed.
    ///
    func parseDocument(_ chStream: SAXCharInputStream) throws {
        do {
            var foundRootElement: Bool = false
            var foundDocType:     Bool = false

            chStream.markSet()
            defer { chStream.markDelete() }

            while var ch = try chStream.read() {
                if ch == "<" {
                    ch = try chStream.readNoNil()

                    if ch == "!" {
                        //--------------------
                        // Comment or DocType
                        //--------------------
                        ch = try chStream.peek()
                        switch ch {
                            case "-":
                                chStream.markBackup(count: 2)
                                try parseComment(chStream)
                            case "D":
                                chStream.markBackup(count: 2)
                                if foundRootElement { throw SAXError.MalformedDocument(chStream, description: "DOCTYPE not expected here.") }
                                if foundDocType { throw SAXError.MalformedDocument(chStream, description: "DOCTYPE already encountered.") }
                                foundDocType = true
                                try parseDocType(chStream)
                            default:
                                throw SAXError.InvalidCharacter(chStream, found: ch, expected: "-", "D")
                        }
                    }
                    else if ch == "?" {
                        //------------------------
                        // Processing Instruction
                        //------------------------
                        try parseProcessingInstruction(chStream)
                    }
                    else if ch.isXmlNameStartChar {
                        //--------------
                        // Root Element
                        //--------------
                        chStream.markBackup(count: 2)
                        if foundRootElement { throw SAXError.MalformedDocument(chStream, description: "Document already has a root element.") }
                        foundRootElement = true
                        try parseElement(chStream)
                    }
                    else {
                        //-------------------
                        // Invalid Character
                        //-------------------
                        throw SAXError.InvalidCharacter(chStream, found: ch, expected: [])
                    }
                }
                else if !ch.isXmlWhitespace {
                    throw SAXError.InvalidCharacter(chStream, found: ch, expected: "<", "␠", "␉", "␍", "␊", "␤")
                }

                chStream.markUpdate()
            }
        }
        catch let e {
            handler.handleError(self, error: e)
            throw e
        }
    }
}
