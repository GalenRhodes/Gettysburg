/*===============================================================================================================================================================================*
 *     PROJECT: Gettysburg
 *    FILENAME: NodeMap.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 9/19/21
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
import RedBlackTree

public let NodeMapDidChange: NSNotification.Name = NSNotification.Name("NodeMapDidChange")

/*===============================================================================================================================*/
/// A collection that holds a set of nodes that can be referenced by their name.
/// 
/// - Note: When it comes to the Document Object Model, there is some ambiguity reguarding name spaces and name collisions. In
///         short how to handle nodes with namespaces and nodes without namespaces.
///
open class NodeMap<T>: BidirectionalCollection, Hashable where T: Node {
    public typealias Element = T
    public typealias Index = Int

    @usableFromInline var nodeList:      [NodeWrapper<T>]                = []
    @usableFromInline let nodeMap:       BinaryTreeSet<NodeWrapper<T>>   = BinaryTreeSet<NodeWrapper<T>>()
    @usableFromInline let nodeNameCache: BinaryTreeDictionary<String, T> = BinaryTreeDictionary<String, T>()

    /*===========================================================================================================================*/
    /// Create a new instance of NodeMap.
    ///
    public init() {}
}

extension NodeMap {
    @inlinable public var startIndex: Int { nodeList.startIndex }
    @inlinable public var endIndex:   Int { nodeList.endIndex }

    /*===========================================================================================================================*/
    /// Returns the node that has the given localName and namespaceURI.
    /// 
    /// - Parameter nsName: a tuple containing the localName and namespaceURI.
    /// - Returns: the node or `nil` if it doesn't exist in this nodeMap. -
    ///
    @inlinable public subscript(nsName: (localName: String, namespaceURI: String)) -> T? {
        nodeMap.search { n in compare((nsName.localName, n.node.localName), (nsName.namespaceURI, n.node.namespaceURI)) }?.node
    }

    @inlinable public subscript(nodeName: String) -> T? {
        if let n = nodeNameCache[nodeName] { return n }
        guard let n = nodeMap.first(where: { n in (n.node.nodeName == nodeName) })?.node else { return nil }
        nodeNameCache[nodeName] = n
        return n
    }

    @inlinable public subscript(position: Int) -> T { nodeList[position].node }

    @inlinable public func index(before i: Int) -> Int { nodeList.index(before: i) }

    @inlinable public func index(after i: Int) -> Int { nodeList.index(after: i) }

    @inlinable public func hash(into hasher: inout Hasher) { nodeMap.forEach { n in hasher.combine(n) } }

    @inlinable public static func == (lhs: NodeMap<T>, rhs: NodeMap<T>) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for n1 in lhs.nodeMap { if !rhs.nodeMap.contains(where: { n2 in (n1 == n2) }) { return false } }
        return true
    }
}

extension NodeMap {
    @usableFromInline struct NodeWrapper<T>: Comparable, Hashable where T: Node {
        @usableFromInline var node: T

        @inlinable init(node: T) { self.node = node }

        @inlinable static func < (lhs: Self, rhs: Self) -> Bool {
            ((lhs.node !== rhs.node) && areLessThan((lhs.node.localName, rhs.node.localName), (lhs.node.namespaceURI, rhs.node.namespaceURI)))
        }

        @inlinable static func == (lhs: Self, rhs: Self) -> Bool {
            ((lhs.node === rhs.node) || areEqual((lhs.node.localName, rhs.node.localName), (lhs.node.namespaceURI, rhs.node.namespaceURI)))
        }

        @inlinable func hash(into hasher: inout Hasher) {
            hasher.combine(node.localName)
            hasher.combine(node.namespaceURI)
        }
    }
}
