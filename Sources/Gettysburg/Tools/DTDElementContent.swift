/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: DTDElementContent.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 1/15/21
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
#if os(Windows)
    import WinSDK
#endif

open class DTDElementContent: CustomStringConvertible {

    public let contentType: ContentType
    public let content:     ItemSet

    public init(contentType: ContentType, content: ItemSet) {
        self.contentType = contentType
        self.content = content
    }

    public enum ContentType {
        case Empty
        case Anything
        case Elements
        case Mixed
    }

    public enum Occurrence {
        case Optional
        case Once
        case ZeroOrMore
        case OnceOrMore
    }

    public enum Order {
        case Sequence
        case AnyOrder
    }

    public enum ItemType {
        case PCData
        case Element
        case Collection
    }

    public class Item: CustomStringConvertible {
        public let type:        ItemType
        public let occurrence:  Occurrence
        public var description: String { "" }

        public init(occurrence: Occurrence, type: ItemType) {
            self.occurrence = occurrence
            self.type = type
        }
    }

    public class ItemSet: Item {
        public let order: Order
        public let items: [Item]
        public override var description: String {
            var s: String = ""
            var f: Bool   = true
            for i in items {
                if f {
                    s += "\(i)"
                    f = false
                }
                else {
                    s += "\(order.symbol)\(i)"
                }
            }
            return "(\(s))\(occurrence.symbol)"
        }

        public init(occurrence: Occurrence, order: Order, items: [Item]) {
            self.order = order
            self.items = items
            super.init(occurrence: occurrence, type: .Collection)
        }
    }

    public class PCData: Item {
        public override var description: String { "#PCDATA" }

        public init() { super.init(occurrence: .Once, type: .PCData) }
    }

    public class Element: Item {
        public override var description: String { ("\(name)\(occurrence.symbol)") }
        public let name: String

        public init(occurrence: Occurrence, name: String) {
            self.name = name
            super.init(occurrence: occurrence, type: .Element)
        }
    }

    public var description: String {
        switch contentType {
            case .Empty:    return "EMPTY"
            case .Anything: return "ANY"
            case .Elements: return content.description
            case .Mixed:    return content.description
        }
    }
}

extension DTDElementContent.ContentType: CustomStringConvertible {
    public var description: String {
        switch self {
            case .Empty:    return "EMPTY"
            case .Anything: return "ANY"
            case .Elements: return "ELEMENTS"
            case .Mixed:    return "MIXED"
        }
    }
}

extension DTDElementContent.Occurrence: CustomStringConvertible {
    public var description: String {
        switch self {
            case .Optional:   return "Optional"
            case .Once:       return "Once"
            case .ZeroOrMore: return "0 -> ∞"
            case .OnceOrMore: return "1 -> ∞"
        }
    }
    public var symbol:      String {
        switch self {
            case .Optional:   return "?"
            case .Once:       return ""
            case .ZeroOrMore: return "*"
            case .OnceOrMore: return "+"
        }
    }
}

extension DTDElementContent.Order: CustomStringConvertible {
    public var description: String {
        switch self {
            case .Sequence:   return "Sequence"
            case .AnyOrder:   return "Any"
        }
    }
    public var symbol:      String {
        switch self {
            case .Sequence: return ","
            case .AnyOrder: return "|"
        }
    }
}

extension DTDElementContent.ItemType: CustomStringConvertible {
    public var description: String {
        switch self {
            case .Collection: return "Collection"
            case .Element:    return "Element"
            case .PCData:     return "PCData"
        }
    }
}
