/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: SAXParsedElement.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 1/18/21
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

open class SAXParsedElement: SAXParsedParentNode {
    public let localName:    String
    public let prefix:       String?
    public let namespaceURI: String?
    public let attribs:      [SAXParsedAttribute]
    public let namespaces:   [String: String]

    public init(localName: String, prefix: String? = nil, namespaceURI: String? = nil, attribs: [SAXParsedAttribute] = [], namespaces: [String: String] = [:]) {
        self.localName = localName
        self.prefix = prefix
        self.namespaceURI = namespaceURI
        self.attribs = attribs
        self.namespaces = namespaces
        super.init(type: .Element)
    }
}
