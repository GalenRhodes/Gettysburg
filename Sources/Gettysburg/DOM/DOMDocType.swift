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

public class DOMDocType: DOMNode {

    public enum DTDExternalType: String { case Public = "PUBLIC", System = "SYSTEM" }

    public enum DTDPlacement { case Internal, External }

    //@f:0
    public override      var nodeType:       NodeType               { .DTDDocType }
    public               var name:           String                 { nodeName }
    public               let placement:      [DTDPlacement]
    public               let externalType:   DTDExternalType?
    public               let publicID:       String?
    public               let systemID:       String?
    public               let internalSubset: String?
    public internal(set) var entities:       [String: DTDEntity]
    public internal(set) var notations:      [String: DTDNotation]
    public internal(set) var elements:       [String: DTDElement]
    public internal(set) var attributes:     [String: DTDAttribute]
    //@f:1

    init(owningDocument: DOMDocument, name: String, externalType: DTDExternalType? = nil, placement: [DTDPlacement] = [ .Internal ], publicID: String?, systemID: String?, internalSubset: String?,
         attributes: [String: DTDAttribute], elements: [String: DTDElement], entities: [String: DTDEntity], notations: [String: DTDNotation]) {
        self.externalType = externalType
        self.placement = placement
        self.publicID = publicID
        self.systemID = systemID
        self.internalSubset = internalSubset
        self.entities = entities
        self.notations = notations
        self.elements = elements
        self.attributes = attributes
        super.init(owningDocument: owningDocument, qName: name, uri: nil)
    }
}
