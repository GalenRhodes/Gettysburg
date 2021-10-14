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

open class Node {
    //@f:0
    open var nodeType:        NodeTypes              { fatalError("Not Implemented") }
    open var nodeName:        String                 { nodeType.rawValue }
    open var localName:       String                 { nodeName }
    open var prefix:          String?                { get { nil } set {} }
    open var namespaceURI:    String?                { nil }
    open var baseURI:         String?                { nil }
    open var nodeValue:       String?                { get { nil } set {} }
    open var textContent:     String                 { get { "" } set {} }
    open var ownerDocument:   DocumentNode           { fatalError("Not Implemented") }
    open var parentNode:      Node?                  { nil }
    open var firstChildNode:  Node?                  { nil }
    open var lastChildNode:   Node?                  { nil }
    open var nextSibling:     Node?                  { nil }
    open var previousSibling: Node?                  { nil }
    open var childNodes:      NodeList               { EmptyNodeList() }
    open var attributes:      [QName: AttributeNode] { [:] }
    open var hasAttributes:   Bool                   { false }
    open var hasChildNodes:   Bool                   { false }
    open var userData:        [String: UserData]     { get { [:] } set {} }
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

    open func hash(into hasher: inout Hasher) {}
}
