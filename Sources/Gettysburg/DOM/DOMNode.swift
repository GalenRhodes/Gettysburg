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

public class DOMNode: Hashable, BidirectionalCollection {
    public typealias Element = DOMNode
    public typealias Index = Int

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
    public                    var nodeType:       NodeType       { fatalError("Not Implemented.") }
    public                    var nodeName:       String         { name.description }
    public                    var localName:      String         { name.name.localName }
    public                    var uri:            String?        { name.uri }
    public                    var prefix:         String?        { name.name.prefix }
    public                    var textContent:    String         { get { "" } set {} }
    public                    var endIndex:       Index          { 0 }
    public                    var firstChild:     DOMNode?       { nil }
    public                    var lastChild:      DOMNode?       { nil }
    public                    var startIndex:     Index          { 0 }
    public internal(set) weak var owningDocument: DOMDocument?   = nil
    public internal(set) weak var parentNode:     DOMNode?       = nil
    public internal(set)      var nextNode:       DOMNode?       = nil
    public internal(set)      var previousNode:   DOMNode?       = nil
    public internal(set)      var isReadOnly:     Bool           = false
    private                   var name:           DOMNSName
    private                   let uuid:           String         = UUID().uuidString
    //@f:1


    public init() { fatalError("Not Implemented.") }

    init(owningDocument: DOMDocument?, qName: String, uri: String? = nil) {
        self.name = DOMNSName(qName: qName, uri: uri)
        self.owningDocument = owningDocument
    }

    public func hash(into hasher: inout Hasher) { hasher.combine(uuid) }

    public static func == (lhs: DOMNode, rhs: DOMNode) -> Bool { lhs.uuid == rhs.uuid }

    @discardableResult public func append(childNode: DOMNode) throws -> DOMNode { throw DOMError.NotImplemented() }

    @discardableResult public func insert(childNode: DOMNode, beforeNode: DOMNode?) throws -> DOMNode { throw DOMError.NotImplemented() }

    @discardableResult public func replace(existingNode: DOMNode, withNode: DOMNode) throws -> DOMNode { throw DOMError.NotImplemented() }

    @discardableResult public func remove(childNode: DOMNode) throws -> DOMNode? { throw DOMError.NotImplemented() }

    public subscript(position: Index) -> Element { fatalError("Index out of range.") }

    public func index(after i: Index) -> Index { (i + 1) }

    public func index(before i: Index) -> Index { (i - 1) }

    public func forEachNode(ofType: NodeType, do body: (DOMNode) throws -> Void) rethrows { try forEach { if $0.nodeType == ofType { try body($0) } } }
}
