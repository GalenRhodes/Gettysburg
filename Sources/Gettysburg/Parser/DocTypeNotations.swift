/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: DocTypeNotations.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 3/3/21
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
    /// Parse the DTD notations.
    /// 
    /// - Parameters:
    ///   - dtd: the string containing the DTD.
    ///   - pos: the starting position of the DTD in the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    ///   - chStream: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code> that the DTD was read from.
    /// - Throws: if any of the notation declarations are malformed.
    ///
    @inlinable func parseDTDNotations(_ dtd: String, position pos: (Int, Int), charStream chStream: SAXCharInputStream) throws {
        try RegularExpression(pattern: "\\<\\!NOTATION\\s+(.*?)\\>", options: RXO)?.forEachMatch(in: dtd) { match, _ in
            if let match = match {
                let group = match[1]
                if let range = group.range {
                    let (s, p) = getSubStringAndPos(dtd, range: range, position: pos, charStream: chStream)
                    try parseSingleDTDNotation(s.trimmed, position: p, charStream: chStream)
                }
            }
            return false
        }
    }

    /*===========================================================================================================================================================================*/
    /// Parse a single notation declaration.
    /// 
    /// - Parameters:
    ///   - str: the string containing the notation declaration.
    ///   - pos: the position of the notation declaration in the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    ///   - chStream: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code> that the notation declaration was read from.
    ///   - error: if the notation declaration is malformed.
    ///
    @usableFromInline func parseSingleDTDNotation(_ str: String, position pos: (Int, Int), charStream chStream: SAXCharInputStream) throws {
        let p = "\\A(\(rxNamePattern))\\s+(PUBLIC|SYSTEM)(?:\\s+([\"'])(.*?)\\3)(?:\\s+([\"'])(.*?)\\5)?\\z"
        guard let m = RegularExpression(pattern: p, options: RXO)?.firstMatch(in: str) else { throw SAXError.MalformedDTD(pos, description: "Malformed Notation Declaration.") }
        guard let noteName = m[1].subString else { throw SAXError.InternalError(description: "Internal Error") }

        if m[2].subString == "PUBLIC" {
            guard let publicId = m[4].subString else { throw SAXError.MalformedDTD(pos, description: "Missing Public ID.") }
            docType._notations <+ SAXDTDNotation(name: noteName, publicId: publicId, systemId: m[6].subString)
            handler.dtdNotationDecl(self, name: noteName, publicId: publicId, systemId: m[6].subString)
        }
        else {
            guard let systemId = m[4].subString else { throw SAXError.MalformedDTD(pos, description: "Missing System ID.") }
            docType._notations <+ SAXDTDNotation(name: noteName, publicId: nil, systemId: systemId)
            handler.dtdNotationDecl(self, name: noteName, publicId: nil, systemId: systemId)
        }
    }
}
