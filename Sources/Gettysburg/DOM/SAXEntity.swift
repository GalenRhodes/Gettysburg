/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: SAXEntity.swift
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

open class SAXEntity: SAXNode {
    public let entityType: SAXEntityType
    public let publicId:   String?
    public let systemId:   String?

    public init(name: String, entityType: SAXEntityType, publicId: String? = nil, systemId: String? = nil) {
        self.entityType = entityType
        self.publicId = publicId
        self.systemId = systemId
        super.init(name: name, type: .Entity)
    }
}

open class SAXUnparsedEntity: SAXEntity {
    public let notation: String

    public init(name: String, publicId: String?, systemId: String, notation: String) {
        self.notation = notation
        super.init(name: name, entityType: .General, publicId: publicId, systemId: systemId)
    }
}
