/*===============================================================================================================================================================================*
 *     PROJECT: Gettysburg
 *    FILENAME: NodeList.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 10/12/21
 *
 * Copyright © 2021. All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software for any purpose with or without fee is hereby granted, provided that the above copyright notice and this
 * permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO
 * EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN
 * AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *===============================================================================================================================================================================*/

import Foundation
import CoreFoundation
import Rubicon

public protocol NodeList: BidirectionalCollection where Element == Node, Index == Int {
    var firstNode:  Node? { get }
    var lastNode:   Node? { get }
    var isReadOnly: Bool { get }

    mutating func append<T>(child node: T) throws -> T where T: Node

    mutating func insert<T>(child newNode: T, before existingNode: Node?) throws -> T where T: Node

    mutating func replace<T>(existing oldNode: T, with newNode: Node) throws -> T where T: Node

    mutating func remove<T>(child node: T) throws -> T where T: Node
}

struct BasicNodeList: NodeList {
    typealias Element = Node
    typealias Index = Int

    let isReadOnly: Bool
    var firstNode:  Node? { nodes.first }
    var lastNode:   Node? { nodes.last }
    var startIndex: Int { nodes.startIndex }
    var endIndex:   Int { nodes.endIndex }

    private var nodes: [Node] = []

    init(isReadOnly: Bool = true) { self.isReadOnly = isReadOnly }

    subscript(position: Int) -> Node {
        get { nodes[position] }
        set { nodes[position] = newValue }
    }

    func index(before i: Int) -> Int { nodes.index(before: i) }

    func index(after i: Int) -> Int { nodes.index(after: i) }

    @discardableResult mutating func append<T>(child node: T) throws -> T where T: Node {
        guard !isReadOnly else { throw DOMError.ReadOnly(description: "Node list is read-only.") }
        return node
    }

    @discardableResult mutating func insert<T>(child newNode: T, before existingNode: Node?) throws -> T where T: Node {
        guard !isReadOnly else { throw DOMError.ReadOnly(description: "Node list is read-only.") }
        return newNode
    }

    @discardableResult mutating func replace<T>(existing oldNode: T, with newNode: Node) throws -> T where T: Node {
        guard !isReadOnly else { throw DOMError.ReadOnly(description: "Node list is read-only.") }
        return oldNode
    }

    @discardableResult mutating func remove<T>(child node: T) throws -> T where T: Node {
        guard !isReadOnly else { throw DOMError.ReadOnly(description: "Node list is read-only.") }
        guard let idx = nodes.firstIndex(where: { $0 === node }) else { throw DOMError.NodeNotFound(description: "Child node not found.") }
        nodes.remove(at: idx)
        return node
    }
}

struct ChildNodeList: NodeList {
    typealias Element = Node
    typealias Index = Int

    var firstNode:  Node? { nodes.first }
    var lastNode:   Node? { nodes.last }
    var startIndex: Int { nodes.startIndex }
    var endIndex:   Int { nodes.endIndex }
    let isReadOnly: Bool = false

    private var nodes: [Node] = []
    private var owner: Node

    init(owner: Node) { self.owner = owner }

    subscript(position: Int) -> Node { nodes[position] }

    func index(before i: Int) -> Int { nodes.index(before: i) }

    func index(after i: Int) -> Int { nodes.index(after: i) }

    @discardableResult mutating func append<T>(child node: T) throws -> T where T: Node { node }

    @discardableResult mutating func insert<T>(child newNode: T, before existingNode: Node?) throws -> T where T: Node { newNode }

    @discardableResult mutating func replace<T>(existing oldNode: T, with newNode: Node) throws -> T where T: Node { oldNode }

    @discardableResult mutating func remove<T>(child node: T) throws -> T where T: Node {
        guard let idx = nodes.firstIndex(where: { $0 === node }) else { throw DOMError.NodeNotFound(description: "Child node not found.") }
        if idx > startIndex {
            nodes[idx - 1].nextSibling = (((idx + 1) < endIndex) ? nodes[idx + 1] : nil)
        }
        if (idx + 1) < endIndex {
            nodes[idx + 1].previousSibling = ((idx > startIndex) ? nodes[idx - 1] : nil)
        }
        nodes[idx].previousSibling = nil
        nodes[idx].nextSibling = nil
        nodes.remove(at: idx)
        return node
    }
}

struct EmptyNodeList: NodeList {
    typealias Element = Node
    typealias Index = Int

    let firstNode:  Node? = nil
    let lastNode:   Node? = nil
    let startIndex: Int   = 0
    let endIndex:   Int   = 0
    let isReadOnly: Bool  = true

    init() {}

    subscript(position: Int) -> Node { fatalError("Index out of bounds.") }

    func index(before i: Int) -> Int { fatalError("Index out of bounds.") }

    func index(after i: Int) -> Int { fatalError("Index out of bounds.") }

    @discardableResult func append<T>(child node: T) throws -> T where T: Node { fatalError("List is read-only.") }

    @discardableResult func insert<T>(child newNode: T, before existingNode: Node?) throws -> T where T: Node { fatalError("List is read-only.") }

    @discardableResult func replace<T>(existing oldNode: T, with newNode: Node) throws -> T where T: Node { fatalError("List is read-only.") }

    @discardableResult func remove<T>(child node: T) throws -> T where T: Node { fatalError("List is read-only.") }
}
