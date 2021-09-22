/*===============================================================================================================================================================================*
 *     PROJECT: Gettysburg
 *    FILENAME: ParentNode.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 9/13/21
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

open class ParentNode: ChildNode {
    @usableFromInline private(set) var nodeList: [ChildNode] = []

    public override var firstChildNode: Node? { nodeList.first }
    public override var lastChildNode:  Node? { nodeList.last }
    public override var childNodes:     NodeList { NodeListImpl(self) }
    public override var hasChildNodes:  Bool { !nodeList.isEmpty }

    override init(ownerDocument: DocumentNode) { super.init(ownerDocument: ownerDocument) }

    public override func forEachChild(_ block: (Node) throws -> Void) rethrows { try nodeList.forEach(block) }

    func testHierarchy(_ newChild: Node) throws -> ChildNode {
        guard let c = (newChild as? ChildNode) else { throw DOMError.InternalInconsistency() }
        guard c.ownerDocument === ownerDocument else { throw DOMError.WrongDocument() }
        var n: Node? = self
        while let p = n {
            guard p !== c else { throw DOMError.HierarchyViolation() }
            n = p.parentNode
        }
        return c
    }

    @discardableResult public override func append<T>(child node: T) throws -> T where T: Node {
        let c = try testHierarchy(node)
        if let p = c.parentNode { try p.remove(child: node) }
        if let l = nodeList.last {
            c._previousSibling = l
            l._nextSibling = c
        }
        c._parentNode = self
        nodeList.append(c)
        return node
    }

    @discardableResult public override func insert<T>(child newNode: T, before existingNode: Node?) throws -> T where T: Node {
        guard let _e = existingNode else { return try append(child: newNode) }
        guard let e = (_e as? ChildNode) else { throw DOMError.NotSupported() }
        guard e.parentNode === self else { throw DOMError.NotFound() }
        guard let i = nodeList.firstIndex(of: e) else { throw DOMError.InternalInconsistency() }

        let c = try testHierarchy(newNode)
        if let p = c.parentNode { try p.remove(child: c) }
        c._parentNode = self

        if let p = e._previousSibling {
            c._previousSibling = p
            p._nextSibling = c
        }

        e._previousSibling = c
        c._nextSibling = e
        nodeList.insert(c, at: i)
        return newNode
    }

    @discardableResult public override func replace<T>(existing oldNode: T, with newNode: Node) throws -> T where T: Node {
        guard let e = (oldNode as? ChildNode) else { throw DOMError.NotSupported() }
        guard e.parentNode === self else { throw DOMError.NotFound() }
        guard let i = nodeList.firstIndex(of: e) else { throw DOMError.InternalInconsistency() }

        let c = try testHierarchy(newNode)
        if let p = c.parentNode { try p.remove(child: c) }
        c._parentNode = self

        if let n = e._previousSibling {
            e._previousSibling = nil
            c._previousSibling = n
            n._nextSibling = c
        }
        if let n = e._nextSibling {
            e._nextSibling = nil
            c._nextSibling = n
            n._previousSibling = c
        }

        e._parentNode = nil
        nodeList[i] = c
        return oldNode
    }

    @discardableResult public override func remove<T>(child node: T) throws -> T where T: Node {
        guard let e = (node as? ChildNode) else { throw DOMError.NotSupported() }
        guard e.parentNode === self else { throw DOMError.NotFound() }
        guard let i = nodeList.firstIndex(of: e) else { throw DOMError.InternalInconsistency() }

        nodeList.remove(at: i)

        e._nextSibling?._previousSibling = e._previousSibling
        e._previousSibling?._nextSibling = e._nextSibling

        e._parentNode = nil
        e._nextSibling = nil
        e._previousSibling = nil

        return node
    }

    public override func isEqualTo(_ other: Node) -> Bool { super.isEqualTo(other) }

    public override func hash(into hasher: inout Hasher) { super.hash(into: &hasher) }
}
