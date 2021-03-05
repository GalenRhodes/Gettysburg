/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: DocTypeValidate.swift
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
    /// Validate that the whitespace does, in fact, contain just whitespace.
    /// 
    /// - Parameters:
    ///   - dtd: the string containing the DTD.
    ///   - chStream: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    ///   - pos: the starting position of the DTD in the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    /// - Throws: if there is non-whitespace characters in the string.
    ///
    func validateWhitespace(_ dtd: String, charStream chStream: SAXCharInputStream, pos: (Int, Int)) throws {
        let rx: RegularExpression = RegularExpression(pattern: "\\S+", options: RXO)!
        var i:  String.Index      = dtd.startIndex

        try RegularExpression(pattern: "\\<\\!(?:(?:(ENTITY|ATTLIST|ELEMENT|NOTATION)\\s(.+?))|(?:--(.*?)--))\\>", options: RXO)?.forEachMatch(in: dtd) { m, _ in
            if let m1 = m {
                let r       = m1.range
                let (s, sp) = getSubStringAndPos(dtd, range: (i ..< r.lowerBound), position: pos, charStream: chStream)

                if let m2 = rx.firstMatch(in: s) { throw getDTDError(s, index: m2.range.lowerBound, position: sp, charStream: chStream, message: "Invalid DTD syntax: \"\(m2.subString)\"") }
                else if let comment = m1[3].subString { handler.comment(self, content: comment) }

                i = r.upperBound
            }
            return false
        }

        let (s, sp) = getSubStringAndPos(dtd, range: (i ..< dtd.endIndex), position: pos, charStream: chStream)
        if let m = rx.firstMatch(in: s) { throw getDTDError(s, index: m.range.lowerBound, position: sp, charStream: chStream, message: "Invalid DTD syntax: \"\(m.subString)\"") }
    }

    /*===========================================================================================================================================================================*/
    /// Create a Malformed DTD error.
    /// 
    /// - Parameters:
    ///   - string: the string containing the error.
    ///   - idx: the index in the string where the error is.
    ///   - pos: the starting position of the string in the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    ///   - chStream: the <code>[character input stream](http://galenrhodes.com/Rubicon/Protocols/CharInputStream.html)</code>.
    ///   - msg: the error message.
    /// - Returns: the error.
    ///
    @inlinable func getDTDError(_ string: String, index idx: String.Index, position pos: (Int, Int), charStream chStream: SAXCharInputStream, message msg: String) -> SAXError.MalformedDTD {
        SAXError.MalformedDTD(string.positionOfIndex(idx, startingLine: pos.0, startingColumn: pos.1, tabSize: chStream.tabWidth), description: msg)
    }
}
