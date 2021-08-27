/*****************************************************************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: DOMDocType.swift
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
import RedBlackTree

public class DOMDocType: DOMNode {

    public enum DTDExternalType: String, Codable { case Public = "PUBLIC", System = "SYSTEM" }

    public enum DTDPlacement: String, Codable { case Internal, External }

    //@f:0
    public override var nodeType:       NodeType { .DTDDocType }
    public          var name:           String   { nodeName }
    public          let placement:      [DTDPlacement]
    public          let externalType:   DTDExternalType?
    public          let publicID:       String?
    public          let systemID:       String?
    public          let internalSubset: String?
    public          let entities:       TreeDictionary<String, DTDEntity> //[String: DTDEntity]
    public          let notations:      TreeDictionary<String, DTDNotation> //[String: DTDNotation]
    public          let elements:       TreeDictionary<String, DTDElement> //[String: DTDElement]
    public          let attributes:     TreeDictionary<String, DTDAttribute> //[String: DTDAttribute]
    //@f:1

    init(owningDocument: DOMDocument, name: String, externalType: DTDExternalType? = nil, placement: [DTDPlacement] = [ .Internal ], publicID: String?, systemID: String?, internalSubset: String?,
         attributes: TreeDictionary<String, DTDAttribute>, elements: TreeDictionary<String, DTDElement>, entities: TreeDictionary<String, DTDEntity>, notations: TreeDictionary<String, DTDNotation>) {
        self.externalType = externalType
        self.placement = placement
        self.publicID = publicID
        self.systemID = systemID
        self.internalSubset = internalSubset
        self.entities = TreeDictionary(treeDictionary: entities)
        self.notations = TreeDictionary(treeDictionary: notations)
        self.elements = TreeDictionary(treeDictionary: elements)
        self.attributes = TreeDictionary(treeDictionary: attributes)
        super.init(owningDocument: owningDocument, qName: name, uri: nil)
    }

    public convenience required init(from decoder: Decoder) throws { try self.init(from: try decoder.container(keyedBy: CodingKeys.self)) }

    override init(from container: KeyedDecodingContainer<CodingKeys>) throws {
        placement = try container.decode(Array<DTDPlacement>.self, forKey: .placement)
        externalType = try container.decodeIfPresent(DTDExternalType.self, forKey: .externalType)
        publicID = try container.decodeIfPresent(String.self, forKey: .publicID)
        systemID = try container.decodeIfPresent(String.self, forKey: .systemID)
        internalSubset = try container.decodeIfPresent(String.self, forKey: .internalSubset)
        entities = try container.decode(TreeDictionary<String, DTDEntity>.self, forKey: .entities)
        notations = try container.decode(TreeDictionary<String, DTDNotation>.self, forKey: .notations)
        elements = try container.decode(TreeDictionary<String, DTDElement>.self, forKey: .elements)
        attributes = try container.decode(TreeDictionary<String, DTDAttribute>.self, forKey: .attributes)
        try super.init(from: container)
    }

    override func encode(to container: inout KeyedEncodingContainer<CodingKeys>) throws {
        try super.encode(to: &container)
        try container.encode(placement, forKey: .placement)
        try container.encodeIfPresent(externalType, forKey: .externalType)
        try container.encodeIfPresent(publicID, forKey: .publicID)
        try container.encodeIfPresent(systemID, forKey: .systemID)
        try container.encodeIfPresent(internalSubset, forKey: .internalSubset)
        try container.encode(entities, forKey: .entities)
        try container.encode(notations, forKey: .notations)
        try container.encode(elements, forKey: .elements)
        try container.encode(attributes, forKey: .attributes)
    }
}
