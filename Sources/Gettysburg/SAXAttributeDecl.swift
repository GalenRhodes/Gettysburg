/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: SAXAttributeDecl.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 11/7/20
 *
 * Copyright © 2020 Galen Rhodes. All rights reserved.
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

open class SAXAttributeDecl {
}

public struct SAXAttribute: Hashable {
    let localName:    String
    let prefix:       String?
    let namespaceURI: String?
    let content:      String
    let isDefault:    Bool

    public init(localName: String, prefix: String?, namespaceURI: String?, content: String, isDefault: Bool) {
        self.localName = localName
        self.prefix = prefix
        self.namespaceURI = namespaceURI
        self.content = content
        self.isDefault = isDefault
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(localName)
        hasher.combine(prefix)
        hasher.combine(namespaceURI)
        hasher.combine(content)
        hasher.combine(isDefault)
    }

    public static func == (lhs: SAXAttribute, rhs: SAXAttribute) -> Bool {
        return lhs.localName == rhs.localName
               && lhs.prefix == rhs.prefix
               && lhs.namespaceURI == rhs.namespaceURI
               && lhs.content == rhs.content
               && lhs.isDefault == rhs.isDefault
    }
}
