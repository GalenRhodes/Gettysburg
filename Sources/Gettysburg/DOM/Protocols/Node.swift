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

public protocol Node: AnyObject {
    //@f:0
    var nodeType:        NodeTypes              {   get   }
    var nodeName:        String                 {   get   }
    var localName:       String                 {   get   }
    var prefix:          String?                { get set }
    var namespaceURI:    String?                {   get   }
    var baseURI:         String?                {   get   }
    var nodeValue:       String?                { get set }
    var textContent:     String                 { get set }
    var ownerDocument:   DocumentNode           {   get   }
    var parentNode:      Node?                  {   get   }
    var firstChildNode:  Node?                  {   get   }
    var lastChildNode:   Node?                  {   get   }
    var nextSibling:     Node?                  {   get   }
    var previousSibling: Node?                  {   get   }
    var childNodes:      NodeList               {   get   }
    var attributes:      [QName: AttributeNode] {   get   }
    var hasAttributes:   Bool                   {   get   }
    var hasChildNodes:   Bool                   {   get   }
    var userData:        [String: UserData]     { get set }
    //@f:1

    @discardableResult func append<T>(child node: T) throws -> T where T: Node

    @discardableResult func insert<T>(child newNode: T, before existingNode: Node?) throws -> T where T: Node

    @discardableResult func replace<T>(existing oldNode: T, with newNode: Node) throws -> T where T: Node

    @discardableResult func remove<T>(child node: T) throws -> T where T: Node

    func cloneNode(deep: Bool) -> Self

    func lookupPrefix(namespaceURI: String) -> String?

    func lookupNamespaceURI(prefix: String) -> String?

    func isDefault(namespaceURI: String) -> Bool

    func forEachChild(_ block: (Node) throws -> Void) rethrows

    func isEqualTo(_ other: Node) -> Bool

    func hash(into hasher: inout Hasher)
}

extension Node where Self: Equatable {
    public func isEqualTo(_ other: Node) -> Bool {
        guard let otherNode = (other as? Self) else { return false }
        return self == otherNode
    }
}

public class AnyNode: Node, Equatable, Hashable {
    @usableFromInline let node: Node

    public init(_ node: Node) { self.node = node }

}

extension AnyNode {
    //@f:0
    @inlinable public var nodeType:        NodeTypes              { node.nodeType                                                }
    @inlinable public var nodeName:        String                 { node.nodeName                                                }
    @inlinable public var localName:       String                 { node.localName                                               }
    @inlinable public var prefix:          String?                { get { node.prefix      } set { node.prefix = newValue      } }
    @inlinable public var namespaceURI:    String?                { node.namespaceURI                                            }
    @inlinable public var baseURI:         String?                { node.baseURI                                                 }
    @inlinable public var nodeValue:       String?                { get { node.nodeValue   } set { node.nodeValue = newValue   } }
    @inlinable public var textContent:     String                 { get { node.textContent } set { node.textContent = newValue } }
    @inlinable public var ownerDocument:   DocumentNode           { node.ownerDocument                                           }
    @inlinable public var parentNode:      Node?                  { node.parentNode                                              }
    @inlinable public var firstChildNode:  Node?                  { node.firstChildNode                                          }
    @inlinable public var lastChildNode:   Node?                  { node.lastChildNode                                           }
    @inlinable public var nextSibling:     Node?                  { node.nextSibling                                             }
    @inlinable public var previousSibling: Node?                  { node.previousSibling                                         }
    @inlinable public var childNodes:      NodeList               { node.childNodes                                              }
    @inlinable public var attributes:      [QName: AttributeNode] { node.attributes                                              }
    @inlinable public var hasAttributes:   Bool                   { node.hasAttributes                                           }
    @inlinable public var hasChildNodes:   Bool                   { node.hasChildNodes                                           }
    @inlinable public var userData:        [String: UserData]     { get { node.userData    } set { node.userData = newValue    } }
    //@f:1

    @inlinable public func append<T>(child node: T) throws -> T where T: Node { try node.append(child: node) }

    @inlinable public func insert<T>(child newNode: T, before existingNode: Node?) throws -> T where T: Node { try node.insert(child: newNode, before: existingNode) }

    @inlinable public func replace<T>(existing oldNode: T, with newNode: Node) throws -> T where T: Node { try node.replace(existing: oldNode, with: newNode) }

    @inlinable public func remove<T>(child node: T) throws -> T where T: Node { try node.remove(child: node) }

    @inlinable public func cloneNode(deep: Bool) -> Self { node.cloneNode(deep: deep) as! Self }

    @inlinable public func lookupPrefix(namespaceURI: String) -> String? { node.lookupPrefix(namespaceURI: namespaceURI) }

    @inlinable public func lookupNamespaceURI(prefix: String) -> String? { node.lookupNamespaceURI(prefix: prefix) }

    @inlinable public func isDefault(namespaceURI: String) -> Bool { node.isDefault(namespaceURI: namespaceURI) }

    @inlinable public func forEachChild(_ block: (Node) throws -> Void) rethrows { try node.forEachChild(block) }

    @inlinable public func hash(into hasher: inout Hasher) { node.hash(into: &hasher) }

    @inlinable public func isEqualTo(_ other: Node) -> Bool { node.isEqualTo(other) }

    @inlinable public static func == (lhs: AnyNode, rhs: AnyNode) -> Bool { lhs.node.isEqualTo(rhs.node) }
}

