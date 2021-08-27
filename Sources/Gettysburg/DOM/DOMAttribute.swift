/*****************************************************************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: DOMAttribute.swift
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

public class DOMAttribute: DOMNode {
    //@f:0
    public override      var nodeType:      NodeType    { .Attribute }
    public override      var textContent:   String      { get { value } set { value = newValue } }
    public               var value:         String      { didSet { isDefault = false } }

    public internal(set) var isDefault:     Bool
    public internal(set) var owningElement: DOMElement? = nil
    //@f:1

    init(owningDocument: DOMDocument, qName: String, uri: String? = nil, value: String, isDefault: Bool) {
        self.value = value
        self.isDefault = isDefault
        super.init(owningDocument: owningDocument, qName: qName, uri: uri)
    }

    public convenience required init(from decoder: Decoder) throws { try self.init(from: try decoder.container(keyedBy: CodingKeys.self)) }

    override init(from container: KeyedDecodingContainer<CodingKeys>) throws {
        value = try container.decode(String.self, forKey: .value)
        isDefault = try container.decode(Bool.self, forKey: .isDefault)
        owningElement = try container.decodeIfPresent(DOMElement.self, forKey: .owningElement)
        try super.init(from: container)
    }

    override func encode(to container: inout KeyedEncodingContainer<CodingKeys>) throws {
        try super.encode(to: &container)
        try container.encode(value, forKey: .value)
        try container.encode(isDefault, forKey: .isDefault)
        try container.encodeIfPresent(owningElement, forKey: .owningElement)
    }
}
