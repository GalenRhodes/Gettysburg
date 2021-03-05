/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: SAXText.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 2/16/21
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

open class SAXText: SAXNode {
    public override var content: String { _content }
    private let _content: String

    fileprivate init(name: String, type: NodeType, content: String) {
        _content = content
        super.init(name: name, type: type)
    }

    public convenience init(content: String) {
        self.init(name: "#text", type: .Text, content: content)
    }
}

open class SAXCData: SAXText {
    public convenience init(content: String) {
        self.init(name: "#cdata-section", type: .CData, content: content)
    }
}

open class SAXComment: SAXText {
    public convenience init(content: String) {
        self.init(name: "#comment", type: .Comment, content: content)
    }
}
