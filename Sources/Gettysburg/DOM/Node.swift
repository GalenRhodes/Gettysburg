/*===============================================================================================================================================================================*
 *     PROJECT: Gettysburg
 *    FILENAME: Node.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 9/11/21
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

open class Node: Hashable, BidirectionalCollection, Codable {
    internal enum CodingKeys: CodingKey {
        case ownerDocument
        case localName
        case prefix
        case namespaceURI
        case nodeName
        case baseURI
        case attributes
        case nodeType
        case nodeValue
        case parentNode
        case refId
    }

    public typealias Element = Node
    public typealias Index = Int

    //@f:0
    open                 var nodeType:        NodeTypes              { fatalError("Not Implemented") }
    open                 var nodeName:        String                 { nodeType.rawValue }
    open   internal(set) var localName:       String                 { get { nodeName } set {} }
    open                 var prefix:          String?                { get { nil } set {} }
    open   internal(set) var namespaceURI:    String?                { get { nil } set {} }
    open                 var nodeValue:       String?                { get { nil } set {} }
    open   internal(set) var ownerDocument:   DocumentNode           { get { fatalError("Not Implemented") } set { fatalError("Not Implemented") } }
    open   internal(set) var parentNode:      Node?                  { get { nil } set {} }
    open   internal(set) var nextSibling:     Node?                  { get { nil } set {} }
    open   internal(set) var previousSibling: Node?                  { get { nil } set {} }
    open                 var attributes:      NodeMap<AttributeNode> { NodeMap() }
    open                 var hasAttributes:   Bool                   { attributes.count > 0 }
    open                 var userData:        [String: UserData]     { get { [:] } set {} }
    public internal(set) var baseURI:         String?                = nil
    public               let startIndex:      Int
    open                 var endIndex:        Int                    { 0 }
    //@f:1

    lazy var refId: String = UUID().uuidString

    init() { startIndex = 0 }

    @discardableResult open func append<T>(child node: T) throws -> T where T: Node { node }

    @discardableResult open func insert<T>(child newNode: T, before existingNode: Node?) throws -> T where T: Node { newNode }

    @discardableResult open func replace<T>(existing oldNode: T, with newNode: Node) throws -> T where T: Node { oldNode }

    @discardableResult open func remove<T>(child node: T) throws -> T where T: Node { node }

    open func cloneNode(deep: Bool) -> Self { self }

    open func lookupPrefix(namespaceURI: String) -> String? { nil }

    open func lookupNamespaceURI(prefix: String) -> String? { nil }

    open func isDefault(namespaceURI: String) -> Bool { false }

    open subscript(position: Int) -> Node { fatalError("Index out of bounds.") }

    open func index(after i: Index) -> Index {
        guard i < endIndex else { fatalError("Index out of bounds.") }
        return i + 1
    }

    open func index(before i: Index) -> Index {
        guard i > 0 else { fatalError("Index out of bounds.") }
        return i - 1
    }

    open var textContent: String {
        get {
            var str: String = ""
            forEach { str += $0.textContent }
            return str
        }
        set {}
    }

    open func hash(into hasher: inout Hasher) {
        hasher.combine(nodeType)
        hasher.combine(nodeName)
        hasher.combine(localName)
        hasher.combine(prefix)
        hasher.combine(namespaceURI)
        hasher.combine(nodeValue)
        hasher.combine(attributes)
    }

    open func isEqual(to node: Node) -> Bool {
        guard (type(of: self) == type(of: node)) &&
              (nodeType == node.nodeType) &&
              (nodeName == node.nodeName) &&
              (localName == node.localName) &&
              (prefix == node.prefix) &&
              (namespaceURI == node.namespaceURI) &&
              (nodeValue == node.nodeValue) else { return false }
        guard attributes == node.attributes else { return false }
        guard count == node.count else { return false }
        for i in (0 ..< count) { guard self[startIndex + i] == node[node.startIndex + i] else { return false } }
        return true
    }

    public required init(from decoder: Decoder) throws { fatalError("init(from:) not implemented.") }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(namespaceURI, forKey: .namespaceURI)
        try c.encodeIfPresent(prefix, forKey: .prefix)
        try c.encode(localName, forKey: .localName)
        try c.encode(nodeName, forKey: .nodeName)
        try c.encodeIfPresent(ownerDocument, forKey: .ownerDocument)
        try c.encodeIfPresent(parentNode, forKey: .parentNode)
    }

    public static func == (lhs: Node, rhs: Node) -> Bool { lhs.isEqual(to: rhs) }
}

extension CodingUserInfoKey {
    static let referenceIDs = CodingUserInfoKey(rawValue: "referenceIDs")!
}
