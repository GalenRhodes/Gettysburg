/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: SAXEntity.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 2/23/21
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

open class SAXEntity: SAXNode {
    public let publicId: String?
    public let systemId: String?
    public var value:    String? { firstChild == nil ? nil : content }

    public init(name: String, publicId: String?, systemId: String?, value: String?) {
        self.publicId = publicId
        self.systemId = systemId
        super.init(name: name, type: .Entity)
        if let value = value { append(node: SAXText(content: value)) }
    }

    open override func hash(into hasher: inout Hasher) {
        super.hash(into: &hasher)
        hasher.combine(publicId)
        hasher.combine(systemId)
        hasher.combine(value)
    }

    public static func == (lhs: SAXEntity, rhs: SAXEntity) -> Bool {
        if lhs === rhs { return true }
        if Swift.type(of: lhs) != Swift.type(of: rhs) { return false }
        return lhs.name == rhs.name && lhs.type == rhs.type && lhs.publicId == rhs.publicId && lhs.systemId == rhs.systemId && lhs.value == rhs.value
    }
}

open class SAXUnparsedEntity: SAXEntity {
    public let notation: String

    public init(name: String, publicId: String?, systemId: String?, value: String?, notation: String) {
        self.notation = notation
        super.init(name: name, publicId: publicId, systemId: systemId, value: value)
    }

    open override func hash(into hasher: inout Hasher) {
        super.hash(into: &hasher)
        hasher.combine(notation)
    }

    public static func == (lhs: SAXUnparsedEntity, rhs: SAXUnparsedEntity) -> Bool {
        if lhs === rhs { return true }
        if Swift.type(of: lhs) != Swift.type(of: rhs) { return false }
        return lhs.name == rhs.name && lhs.type == rhs.type && lhs.publicId == rhs.publicId && lhs.systemId == rhs.systemId && lhs.value == rhs.value && lhs.notation == rhs.notation
    }
}
