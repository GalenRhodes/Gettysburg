/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: ExternalEntities.swift
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
    func getExternalEntityCharInputStream(url: URL) throws -> SAXCharInputStream {
        guard let inStream = MarkInputStream(url: url) else { throw SAXError.IOError(0, 0, description: "Unable to open URL: \(url.absoluteString)") }
        let chStream = try SAXCharInputStream(inputStream: inStream, url: url)

        //------------------------------------------------------
        // Now skip over the text declaration if there was one.
        //------------------------------------------------------
        chStream.open()
        chStream.markSet()
        defer { chStream.markReturn() }

        let str = try chStream.readString(count: 6, errorOnEOF: false)
        if try str.matches(pattern: XML_DECL_PREFIX_PATTERN) {
            _ = try chStream.readUntil(found: "?>")
            chStream.markUpdate()
        }

        return chStream
    }
}
