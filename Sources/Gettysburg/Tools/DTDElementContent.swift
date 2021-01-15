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

open class DTDElementContent {

    public let contentType: ContentType
    public let content:     [Item]

    public init(contentType: ContentType, content: [Item]) {
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
        case None
    }

    public enum ItemType {
        case PCData
        case Element
        case Collection
    }

    public class Item {
        public let type:       ItemType
        public let occurrence: Occurrence

        public init(occurrence: Occurrence, type: ItemType) {
            self.occurrence = occurrence
            self.type = type
        }
    }

    public class ItemSet: Item {
        public let order: Order
        public let items: [Item]

        public init(occurrence: Occurrence, order: Order, items: [Item]) {
            self.order = order
            self.items = items
            super.init(occurrence: occurrence, type: .Collection)
        }
    }

    public class PCData: Item { public init() { super.init(occurrence: .OnceOrMore, type: .PCData) } }

    public class Element: Item {
        public let name: String

        public init(occurrence: Occurrence, name: String) {
            self.name = name
            super.init(occurrence: occurrence, type: .Element)
        }
    }
}
