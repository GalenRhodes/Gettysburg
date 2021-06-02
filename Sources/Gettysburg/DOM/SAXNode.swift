/*******************************************************************************************************************************************************************************//*
 *     PROJECT: Gettysburg
 *    FILENAME: SAXNode.swift
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

open class SAXNode {
    public var parentNode:   SAXNode?
    public var nextNode:     SAXNode?
    public var prevNode:     SAXNode?
    public var firstNode:    SAXNode?
    public var lastNode:     SAXNode?
    public var nodeName:     String { _name.name }
    public var localName:    String { _name.localName }
    public var prefix:       String? { _name.prefix }
    public var namespaceURI: String? { _name.uri }

    var _name: SAXNSName

    init(name: SAXNSName) { self._name = name }

    public convenience init() {
        self.init(name: SAXNSName(localName: "#node", prefix: nil, uri: nil))
    }

    public var children: [SAXNode] {
        var array: [SAXNode] = []
        var node = firstNode
        while let n = node {
            array <+ n
            node = n.nextNode
        }
        return array
    }

    func remove(node: SAXNode) {
        guard node.parentNode === self else { fatalError() }
        if let prev = node.prevNode {
            prev.nextNode = node.nextNode
            node.nextNode?.prevNode = prev
        }
        if let next = node.nextNode {
            next.prevNode = node.prevNode
            next.prevNode?.nextNode = next
        }
        if firstNode === node { firstNode = node.nextNode }
        if lastNode === node { lastNode = node.prevNode }
        node.parentNode = nil
        node.prevNode = nil
        node.nextNode = nil
    }

    func insert(node: SAXNode, after: SAXNode?) {
        if let after = after {
            guard after.parentNode === self else { fatalError() }
            if let p = node.parentNode { p.remove(node: node) }
            node.parentNode = self
            node.prevNode = after
            node.nextNode = after.nextNode
            after.nextNode = node
            if lastNode === after { lastNode = node }
        }
        else {
            append(node: node)
        }
    }

    func append(node: SAXNode) {
        if let p = node.parentNode { p.remove(node: node) }
        node.parentNode = self
        node.nextNode = nil
        node.prevNode = lastNode
        lastNode?.nextNode = node
        lastNode = node
        if firstNode == nil {
            firstNode = node
            while let p = firstNode?.prevNode { firstNode = p }
        }
    }
}
