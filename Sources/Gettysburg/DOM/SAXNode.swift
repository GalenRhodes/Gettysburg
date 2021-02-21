/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: SAXNode.swift
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

open class SAXNode {
    public enum NodeType {
        case Text
        case Comment
        case CData
        case Element
        case Attribute
        case ProcessingInstruction
        case Entity
        case EntityRef
    }

    public private(set) var next:       SAXNode? = nil
    public private(set) var prev:       SAXNode? = nil
    public private(set) var firstChild: SAXNode? = nil
    public private(set) var lastChild:  SAXNode? = nil

    public private(set) weak var parent: SAXNode? = nil

    public let name: String
    public let type: NodeType

    public var content: String {
        var str:   String   = ""
        var child: SAXNode? = firstChild

        while let node = child {
            str.append(node.content)
            child = node.next
        }

        return str
    }

    public init(name: String, type: NodeType) {
        self.name = name
        self.type = type
    }

    @discardableResult open func append(node: SAXNode) -> SAXNode {
        node.parent?.remove(child: node)
        node.parent = self
        node.next = nil
        node.prev = lastChild
        lastChild?.next = node
        lastChild = node
        if firstChild == nil { firstChild = node }
        return node
    }

    @discardableResult open func insert(node: SAXNode, before child: SAXNode?) -> SAXNode {
        guard let child = child else { return append(node: node) }
        node.parent?.remove(child: node)
        node.parent = self
        node.next = child
        node.prev = child.prev
        child.prev = node
        if firstChild === child { firstChild = node }
        return node
    }

    @discardableResult open func remove(child node: SAXNode) -> SAXNode {
        guard node.parent === self else { return node }
        node.prev?.next = node.next
        node.next?.prev = node.prev
        node.next = nil
        node.prev = nil
        node.parent = nil
        return node
    }
}
