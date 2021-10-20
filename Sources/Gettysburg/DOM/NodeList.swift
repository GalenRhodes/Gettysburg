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

infix operator ~==: ComparisonPrecedence

public protocol NodeList: Hashable, BidirectionalCollection where Element == Node, Index == Int {
    var firstNode:  Node? { get }
    var lastNode:   Node? { get }
    var isReadOnly: Bool { get }

    mutating func append<T>(child newNode: T) throws -> T where T: Node

    mutating func insert<T>(child newNode: T, before existingNode: Node?) throws -> T where T: Node

    mutating func replace<T>(existing oldNode: T, with newNode: Node) throws -> T where T: Node

    mutating func remove<T>(child node: T) throws -> T where T: Node
}

struct UnownedNodeList: NodeList {
    typealias Element = Node
    typealias Index = Int

    let isReadOnly: Bool
    var firstNode:  Node? { nodes.first }
    var lastNode:   Node? { nodes.last }
    var startIndex: Int { nodes.startIndex }
    var endIndex:   Int { nodes.endIndex }

    private var nodes:         [Node] = []
    private let ownerDocument: DocumentNode

    init(ownerDocument: DocumentNode, isReadOnly: Bool = true) {
        self.ownerDocument = ownerDocument
        self.isReadOnly = isReadOnly
    }

    subscript(position: Int) -> Node {
        get { nodes[position] }
        set { nodes[position] = newValue }
    }

    func index(before i: Int) -> Int { nodes.index(before: i) }

    func index(after i: Int) -> Int { nodes.index(after: i) }

    @discardableResult mutating func append<T>(child newNode: T) throws -> T where T: Node {
        guard !isReadOnly else { throw DOMError.ReadOnly(description: "Node list is read-only.") }
        guard newNode.ownerDocument === ownerDocument else { throw DOMError.WrongDocument(description: "New node belongs to the wrong document.") }
        return newNode
    }

    @discardableResult mutating func insert<T>(child newNode: T, before existingNode: Node?) throws -> T where T: Node {
        guard !isReadOnly else { throw DOMError.ReadOnly(description: "Node list is read-only.") }
        guard newNode.ownerDocument === ownerDocument else { throw DOMError.WrongDocument(description: "New node belongs to the wrong document.") }
        return newNode
    }

    @discardableResult mutating func replace<T>(existing oldNode: T, with newNode: Node) throws -> T where T: Node {
        guard !isReadOnly else { throw DOMError.ReadOnly(description: "Node list is read-only.") }
        guard newNode.ownerDocument === ownerDocument else { throw DOMError.WrongDocument(description: "New node belongs to the wrong document.") }
        return oldNode
    }

    @discardableResult mutating func remove<T>(child node: T) throws -> T where T: Node {
        guard !isReadOnly else { throw DOMError.ReadOnly(description: "Node list is read-only.") }
        guard let idx = nodes.firstIndex(where: { $0 === node }) else { throw DOMError.NodeNotFound(description: "Child node not found.") }
        nodes.remove(at: idx)
        return node
    }

    @inlinable func hash(into hasher: inout Hasher) {
        hasher.combine(nodes)
        hasher.combine(isReadOnly)
    }

    @inlinable static func == (lhs: UnownedNodeList, rhs: UnownedNodeList) -> Bool {
        guard lhs.isReadOnly == rhs.isReadOnly && lhs.count == rhs.count else { return false }
        for i in (0 ..< lhs.count) { guard lhs[lhs.startIndex + i] === rhs[rhs.startIndex + i] else { return false } }
        return true
    }
}

struct ChildNodeList: NodeList {
    typealias Element = Node
    typealias Index = Int

    @inlinable var firstNode:  Node? { nodes.first }
    @inlinable var lastNode:   Node? { nodes.last }
    @inlinable var startIndex: Int { nodes.startIndex }
    @inlinable var endIndex:   Int { nodes.endIndex }
    let            isReadOnly: Bool = false

    private var nodes: [Node] = []
    private var owner: Node

    @inlinable init(owner: Node) { self.owner = owner }

    @inlinable subscript(position: Int) -> Node { nodes[position] }

    @inlinable func index(before i: Int) -> Int { nodes.index(before: i) }

    @inlinable func index(after i: Int) -> Int { nodes.index(after: i) }

    @discardableResult mutating func append<T>(child newNode: T) throws -> T where T: Node {
        guard newNode.ownerDocument === owner.ownerDocument else { throw DOMError.WrongDocument(description: "New node belongs to the wrong document.") }
        try testHierarchy(node: newNode)

        if let p = newNode.parentNode {
            try p.remove(child: newNode)
        }
        if let l = lastNode {
            l.nextSibling = newNode
            newNode.previousSibling = l
        }

        newNode.nextSibling = nil
        newNode.parentNode = owner
        nodes <+ newNode
        return newNode
    }

    @discardableResult mutating func insert<T>(child newNode: T, before existingNode: Node?) throws -> T where T: Node {
        guard let oldNode = existingNode else { return try append(child: newNode) }
        guard oldNode.parentNode === owner, let idx = indexFor(node: oldNode) else { throw DOMError.NodeNotFound(description: "Existing node not found.") }
        guard newNode.ownerDocument === owner.ownerDocument else { throw DOMError.WrongDocument(description: "New node belongs to the wrong document.") }
        guard oldNode !== newNode else { return newNode }

        try testHierarchy(node: newNode)
        try newNode.parentNode?.remove(child: newNode)
        newNode.parentNode = owner

        newNode.previousSibling = oldNode.previousSibling
        newNode.previousSibling?.nextSibling = newNode
        newNode.nextSibling = oldNode
        oldNode.previousSibling = newNode

        nodes.insert(newNode, at: idx)
        return newNode
    }

    @discardableResult mutating func replace<T>(existing oldNode: T, with newNode: Node) throws -> T where T: Node {
        guard oldNode.parentNode === owner, let idx = indexFor(node: oldNode) else { throw DOMError.NodeNotFound(description: "Existing node not found.") }
        guard newNode.ownerDocument === owner.ownerDocument else { throw DOMError.WrongDocument(description: "New node belongs to the wrong document.") }
        guard oldNode !== newNode else { return oldNode }

        try testHierarchy(node: newNode)
        try newNode.parentNode?.remove(child: newNode)
        newNode.parentNode = owner

        newNode.previousSibling = oldNode.previousSibling
        newNode.previousSibling?.nextSibling = newNode
        newNode.nextSibling = oldNode.nextSibling
        newNode.nextSibling?.previousSibling = newNode

        oldNode.nextSibling = nil
        oldNode.previousSibling = nil
        oldNode.parentNode = nil

        nodes[idx] = newNode
        return oldNode
    }

    @discardableResult mutating func remove<T>(child node: T) throws -> T where T: Node {
        guard node.parentNode === owner, let idx = indexFor(node: node) else { throw DOMError.NodeNotFound(description: "Child node not found.") }
        if idx > startIndex {
            nodes[idx - 1].nextSibling = (((idx + 1) < endIndex) ? nodes[idx + 1] : nil)
        }
        if (idx + 1) < endIndex {
            nodes[idx + 1].previousSibling = ((idx > startIndex) ? nodes[idx - 1] : nil)
        }
        node.parentNode = nil
        node.nextSibling = nil
        node.previousSibling = nil
        nodes.remove(at: idx)
        return node
    }

    @inlinable func indexFor(node: Node) -> Index? {
        nodes.firstIndex { $0 === node }
    }

    @inlinable func testHierarchy(node: Node) throws {
        var _n: Node? = owner
        while let n = _n {
            guard n !== node else { throw DOMError.Hierarchy(description: "Heirarchy Error") }
            _n = n.parentNode
        }
    }

    @inlinable func hash(into hasher: inout Hasher) {
        hasher.combine(owner)
        hasher.combine(nodes)
        hasher.combine(isReadOnly)
    }

    @inlinable static func == (lhs: ChildNodeList, rhs: ChildNodeList) -> Bool {
        guard lhs.owner === rhs.owner && lhs.isReadOnly == rhs.isReadOnly && lhs.count == rhs.count else { return false }
        for i in (0 ..< lhs.count) { guard lhs[lhs.startIndex + i] === rhs[rhs.startIndex + i] else { return false } }
        return true
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

    @inlinable subscript(position: Int) -> Node { fatalError("Index out of bounds.") }

    @inlinable func index(before i: Int) -> Int { fatalError("Index out of bounds.") }

    @inlinable func index(after i: Int) -> Int { fatalError("Index out of bounds.") }

    @inlinable @discardableResult func append<T>(child newNode: T) throws -> T where T: Node { fatalError("List is read-only.") }

    @inlinable @discardableResult func insert<T>(child newNode: T, before existingNode: Node?) throws -> T where T: Node { fatalError("List is read-only.") }

    @inlinable @discardableResult func replace<T>(existing oldNode: T, with newNode: Node) throws -> T where T: Node { fatalError("List is read-only.") }

    @inlinable @discardableResult func remove<T>(child node: T) throws -> T where T: Node { fatalError("List is read-only.") }

    @inlinable func hash(into hasher: inout Hasher) { hasher.combine(2112) }

    @inlinable static func == (lhs: EmptyNodeList, rhs: EmptyNodeList) -> Bool { true }

    @inlinable static func ~== (lhs: EmptyNodeList, rhs: EmptyNodeList) -> Bool { true }
}
