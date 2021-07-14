/*******************************************************************************************************************************************************************************//*
 *     PROJECT: Gettysburg
 *    FILENAME: RegexPatterns.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 6/22/21
 *
 * Copyright © 2021 Galen Rhodes. All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software for any purpose with or without fee is hereby granted, provided that the above copyright notice and this
 * permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO
 * EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN
 * AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *//******************************************************************************************************************************************************************************/

import Foundation
import CoreFoundation
import Rubicon

//@f:0
/*===============================================================================================================================================================================*/
/// A regular expression pattern to validate a starting character for an XML name.
///
@usableFromInline let RX_NM_START_CHAR: String = "a-zA-Z_:\\u00c0-\\u00d6\\u00d8-\\u00f6\\u00f8-\\u02ff\\u0370-\\u037d\\u037f-\\u1fff\\u200c-\\u200d\\u2070-\\u218f\\u2c00-\\u2fef\\u3001-\\ud7ff\\uf900-\\ufdcf\\ufdf0-\\ufffd\\U00010000-\\U000effff"
/*===============================================================================================================================================================================*/
/// A regular expression patther to validate a character for an XML name.
///
@usableFromInline let RX_NM_CHAR:       String = "\(RX_NM_START_CHAR)0123456789\\u002e\\u00b7\\u0300-\\u036f\\u203f-\\u2040\\u002d"

@usableFromInline let RX_ONESPC:        String = "[\\u0000-\\u0020\\u007f]"
@usableFromInline let RX_NAME:          String = "(?:[\(RX_NM_START_CHAR)][\(RX_NM_CHAR)]*)"
@usableFromInline let RX_TOKEN:         String = "(?:[\(RX_NM_CHAR)]+)"
@usableFromInline let RX_SPCS:          String = "(?:\(RX_ONESPC)+)"
@usableFromInline let RX_SPCSQ:         String = "(?:\(RX_ONESPC)*)"
@usableFromInline let RX_QUOTED:        String = "(\"[^\"]*\"|'[^']*')"
@usableFromInline let RX_ENTITY:        String = "\\&(\(RX_NAME));"
@usableFromInline let RX_PENTITY:       String = "\\%(\(RX_NAME));"
@usableFromInline let RX_SYSPUB:        String = "(?:(?:(SYSTEM)|(PUBLIC)\(RX_SPCS)\(RX_QUOTED))\(RX_SPCS)\(RX_QUOTED))"
@usableFromInline let RX_PARAM:         String = "(\(RX_NAME))=\(RX_QUOTED)"

@usableFromInline let RX_DOCTYPE:       [String] = [
    "^\(RX_SPCS)(\(RX_NAME))\(RX_SPCS)\\[$",
    "^\(RX_SPCS)(\(RX_NAME))\(RX_SPCS)(SYSTEM)\(RX_SPCS)\(RX_QUOTED)((?:\(RX_SPCSQ)\\>)|(?:\(RX_SPCS)\\[))$",
    "^\(RX_SPCS)(\(RX_NAME))\(RX_SPCS)(PUBLIC)\(RX_SPCS)\(RX_QUOTED)\(RX_SPCS)\(RX_QUOTED)\(RX_SPCSQ)\\>$",
]

@usableFromInline let RX_DTD_NOTATION:  String = "(\(RX_NAME))\(RX_SPCS)(SYSTEM|PUBLIC)\(RX_SPCS)(\(RX_QUOTED))(?:\(RX_SPCS)(\(RX_QUOTED)))?"
@usableFromInline let RX_DTD_ENTITY:    String = "(?:(\(RX_NAME))(?:(?:\(RX_SPCS)\(RX_QUOTED))|(?:\(RX_SPCS)\(RX_SYSPUB)(?:\(RX_SPCS)(NDATA)\(RX_SPCS)(\(RX_NAME)))?))|(\\%)\(RX_SPCS)(\(RX_NAME))(?:(?:\(RX_SPCS)\(RX_QUOTED))|(?:\(RX_SPCS)\(RX_SYSPUB))))"
@usableFromInline let RX_DTD_ATTLIST:   String = "(\(RX_NAME))\(RX_SPCS)(\(RX_NAME))\(RX_SPCS)(CDATA|ID|IDREF|IDREFS|ENTITY|ENTITIES|NMTOKEN|NMTOKENS|NOTATION|(?:\\([^|)]+(?:\\|[^|)]+)*\\)))\(RX_SPCS)(\\#REQUIRED|\\#IMPLIED|(?:(?:(#FIXED)\(RX_SPCS))?\(RX_QUOTED)))"
@usableFromInline let RX_DTD_ELEMENT:   String = "(\(RX_NAME))\(RX_SPCS)(EMPTY|ANY|\\([^>]+)"

@usableFromInline let RX_PROC_INST:     String = "^(\(RX_NAME))\(RX_SPCS)(?s:(.+))"
@usableFromInline let RX_XML_DECL:      String = "(?:\(RX_SPCS)\(RX_PARAM))"
