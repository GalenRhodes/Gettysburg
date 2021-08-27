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

public class DOMNode: Hashable, BidirectionalCollection, Codable {
    @usableFromInline enum CodingKeys: String, CodingKey {
        case className
        case name
        case uuid
        case isReadOnly
        case previousNode
        case nextNode
        case parentNode
        case owningDocument
        case childNodes
        case textContent
        case data
        case value, isDefault, owningElement
        case placement, externalType, publicID, systemID, internalSubset, entities, notations, elements
        case attributes
        case element, type, defaultType
        case allowedContent
    }

    public typealias Element = DOMNode
    public typealias Index = Int

    public enum NodeType: Int, Codable {
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
    private                   let uuid:           String
    private                   var name:           NSName
    //@f:1

    public init() { fatalError("Not Implemented.") }

    init(owningDocument: DOMDocument?, qName: String, uri: String? = nil) {
        self.name = NSName(qName: qName, uri: uri)
        self.owningDocument = owningDocument
        self.uuid = UUID().uuidString
    }

    public convenience required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(from: container)
    }

    init(from container: KeyedDecodingContainer<CodingKeys>) throws {
        owningDocument = try container.decodeIfPresent(DOMDocument.self, forKey: .owningDocument)
        parentNode = try container.decodeIfPresent(DOMNode.self, forKey: .parentNode)
        nextNode = try container.decodeIfPresent(DOMNode.self, forKey: .nextNode)
        previousNode = try container.decodeIfPresent(DOMNode.self, forKey: .previousNode)
        isReadOnly = try container.decode(Bool.self, forKey: .isReadOnly)
        uuid = try container.decode(String.self, forKey: .uuid)
        name = try container.decode(NSName.self, forKey: .name)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try encode(to: &container)
    }

    func encode(to container: inout KeyedEncodingContainer<CodingKeys>) throws {
        try container.encode(String(describing: type(of: self)), forKey: .className)
        try container.encodeIfPresent(owningDocument, forKey: .owningDocument)
        try container.encodeIfPresent(parentNode, forKey: .parentNode)
        try container.encodeIfPresent(nextNode, forKey: .nextNode)
        try container.encodeIfPresent(previousNode, forKey: .previousNode)
        try container.encode(isReadOnly, forKey: .isReadOnly)
        try container.encode(uuid, forKey: .uuid)
        try container.encode(name, forKey: .name)
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
