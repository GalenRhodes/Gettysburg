/*******************************************************************************************************************************************************************************//*
 *     PROJECT: Gettysburg
 *    FILENAME: SAXDTDElementContentItem.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 6/1/21
 *
 * Copyright © 2021 Galen Rhodes. All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software for any purpose with or without fee is hereby granted, provided that the above copyright notice and this
 * permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO
 * EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN
 * AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *//******************************************************************************************************************************************************************************/

import Foundation
import CoreFoundation
import Rubicon

public class SAXDTDElemCont: Hashable {
    public enum ItemMultiplicity { case Optional, Once, ZeroOrMore, OneOrMore }

    public enum ItemType { case Element, List, PCData }

    public let type:         ItemType
    public let multiplicity: ItemMultiplicity

    public init(type: ItemType, multiplicity: ItemMultiplicity) {
        self.type = type
        self.multiplicity = multiplicity
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(type)
        hasher.combine(multiplicity)
    }

    @inlinable public static func == (lhs: SAXDTDElemCont, rhs: SAXDTDElemCont) -> Bool { equals(lhs: lhs, rhs: rhs) }

    @inlinable static func equals(lhs: SAXDTDElemCont, rhs: SAXDTDElemCont) -> Bool {
        ((Swift.type(of: lhs) == Swift.type(of: rhs)) && (lhs.type == rhs.type) && (lhs.multiplicity == rhs.multiplicity))
    }
}

public class SAXDTDElemContList: SAXDTDElemCont {
    public enum ItemConjunction { case And, Or }

    public let conjunction: ItemConjunction
    public var items:       [SAXDTDElemCont] = []

    public init(multiplicity: ItemMultiplicity, conjunction: ItemConjunction, items: [SAXDTDElemCont] = []) {
        self.conjunction = conjunction
        super.init(type: .List, multiplicity: multiplicity)
        self.items.append(contentsOf: items)
    }

    @inlinable public static func <+ (lhs: SAXDTDElemContList, rhs: SAXDTDElemCont) { lhs.items <+ rhs }

    @inlinable public static func <+ (lhs: SAXDTDElemContList, rhs: [SAXDTDElemCont]) { lhs.items.append(contentsOf: rhs) }

    @inlinable public static func == (lhs: SAXDTDElemContList, rhs: SAXDTDElemContList) -> Bool {
        (equals(lhs: lhs, rhs: rhs) && (lhs.conjunction == rhs.conjunction) && (lhs.items == rhs.items))
    }
}

public class SAXDTDElemContElement: SAXDTDElemCont {
    public let name: String

    public init(name: String, multiplicity: ItemMultiplicity) {
        self.name = name
        super.init(type: .Element, multiplicity: multiplicity)
    }

    public override func hash(into hasher: inout Hasher) {
        super.hash(into: &hasher)
        hasher.combine(name)
    }

    public static func == (lhs: SAXDTDElemContElement, rhs: SAXDTDElemContElement) -> Bool { (equals(lhs: lhs, rhs: rhs) && (lhs.name == rhs.name)) }
}

public class SAXDTDElemContPCData: SAXDTDElemCont {
    public convenience init() { self.init(type: .PCData, multiplicity: .Optional) }
}
