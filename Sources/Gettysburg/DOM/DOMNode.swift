/*****************************************************************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: DOMNode.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: July 11, 2021
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

public typealias DOMNSName = SAXNSName
public typealias DOMName = SAXName

public class DOMNode: Hashable {
    public enum NodeType: Int {
        case Document = 1
        case DocumentFragment
        case Element
        case Attribute
        case EntityReference
        case Text
        case CData
        case Comment
        case ProcessingInstruction
        case DTDDocType
        case DTDAttribute
        case DTDElement
        case DTDNotation
        case DTDEntity
    }

    //@f:0
    public                    var nodeType:       NodeType     { fatalError("Not Implemented.") }
    public                    var nodeName:       String       { name.description }
    public                    var textContent:    String       { get { "" } set {} }
    public internal(set)      var name:           DOMNSName
    public internal(set)      var isReadOnly:     Bool         = false
    public internal(set) weak var owningDocument: DOMDocument? = nil
    public internal(set) weak var parentNode:     DOMNode?     = nil
    public internal(set)      var previousNode:   DOMNode?     = nil
    public internal(set)      var nextNode:       DOMNode?     = nil
    public internal(set)      var firstChild:     DOMNode?     = nil
    public internal(set)      var lastChild:      DOMNode?     = nil
    public internal(set)      var childNodes:     DOMNodeList  = DOMNodeList()
    public internal(set)      var attributes:     DOMNodeSet   = DOMNodeSet()
    //@f:1

    private let uuid: String = UUID().uuidString

    public init() { fatalError("Not Implemented.") }

    init(owningDocument: DOMDocument?, qName: String, uri: String? = nil) {
        self.name = DOMNSName(qName: qName, uri: uri)
        self.owningDocument = owningDocument
    }

    public func hash(into hasher: inout Hasher) { hasher.combine(uuid) }

    public static func == (lhs: DOMNode, rhs: DOMNode) -> Bool { lhs.uuid == rhs.uuid }

    public func forEachChild(exec body: (DOMNode, inout Bool) throws -> Void) rethrows {
        var n: DOMNode? = firstChild
        var s: Bool     = false

        while let node = n {
            n = node.nextNode
            try body(node, &s)
            if s { break }
        }
    }

    public func map<T>(transform body: (DOMNode) throws -> T) rethrows -> [T] {
        var array: [T] = []
        try forEachChild { node, _ in array <+ try body(node) }
        return array
    }

    @discardableResult public func append(childNode: DOMNode) throws -> DOMNode { throw DOMError.NotImplemented() }

    @discardableResult public func insert(childNode: DOMNode, beforeNode: DOMNode?) throws -> DOMNode { throw DOMError.NotImplemented() }

    @discardableResult public func replace(existingNode: DOMNode, withNode: DOMNode) throws -> DOMNode { throw DOMError.NotImplemented() }

    @discardableResult public func remove(childNode: DOMNode) throws -> DOMNode? { throw DOMError.NotImplemented() }
}

public class DOMParentNode: DOMNode {
    public override var textContent: String {
        get {
            var out: String = ""
            forEachChild { node, _ in out += node.textContent }
            return out
        }
        set {
            removeAllChildren()
            let txt = DOMText(owningDocument: owningDocument!, content: newValue)
            txt.parentNode = self
            firstChild = txt
            lastChild = txt
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
        _ = try _insert(childNode: nNode, beforeNode: eNode)
        return _remove(childNode: eNode)
    }

    @discardableResult public override func remove(childNode eNode: DOMNode) throws -> DOMNode? {
        guard let p = eNode.parentNode else { return nil }
        guard p === self else { throw DOMError.Hierarchy(description: "Node to remove is not a child of this node.") }
        return _remove(childNode: eNode)
    }

    @discardableResult func removeAllChildren() -> [DOMNode] {
        var list: [DOMNode] = []
        forEachChild { node, _ in
            list <+ node
            node.parentNode = nil
            node.nextNode = nil
            node.previousNode = nil
        }
        firstChild = nil
        lastChild = nil
        return list
    }

    private func _checkHierachry(childNode nNode: DOMNode) -> Bool {
        guard nNode !== self else { return false }
        guard let p1 = parentNode, let p2 = (p1 as? DOMParentNode) else { return true }
        return p2._checkHierachry(childNode: nNode)
    }

    private func _append(childNode nNode: DOMNode) throws -> DOMNode {
        try nNode.parentNode?.remove(childNode: nNode)

        if let lNode = lastChild {
            nNode.previousNode = lNode
            lNode.nextNode = nNode
        }
        else {
            nNode.previousNode = nil
            firstChild = nNode
        }

        lastChild = nNode
        nNode.nextNode = nil
        nNode.parentNode = self
        return nNode
    }

    private func _insert(childNode nNode: DOMNode, beforeNode eNode: DOMNode) throws -> DOMNode {
        try nNode.parentNode?.remove(childNode: nNode)

        if let pn = eNode.previousNode {
            nNode.previousNode = pn
            pn.nextNode = nNode
        }
        else {
            firstChild = nNode
            nNode.previousNode = nil
        }

        eNode.previousNode = nNode
        nNode.nextNode = eNode
        nNode.parentNode = self
        return nNode
    }

    private func _remove(childNode eNode: DOMNode) -> DOMNode {
        //@f:0
        if let pn = eNode.previousNode { pn.nextNode = eNode.nextNode         } else { firstChild = eNode.nextNode    }
        if let nn = eNode.nextNode     { nn.previousNode = eNode.previousNode } else { lastChild = eNode.previousNode }
        //@f:1
        eNode.parentNode = nil
        eNode.nextNode = nil
        eNode.previousNode = nil
        return eNode
    }
}
