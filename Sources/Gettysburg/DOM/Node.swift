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

open class Node: Hashable {
    //@f:0
    open               var nodeType:        NodeTypes              { fatalError("Not Implemented") }
    open               var nodeName:        String                 { nodeType.rawValue }
    open               var localName:       String                 { nodeName }
    open               var prefix:          String?                { get { nil } set {} }
    open               var namespaceURI:    String?                { nil }
    open               var baseURI:         String?                { nil }
    open               var nodeValue:       String?                { get { nil } set {} }
    open               var ownerDocument:   DocumentNode           { fatalError("Not Implemented") }
    open internal(set) var parentNode:      Node?                  { get { nil } set {} }
    open internal(set) var nextSibling:     Node?                  { get { nil } set {} }
    open internal(set) var previousSibling: Node?                  { get { nil } set {} }
    open               var firstChildNode:  Node?                  { childNodes.firstNode }
    open               var lastChildNode:   Node?                  { childNodes.lastNode }
    open               var childNodes:      some NodeList          { EmptyNodeList() }
    open               var attributes:      some NodeMap           { EmptyNodeMap() }
    open               var hasAttributes:   Bool                   { attributes.count > 0 }
    open               var hasChildNodes:   Bool                   { childNodes.count > 0 }
    open               var userData:        [String: UserData]     { get { [:] } set {} }
    open               var textContent:     String                 { get { "" } set {} }
    //@f:1

    init() {}

    @discardableResult open func append<T>(child node: T) throws -> T where T: Node { node }

    @discardableResult open func insert<T>(child newNode: T, before existingNode: Node?) throws -> T where T: Node { newNode }

    @discardableResult open func replace<T>(existing oldNode: T, with newNode: Node) throws -> T where T: Node { oldNode }

    @discardableResult open func remove<T>(child node: T) throws -> T where T: Node { node }

    open func cloneNode(deep: Bool) -> Self { self }

    open func lookupPrefix(namespaceURI: String) -> String? { nil }

    open func lookupNamespaceURI(prefix: String) -> String? { nil }

    open func isDefault(namespaceURI: String) -> Bool { false }

    open func forEachChild(_ block: (Node) throws -> Void) rethrows {}

    open func isEqualTo(_ other: Node) -> Bool { false }

    open func hash(into hasher: inout Hasher) {
        hasher.combine(nodeType)
        hasher.combine(nodeName)
        hasher.combine(localName)
        hasher.combine(prefix)
        hasher.combine(namespaceURI)
        hasher.combine(nodeValue)
        hasher.combine(childNodes)
        hasher.combine(attributes)
    }

    public static func == (lhs: Node, rhs: Node) -> Bool {
        guard (lhs.nodeType == rhs.nodeType) &&
              (lhs.nodeName == rhs.nodeName) &&
              (lhs.localName == rhs.localName) &&
              (lhs.prefix == rhs.prefix) &&
              (lhs.namespaceURI == rhs.namespaceURI) &&
              (lhs.nodeValue == rhs.nodeValue) else { return false }

        let lCNodes = lhs.childNodes
        let rCNodes = rhs.childNodes

        guard lCNodes.isReadOnly == rCNodes.isReadOnly else { return false }
        guard lCNodes.count == rCNodes.count else { return false }

        for i in (0 ..< lCNodes.count) { guard lCNodes[lCNodes.startIndex + i] == rCNodes[rCNodes.startIndex + i] else { return false } }

        let lAttrs = lhs.attributes
        let rAttrs = rhs.attributes

        guard lAttrs.isReadOnly == rAttrs.isReadOnly else { return false }
        guard lAttrs.count == rAttrs.count else { return false }

        for e: NodeMapElement in lAttrs { guard let n = rAttrs[e.nodeName], n == e.node else { return false } }

        return true
    }
}
