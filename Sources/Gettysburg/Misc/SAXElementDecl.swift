/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: SAXElementDecl.swift
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

open class SAXElementDeclItem {
    public enum ItemType {
        case Element
        case List
        case PCData
    }

    public enum ItemMultiplicity {
        case Optional
        case Once
        case ZeroOrMore
        case OneOrMore
    }

    public let type:         ItemType
    public let multiplicity: ItemMultiplicity

    init(type: ItemType, multiplicity: ItemMultiplicity) {
        self.type = type
        self.multiplicity = multiplicity
    }
}

open class SAXElementDeclList: SAXElementDeclItem {
    public enum ItemConjunction {
        case And
        case Or
    }

    public let conjunction: ItemConjunction
    public let items:       [SAXElementDeclItem]

    init(multiplicity: ItemMultiplicity, conjunction: ItemConjunction, items: [SAXElementDeclItem]) {
        self.conjunction = conjunction
        self.items = items
        super.init(type: .List, multiplicity: multiplicity)
    }
}

open class SAXElementDeclElement: SAXElementDeclItem {
    public let elementName: String

    init(multiplicity: ItemMultiplicity, elementName: String) {
        self.elementName = elementName
        super.init(type: .Element, multiplicity: multiplicity)
    }
}

open class SAXElementDeclPCData: SAXElementDeclItem {
    init() { super.init(type: .PCData, multiplicity: .Optional) }
}
