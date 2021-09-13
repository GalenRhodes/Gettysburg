/*===============================================================================================================================================================================*
 *     PROJECT: Gettysburg
 *    FILENAME: NodeImpl.swift
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

open class NodeImpl: Node, Hashable, Equatable {
    //@f:0
    public var nodeType:        NodeTypes              { fatalError("nodeType has not been implemented")                                        }
    public var nodeName:        String                 { nodeType.rawValue                                                                      }
    public var localName:       String                 { nodeName                                                                               }
    public var prefix:          String?                { get { nil } set {}                                                                     }
    public var namespaceURI:    String?                { nil                                                                                    }
    public var baseURI:         String?                { nil                                                                                    }
    public var nodeValue:       String?                { get { nil } set {}                                                                     }
    public var textContent:     String                 { get { var str: String = ""; forEachChild{ str += $0.textContent }; return str } set {} }
    public var ownerDocument:   DocumentNode           { if let d = _ownerDocument { return d } else { fatalError("No Owner Document") }        }
    public var parentNode:      Node?                  { nil                                                                                    }
    public var firstChildNode:  Node?                  { nil                                                                                    }
    public var lastChildNode:   Node?                  { nil                                                                                    }
    public var nextSibling:     Node?                  { nil                                                                                    }
    public var previousSibling: Node?                  { nil                                                                                    }
    public var childNodes:      NodeList               { EmptyNodeListImpl()                                                                    }
    public var attributes:      [QName: AttributeNode] { [:]                                                                                    }
    public var hasAttributes:   Bool                   { false                                                                                  }
    public var hasChildNodes:   Bool                   { false                                                                                  }
    public var userData:        [String: UserData]     = [:]
    //@f:1

    internal var _ownerDocument: DocumentNode? = nil

    init(ownerDocument: DocumentNode?) { _ownerDocument = ownerDocument }

    @discardableResult public func append<T>(child node: T) throws -> T where T: Node { throw DOMError.NotSupported(description: "Child nodes are not allowed here.") }

    @discardableResult public func insert<T>(child newNode: T, before existingNode: Node?) throws -> T where T: Node { throw DOMError.NotSupported(description: "Child nodes are not allowed here.") }

    @discardableResult public func replace<T>(existing oldNode: T, with newNode: Node) throws -> T where T: Node { throw DOMError.NotSupported(description: "Child nodes are not allowed here.") }

    @discardableResult public func remove<T>(child node: T) throws -> T where T: Node { throw DOMError.NotSupported(description: "Child nodes are not allowed here.") }

    public func cloneNode(deep: Bool) -> Self { fatalError("cloneNode(deep:) has not been implemented") }

    public func lookupPrefix(namespaceURI: String) -> String? { fatalError("lookupPrefix(namespaceURI:) has not been implemented") }

    public func lookupNamespaceURI(prefix: String) -> String? { fatalError("lookupNamespaceURI(prefix:) has not been implemented") }

    public func isDefault(namespaceURI: String) -> Bool { fatalError("isDefault(namespaceURI:) has not been implemented") }

    public func hash(into hasher: inout Hasher) {}

    public func isEqualTo(_ other: Node) -> Bool { fatalError("isEqualTo(_:) has not been implemented") }

    public static func == (lhs: NodeImpl, rhs: NodeImpl) -> Bool { lhs.isEqualTo(rhs) }

    public func forEachChild(_ block: (Node) throws -> Void) rethrows {
        var node = firstChildNode
        while let n = node {
            try block(n)
            node = n.nextSibling
        }
    }
}
