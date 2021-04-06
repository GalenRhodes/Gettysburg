/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: SAXDTDElement.swift
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

open class SAXDTDElement: Hashable {
    public let name:           String
    public let attributes:     [SAXDTDAttribute]
    public let allowedContent: SAXElementAllowedContent
    public let content:        SAXDTDElementContentList?

    public init(name: String, attributes: [SAXDTDAttribute], allowedContent: SAXElementAllowedContent, content: SAXDTDElementContentList?) {
        self.name = name
        self.attributes = attributes
        self.allowedContent = allowedContent
        self.content = content
    }

    open func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(attributes)
        hasher.combine(allowedContent)
        hasher.combine(content)
    }

    public static func == (lhs: SAXDTDElement, rhs: SAXDTDElement) -> Bool {
        if lhs === rhs { return true }
        if type(of: lhs) != type(of: rhs) { return false }
        return lhs.name == rhs.name && lhs.attributes == rhs.attributes && lhs.allowedContent == rhs.allowedContent && lhs.content == rhs.content
    }
}

open class SAXDTDElementContentItem: Hashable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
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

    public var description:      String { debugDescription }
    public var debugDescription: String { "" }

    init(type: ItemType, multiplicity: ItemMultiplicity) {
        self.type = type
        self.multiplicity = multiplicity
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(type)
        hasher.combine(multiplicity)
    }

    public static func == (lhs: SAXDTDElementContentItem, rhs: SAXDTDElementContentItem) -> Bool {
        if lhs === rhs { return true }
        if Swift.type(of: lhs) != Swift.type(of: rhs) { return false }
        return lhs.type == rhs.type && lhs.multiplicity == rhs.multiplicity
    }

    public var customMirror: Mirror { Mirror(reflecting: self) }
}

open class SAXDTDElementContentList: SAXDTDElementContentItem {
    public enum ItemConjunction {
        case And
        case Or
    }

    public let conjunction: ItemConjunction
    public let items:       [SAXDTDElementContentItem]

    public override var debugDescription: String {
        guard !items.isEmpty else { return "()" }
        var str = "(\(items[0].debugDescription)"
        for i in (1 ..< items.count) {
            str.append(conjunction == .And ? "," : "|")
            str.append(contentsOf: items[i].debugDescription)
        }
        return "\(str))\(multiplicity.symbolChar)"
    }

    init(multiplicity: ItemMultiplicity, conjunction: ItemConjunction, items: [SAXDTDElementContentItem]) {
        self.conjunction = conjunction
        self.items = items
        super.init(type: .List, multiplicity: multiplicity)
    }

    public override func hash(into hasher: inout Hasher) {
        super.hash(into: &hasher)
        hasher.combine(conjunction)
        hasher.combine(items)
    }

    public static func == (lhs: SAXDTDElementContentList, rhs: SAXDTDElementContentList) -> Bool {
        if lhs === rhs { return true }
        if Swift.type(of: lhs) != Swift.type(of: rhs) { return false }
        return lhs.type == rhs.type && lhs.multiplicity == rhs.multiplicity && lhs.conjunction == rhs.conjunction && lhs.items == rhs.items
    }
}

open class SAXDTDElementContentElement: SAXDTDElementContentItem {
    public let elementName: String
    public override var debugDescription: String { "\(elementName)\(multiplicity.symbolChar)" }

    init(multiplicity: ItemMultiplicity, elementName: String) {
        self.elementName = elementName
        super.init(type: .Element, multiplicity: multiplicity)
    }

    public override func hash(into hasher: inout Hasher) {
        super.hash(into: &hasher)
        hasher.combine(elementName)
    }

    public static func == (lhs: SAXDTDElementContentElement, rhs: SAXDTDElementContentElement) -> Bool {
        if lhs === rhs { return true }
        if Swift.type(of: lhs) != Swift.type(of: rhs) { return false }
        return lhs.type == rhs.type && lhs.multiplicity == rhs.multiplicity && lhs.elementName == rhs.elementName
    }
}

open class SAXDTDElementContentPCData: SAXDTDElementContentItem {
    init() { super.init(type: .PCData, multiplicity: .Optional) }

    public static func == (lhs: SAXDTDElementContentPCData, rhs: SAXDTDElementContentPCData) -> Bool {
        if lhs === rhs { return true }
        if Swift.type(of: lhs) != Swift.type(of: rhs) { return false }
        return lhs.type == rhs.type && lhs.multiplicity == rhs.multiplicity
    }

    public override var debugDescription: String { "#PCDATA" }
}
