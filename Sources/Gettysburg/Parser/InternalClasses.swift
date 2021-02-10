/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: InternalClasses.swift
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
    /// Holds intermediate attribute information while parsing an element tag.
    ///
    @usableFromInline class NSAttribInfo {
        /*=======================================================================================================================================================================*/
        /// the line number of the start of the attribute.
        ///
        @usableFromInline let line:         Int
        /*=======================================================================================================================================================================*/
        /// the column number of the start of the attribute.
        ///
        @usableFromInline let column:       Int
        /*=======================================================================================================================================================================*/
        /// the namespace prefix for the attribute name.
        ///
        @usableFromInline let prefix:       String?
        /*=======================================================================================================================================================================*/
        /// the localname for the attribute name.
        ///
        @usableFromInline let localName:    String
        /*=======================================================================================================================================================================*/
        /// the namespace URI for the attribute.
        ///
        @usableFromInline var namespaceURI: String? = nil
        /*=======================================================================================================================================================================*/
        /// the value for the attribute.
        ///
        @usableFromInline let value:        String

        /*=======================================================================================================================================================================*/
        /// the fully qualified name for this attribute.
        ///
        @usableFromInline var qName:        String { Gettysburg.qName(prefix: prefix, localName: localName) }

        /*=======================================================================================================================================================================*/
        /// Constructs a new namespaced attribute info.
        /// 
        /// - Parameters:
        ///   - line: the line number of the start of the attribute.
        ///   - column: the column number of the start of the attribute.
        ///   - prefix: the namespace prefix for the attribute name.
        ///   - localName: the localname for the attribute name.
        ///   - value: the value for the attribute.
        ///
        @usableFromInline init(line: Int, column: Int, prefix: String?, localName: String, value: String) {
            self.line = line
            self.column = column
            self.prefix = prefix
            self.localName = localName
            self.value = value
        }
    }

    /*===========================================================================================================================================================================*/
    /// Holds a prefix and namespace URI combination.
    ///
    @usableFromInline class NamespaceURIMapping {
        /*=======================================================================================================================================================================*/
        /// The prefix.
        ///
        @usableFromInline let prefix:       String
        /*=======================================================================================================================================================================*/
        /// The namespace URI.
        ///
        @usableFromInline let namespaceURI: String

        /*=======================================================================================================================================================================*/
        /// Create a new namespace prefix/URI mapping.
        /// 
        /// - Parameters:
        ///   - prefix: the namespace prefix.
        ///   - namespaceURI: the namespace URI.
        ///
        @usableFromInline init(prefix: String = "", namespaceURI: String) {
            self.prefix = prefix
            self.namespaceURI = namespaceURI
        }
    }
}
