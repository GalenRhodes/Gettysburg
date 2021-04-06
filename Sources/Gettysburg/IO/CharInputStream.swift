/*
 *     PROJECT: Gettysburg
 *    FILENAME: CharInputStream.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 3/28/21
 *
 * Copyright © 2021 Galen Rhodes. All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software for any purpose with or without fee is hereby granted, provided that the above copyright notice and this
 * permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO
 * EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN
 * AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *//*============================================================================================================================================================================*/

import Foundation
import CoreFoundation
import Rubicon

extension CharInputStream {

    /*===========================================================================================================================================================================*/
    /// Read a set number of characters from the stream and return then as a string.
    /// 
    /// - Parameters:
    ///   - count: the number of characters to read.
    ///   - errorOnEOF: if `true` and the EOF is encountered before the number of characters are read then an error is thrown. Otherwise the characters read are returned.
    /// - Returns: the string.
    /// - Throws: if there is an I/O error or if errorOnEOF is `true` and the EOF is encountered before the set number of characters can be read.
    ///
    func readString(count: Int, errorOnEOF: Bool = true) throws -> String {
        var chars: [Character] = []
        for _ in (0 ..< count) {
            guard let ch = try read() else {
                if errorOnEOF { throw SAXError.UnexpectedEndOfInput(self) }
                break
            }
            chars <+ ch
        }
        return String(chars)
    }

    func readUntil(found: String) throws -> String {
        let f  = found.getCharacters()
        let fc = f.count
        var b  = Array<Character>()

        while let c = try read() {
            b <+ c
            if b.last(count: fc) == f { return String(b) }
        }

        throw SAXError.UnexpectedEndOfInput(self)
    }
}
