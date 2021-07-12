/*****************************************************************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: DOMParentNode.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: July 12, 2021
 *
  * Permission to use, copy, modify, and distribute this software for any purpose with or without fee is hereby granted, provided
 * that the above copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR
 * CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT,
 * NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *//*****************************************************************************************************************************/

import Foundation
import CoreFoundation
import Rubicon

public class DOMParentNode: DOMNode {
    var childNodes: [DOMNode] = []

    public override var startIndex: Index { childNodes.startIndex }
    public override var endIndex:   Index { childNodes.endIndex }
    public override var firstChild: DOMNode? { childNodes.first }
    public override var lastChild:  DOMNode? { childNodes.last }

    public override subscript(position: Index) -> Element { childNodes[position] }

    public override var textContent: String {
        get {
            var out: String = ""
            childNodes.forEach { out += $0.textContent }
            return out
        }
        set {
            removeAllChildren()
            let txt = DOMText(owningDocument: owningDocument!, content: newValue)
            txt.parentNode = self
            childNodes <+ txt
        }
    }

    @discardableResult public override func append(childNode node: DOMNode) throws -> DOMNode {
        guard node.owningDocument === owningDocument else { throw DOMError.WrongDocument() }
        guard _checkHierachry(childNode: node) else { throw DOMError.Hierarchy(description: "Node cannot be a child of this node.") }
        return try _append(childNode: node)
    }

    @discardableResult public override func insert(childNode nNode: DOMNode, beforeNode: DOMNode?) throws -> DOMNode {
        guard let eNode = beforeNode else { return try append(childNode: nNode) }
        guard eNode.parentNode === self else { throw DOMError.Hierarchy(description: "\"Before\" node is not a child of this node.") }
        guard nNode.owningDocument === owningDocument else { throw DOMError.WrongDocument() }
        guard _checkHierachry(childNode: nNode) else { throw DOMError.Hierarchy(description: "Node cannot be a child of this node.") }
        guard eNode !== nNode else { return nNode }
        return try _insert(childNode: nNode, beforeNode: eNode)
    }

    @discardableResult public override func replace(existingNode eNode: DOMNode, withNode nNode: DOMNode) throws -> DOMNode {
        guard eNode.parentNode === self else { throw DOMError.Hierarchy(description: "\"Existing\" node is not a child of this node.") }
        guard nNode.owningDocument === owningDocument else { throw DOMError.WrongDocument() }
        guard _checkHierachry(childNode: nNode) else { throw DOMError.Hierarchy(description: "Node cannot be a child of this node.") }
        guard eNode !== nNode else { return nNode }
        try _insert(childNode: nNode, beforeNode: eNode)
        return try _remove(childNode: eNode)
    }

    @discardableResult public override func remove(childNode eNode: DOMNode) throws -> DOMNode? {
        guard let p = eNode.parentNode else { return nil }
        guard p === self else { throw DOMError.Hierarchy(description: "Node to remove is not a child of this node.") }
        return try _remove(childNode: eNode)
    }

    @discardableResult func removeAllChildren() -> [DOMNode] {
        var list: [DOMNode] = []
        childNodes.forEach {
            $0.parentNode = nil
            $0.previousNode = nil
            $0.nextNode = nil
            list <+ $0
        }
        childNodes.removeAll()
        return list
    }

    private func _checkHierachry(childNode nNode: DOMNode) -> Bool {
        guard nNode !== self else { return false }
        guard let p1 = parentNode, let p2 = (p1 as? DOMParentNode) else { return true }
        return p2._checkHierachry(childNode: nNode)
    }

    private func _append(childNode nNode: DOMNode) throws -> DOMNode {
        try nNode.parentNode?.remove(childNode: nNode)
        nNode.parentNode = self
        if let ln = childNodes.last {
            nNode.previousNode = ln
            ln.nextNode = nNode
        }
        childNodes <+ nNode
        return nNode
    }

    @discardableResult private func _insert(childNode nNode: DOMNode, beforeNode eNode: DOMNode) throws -> DOMNode {
        guard let idx = childNodes.firstIndex(where: { $0 === eNode }) else { throw DOMError.Hierarchy(description: "\"Before\" node is not a child of this node.") }
        try nNode.parentNode?.remove(childNode: nNode)
        childNodes.insert(nNode, at: idx)

        if idx > 0 {
            let cn = childNodes[idx - 1]
            nNode.previousNode = cn
            cn.nextNode = nNode
        }

        nNode.nextNode = eNode
        eNode.previousNode = nNode
        nNode.parentNode = self
        return nNode
    }

    private func _remove(childNode eNode: DOMNode) throws -> DOMNode {
        guard let idx = childNodes.firstIndex(where: { $0 === eNode }) else { throw DOMError.Hierarchy(description: "Node to remove is not a child of this node.") }
        childNodes.remove(at: idx)

        if childNodes.isNotEmpty {
            let a = ((idx > childNodes.startIndex) ? childNodes[idx - 1] : nil)
            let b = ((idx < childNodes.endIndex) ? childNodes[idx] : nil)
            if let a = a { a.nextNode = b }
            if let b = b { b.previousNode = a }
        }

        eNode.parentNode = nil
        eNode.nextNode = nil
        eNode.previousNode = nil
        return eNode
    }
}
