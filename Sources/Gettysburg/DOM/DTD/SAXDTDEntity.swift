/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: SAXDTDEntity.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 2/16/21
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

open class SAXDTDEntity: Hashable {
    public let name:       String
    public let externType: SAXExternalType
    public let entityType: SAXEntityType
    public let publicId:   String?
    public let systemId:   String?
    public let value:      String?

    public init(name: String, entityType: SAXEntityType, publicId: String? = nil, systemId: String? = nil, value: String?) {
        self.name = name
        self.entityType = entityType
        self.publicId = publicId
        self.systemId = systemId
        self.value = value
        self.externType = ((publicId == nil && systemId == nil) ? .Internal : ((publicId == nil) ? .System : .Public))
    }

    @inlinable func setNotation(_ list: [SAXDTDNotation]) {}

    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(externType)
        hasher.combine(entityType)
        hasher.combine(publicId)
        hasher.combine(systemId)
    }

    public static func == (lhs: SAXDTDEntity, rhs: SAXDTDEntity) -> Bool {
        if lhs === rhs { return true }
        if type(of: lhs) != type(of: rhs) { return false }
        return lhs.name == rhs.name && lhs.externType == rhs.externType && lhs.entityType == rhs.entityType && lhs.publicId == rhs.publicId && lhs.systemId == rhs.systemId
    }
}

open class SAXDTDUnparsedEntity: SAXDTDEntity {
    public let notationName: String
    public var notation: SAXDTDNotation? = nil

    public init(name: String, publicId: String?, systemId: String, notation: String) {
        notationName = notation
        super.init(name: name, entityType: .General, publicId: publicId, systemId: systemId, value: nil)
    }

    @inlinable override func setNotation(_ list: [SAXDTDNotation]) { for n in list { if n.name == notationName { notation = n } } }

    public override func hash(into hasher: inout Hasher) {
        super.hash(into: &hasher)
        hasher.combine(notationName)
    }

    public static func == (lhs: SAXDTDUnparsedEntity, rhs: SAXDTDUnparsedEntity) -> Bool {
        if lhs === rhs { return true }
        if type(of: lhs) != type(of: rhs) { return false }
        return lhs.name == rhs.name && lhs.externType == rhs.externType && lhs.entityType == rhs.entityType && lhs.publicId == rhs.publicId && lhs.systemId == rhs.systemId && lhs.notationName == rhs.notationName
    }
}
