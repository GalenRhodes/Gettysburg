/*===============================================================================================================================================================================*
 *     PROJECT: Gettysburg
 *    FILENAME: SimpleIConvCharInputStream.swift
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

open class NodeImpl: Node, Hashable, Equatable {
    //@f:0
    public var nodeType:        NodeTypes          { fatalError("nodeType has not been implemented")                                        }
    public var nodeName:        String             { nodeType.rawValue.hasPrefix("#") ? nodeType.rawValue : _name.name.description          }
    public var localName:       String             { _name.name.localName                                                                   }
    public var prefix:          String?            { get { _name.name.prefix } set { _name.name.prefix = newValue }                         }
    public var namespaceURI:    String?            { _name.uri                                                                              }
    public var baseURI:         String?            { nil                                                                                    }
    public var nodeValue:       String?            { get { nil } set {}                                                                     }
    public var textContent:     String             { get { var str: String = ""; forEachChild{ str += $0.textContent }; return str } set {} }
    public var ownerDocument:   Document           { if let d = _ownerDocument { return d } else { fatalError("No Owner Document") }        }
    public var parentNode:      Node?              { nil                                                                                    }
    public var firstChildNode:  Node?              { nil                                                                                    }
    public var lastChildNode:   Node?              { nil                                                                                    }
    public var nextSibling:     Node?              { nil                                                                                    }
    public var previousSibling: Node?              { nil                                                                                    }
    public var childNodes:      [Node]             { []                                                                                     }
    public var attributes:      [QName: Attribute] { [:]                                                                                    }
    public var hasAttributes:   Bool               { false                                                                                  }
    public var hasChildNodes:   Bool               { false                                                                                  }
    public var userData:        [String: UserData] = [:]
    //@f:1

    internal var _ownerDocument: Document? = nil
    private  var _name:          NSName

    init(ownerDocument: Document?, name: NSName) {
        _ownerDocument = ownerDocument
        _name = name
    }

    public func append<T>(child node: T) throws -> T where T: Node { throw DOMError.NotSupported(description: "Child nodes are not allowed here.") }

    public func insert<T>(child newNode: T, before existingNode: Node) throws -> T where T: Node { throw DOMError.NotSupported(description: "Child nodes are not allowed here.") }

    public func replace<T>(existing oldNode: T, with newNode: Node) throws -> T where T: Node { throw DOMError.NotSupported(description: "Child nodes are not allowed here.") }

    public func remove<T>(child node: T) throws -> T where T: Node { throw DOMError.NotSupported(description: "Child nodes are not allowed here.") }

    public func cloneNode(deep: Bool) -> Self { fatalError("cloneNode(deep:) has not been implemented") }

    public func lookupPrefix(namespaceURI: String) -> String? { fatalError("lookupPrefix(namespaceURI:) has not been implemented") }

    public func lookupNamespaceURI(prefix: String) -> String? { fatalError("lookupNamespaceURI(prefix:) has not been implemented") }

    public func isDefault(namespaceURI: String) -> Bool { fatalError("isDefault(namespaceURI:) has not been implemented") }

    public func hash(into hasher: inout Hasher) {}

    public static func == (lhs: NodeImpl, rhs: NodeImpl) -> Bool { fatalError("== has not been implemented") }

    func forEachChild(_ block: (Node) throws -> Void) rethrows {
        var node = firstChildNode
        while let n = node {
            try block(n)
            node = n.nextSibling
        }
    }
}
