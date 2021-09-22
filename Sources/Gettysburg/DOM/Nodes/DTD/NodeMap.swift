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
    public typealias Index = BinaryTreeDictionary<String, T>.Index

    @usableFromInline let nsNameMap:   BinaryTreeDictionary<String, T> = BinaryTreeDictionary<String, T>()
    @usableFromInline let nodeNameMap: BinaryTreeDictionary<String, T> = BinaryTreeDictionary<String, T>()

    @usableFromInline var sample: [T] = []

    /*===========================================================================================================================*/
    /// Create a new instance of NodeMap.
    ///
    public init() {}
}

extension NodeMap {
    @inlinable public var startIndex: Index { nsNameMap.startIndex }
    @inlinable public var endIndex:   Index { nsNameMap.endIndex }

    /*===========================================================================================================================*/
    /// Returns the node that has the given localName and namespaceURI.
    /// 
    /// - Parameter nsName: a tuple containing the localName and namespaceURI.
    /// - Returns: the node or `nil` if it doesn't exist in this nodeMap. -
    ///
    @inlinable public subscript(nsName: NamespaceTuple) -> T? { nsNameMap["\(nsName.namespaceURI.quoted())|\(nsName.localName.quoted())"] }

    @inlinable public subscript(nodeName: String) -> T? {
        if let n = nodeNameMap[nodeName] { return n }
        guard let n = nsNameMap.first(where: { $0.value.nodeName == nodeName }) else { return nil }
        nodeNameMap[nodeName] = n.value
        return n.value
    }

    @inlinable public subscript(position: Index) -> T { nsNameMap[position].value }

    @discardableResult @inlinable public func add(node: T) -> T? {
        let n = nsNameMap[node.mapKey]
        nodeNameMap.removeAll()
        nsNameMap[node.mapKey] = node
        return n
    }

    @inlinable public func removeAll() {
        nsNameMap.removeAll()
        nodeNameMap.removeAll()
    }

    @discardableResult @inlinable public func remove(at position: Index) -> T {
        let n = self[position]
        remove(node: n)
        nodeNameMap.removeAll()
        return n
    }

    @discardableResult @inlinable public func removeNodeWith(nsName: NamespaceTuple) -> T? {
        guard let n = self[nsName] else { return nil }
        return remove(node: n)
    }

    @discardableResult @inlinable public func remove(node: T) -> T? {
        guard let n = nsNameMap.removeValue(forKey: node.mapKey) else { return nil }
        nodeNameMap.removeAll()
        return n
    }

    @inlinable public func nodesWith(localName: String) -> [T] { filter { $0.localName == localName } }

    @inlinable public func nodesWith(namespaceURI: String) -> [T] { filter { $0.namespaceURI == namespaceURI } }

    @inlinable public func nodesWith(prefix: String) -> [T] { filter { $0.prefix == prefix } }

    @inlinable public func index(before i: Index) -> Index { nsNameMap.index(before: i) }

    @inlinable public func index(after i: Index) -> Index { nsNameMap.index(after: i) }

    @inlinable public func hash(into hasher: inout Hasher) {
        nsNameMap.forEach { n in
            hasher.combine(n.value.localName)
            hasher.combine(n.value.namespaceURI)
        }
    }

    @inlinable public static func == (lhs: NodeMap<T>, rhs: NodeMap<T>) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for n1 in lhs.nsNameMap { if !rhs.nsNameMap.contains(where: { n2 in areEqual((n1.value.localName, n2.value.localName), (n1.value.namespaceURI, n2.value.namespaceURI)) }) { return false } }
        return true
    }
}

extension Node {
    @inlinable var mapKey: String {
        let uri = (namespaceURI ?? "")
        return "\(uri.quoted())|\(localName.quoted())"
    }
}
