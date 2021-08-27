/*****************************************************************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: DTDEntity.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: July 13, 2021
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

public class DTDEntity: DOMNode {
    public enum EntityType: String, Codable { case Parsed, Unparsed }

    //@f:0
    public override var nodeType:     NodeType                   { .DTDEntity }
    public          var name:         String                     { nodeName }
    public          var value:        String?                    { (type == .Parsed) ? textContent : nil }
    public          let type:         EntityType
    public          let placement:    DOMDocType.DTDPlacement
    public          let externalType: DOMDocType.DTDExternalType
    public          let publicID:     String?
    public          let systemID:     String?
    //@f:1

    init(owningDocument: DOMDocument, name: String, value: String?, type: EntityType, placement: DOMDocType.DTDPlacement, externalType: DOMDocType.DTDExternalType, publicID: String?, systemID: String?) {
        self.type = type
        self.placement = placement
        self.externalType = externalType
        self.publicID = publicID
        self.systemID = systemID
        super.init(owningDocument: owningDocument, qName: name, uri: nil)
        if type == .Parsed { self.textContent = (value ?? "") }
    }

    private enum CodingKeys: String, CodingKey { case type, placement, externalType, publicID, systemID }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(EntityType.self, forKey: .type)
        placement = try container.decode(DOMDocType.DTDPlacement.self, forKey: .placement)
        externalType = try container.decode(DOMDocType.DTDExternalType.self, forKey: .externalType)
        publicID = try container.decodeIfPresent(String.self, forKey: .publicID)
        systemID = try container.decodeIfPresent(String.self, forKey: .systemID)
        try super.init(from: decoder)
    }

    public override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(placement, forKey: .placement)
        try container.encode(externalType, forKey: .externalType)
        try container.encodeIfPresent(publicID, forKey: .publicID)
        try container.encodeIfPresent(systemID, forKey: .systemID)
    }
}

