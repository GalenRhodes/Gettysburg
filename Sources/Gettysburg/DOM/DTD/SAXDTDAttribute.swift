/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: SAXDTDAttribute.swift
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

open class SAXDTDAttribute: Hashable {
    public let attrType:     SAXAttributeType
    public let name:         String
    public let element:      String
    public let defaultType:  SAXAttributeDefaultType
    public let defaultValue: String?
    public let enumValues:   [String]

    public init(attrType: SAXAttributeType, name: String, element: String, enumValues: [String], defaultType: SAXAttributeDefaultType, defaultValue: String?) {
        self.attrType = attrType
        self.name = name
        self.element = element
        self.defaultType = defaultType
        self.defaultValue = defaultValue
        self.enumValues = enumValues
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(attrType)
        hasher.combine(name)
        hasher.combine(element)
        hasher.combine(enumValues)
        hasher.combine(defaultType)
        hasher.combine(defaultValue)
    }

    public static func == (lhs: SAXDTDAttribute, rhs: SAXDTDAttribute) -> Bool {
        if lhs === rhs { return true }
        if type(of: lhs) != type(of: rhs) { return false }
        return lhs.attrType == rhs.attrType && lhs.name == rhs.name && lhs.element == rhs.element && lhs.enumValues == rhs.enumValues && lhs.defaultType == rhs.defaultType && lhs.defaultValue == rhs.defaultValue
    }
}
