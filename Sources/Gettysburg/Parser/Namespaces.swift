/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: Namespaces.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 2/8/21
 *
 * Copyright © 2021 Galen Rhodes. All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *//************************************************************************/

import Foundation
import CoreFoundation
import Rubicon
#if os(Windows)
    import WinSDK
#endif

extension SAXParser {

    /*===========================================================================================================================================================================*/
    /// Attempt to resolve the namespace URI given the qualified name for an element or attribute.
    /// 
    /// - Parameter name: the fully qualified name.
    /// - Returns: a tuple with the local name, prefix, and namespace URI. The namespace URI may be `nil` if it can't be resolved. The prefix may be `nil` if there isn't one.
    ///
    @inlinable final func getNamespaceInfo(qualifiedName name: String) -> (localName: String, prefix: String?, namespaceURI: String?) {
        let (prefix, localName) = name.getXmlPrefixAndLocalName()
        if prefix == "xml" {
            return (localName, "xml", "http://www.w3.org/XML/1998/namespace")
        }
        else if prefix == "xmlns" || (prefix == nil && localName == "xmlns") {
            return (localName, prefix, "http://www.w3.org/2000/xmlns/")
        }
        else if let pfx = prefix {
            if let uri = getNamespaceURI(prefix: pfx) {
                return (localName, pfx, uri)
            }
        }
        else if let uri = getNamespaceURI(prefix: "") {
            return (localName, nil, uri)
        }
        return (name, nil, nil)
    }

    /*===========================================================================================================================================================================*/
    /// Attempt to resolve the namespace URI given the prefix.
    /// 
    /// - Parameter prefix: the prefix.
    /// - Returns: the namespace URI or `nil` if it can't be found.
    ///
    @inlinable final func getNamespaceURI(prefix: String) -> String? {
        var idx = namespaceMappings.endIndex
        let stx = namespaceMappings.startIndex

        while idx > stx {
            idx = namespaceMappings.index(before: idx)
            let ns = namespaceMappings[idx]
            if prefix == ns.prefix { return ns.namespaceURI }
        }

        return nil
    }
}
