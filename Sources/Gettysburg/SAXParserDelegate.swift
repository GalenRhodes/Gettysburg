/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: SAXParserDelegate.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 11/7/20
 *
 * Copyright © 2020 Galen Rhodes. All rights reserved.
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

//@f:0
public typealias SAXAttributeDeclFunc         = (SAXParser, String?, String, Int, Int, String?, [String])              -> Void
public typealias SAXAttributeFunc             = (SAXParser, String, String)                                            -> Void
public typealias SAXCdataBlockFunc            = (SAXParser, String)                                                    -> Void
public typealias SAXCharactersFunc            = (SAXParser, String)                                                    -> Void
public typealias SAXCommentFunc               = (SAXParser, String)                                                    -> Void
public typealias SAXElementDeclFunc           = (SAXParser, String, Int, SAXElementContent)                            -> Void
public typealias SAXEndDocumentFunc           = (SAXParser)                                                            -> Void
public typealias SAXEndElementFunc            = (SAXParser, String)                                                    -> Void
public typealias SAXEntityDeclFunc            = (SAXParser, String, Int, String?, String?, [String])                   -> Void
public typealias SAXErrorFunc                 = (SAXParser, Error)                                                     -> Void
public typealias SAXExternalSubsetFunc        = (SAXParser, String, String?, String?)                                  -> Void
public typealias SAXFatalErrorFunc            = (SAXParser, Error)                                                     -> Void
public typealias SAXGetEntityFunc             = (SAXParser, String)                                                    -> SAXEntity?
public typealias SAXGetParameterEntityFunc    = (SAXParser, String)                                                    -> SAXEntity?
public typealias SAXHasExternalSubsetFunc     = (SAXParser)                                                            -> Bool
public typealias SAXHasInternalSubsetFunc     = (SAXParser)                                                            -> Bool
public typealias SAXIgnorableWhitespaceFunc   = (SAXParser, String)                                                    -> Void
public typealias SAXInternalSubsetFunc        = (SAXParser, String, String?, String?)                                  -> Void
public typealias SAXIsStandaloneFunc          = (SAXParser)                                                            -> Bool
public typealias SAXNotationDeclFunc          = (SAXParser, String, String?, String?)                                  -> Void
public typealias SAXProcessingInstructionFunc = (SAXParser, String, String)                                            -> Void
public typealias SAXReferenceFunc             = (SAXParser, String)                                                    -> Void
public typealias SAXResolveEntityFunc         = (SAXParser, String?, String?)                                          -> InputStream?
public typealias SAXSetDocumentLocatorFunc    = (SAXParser, SAXLocator)                                                -> Void
public typealias SAXStartDocumentFunc         = (SAXParser)                                                            -> Void
public typealias SAXStartElementFunc          = (SAXParser, String, [SAXAttribute])                                    -> Void
public typealias SAXUnparsedEntityDeclFunc    = (SAXParser, String, String?, String?, String?)                         -> Void
public typealias SAXWarningFunc               = (SAXParser, Error)                                                     -> Void
public typealias SAXStartElementNsFunc        = (SAXParser, String, String?, String?, [String:String], [SAXAttribute]) -> Void
public typealias SAXEndElementNsFunc          = (SAXParser, String, String?, String?)                                  -> Void

public protocol SAXParserDelegate {
    var parseAttributeDecl         : SAXAttributeDeclFunc?         { get set }
    var parseAttribute             : SAXAttributeFunc?             { get set }
    var parseCdataBlock            : SAXCdataBlockFunc?            { get set }
    var parseCharacters            : SAXCharactersFunc?            { get set }
    var parseComment               : SAXCommentFunc?               { get set }
    var parseElementDecl           : SAXElementDeclFunc?           { get set }
    var parseEndDocument           : SAXEndDocumentFunc?           { get set }
    var parseEndElement            : SAXEndElementFunc?            { get set }
    var parseEntityDecl            : SAXEntityDeclFunc?            { get set }
    var parseError                 : SAXErrorFunc?                 { get set }
    var parseExternalSubset        : SAXExternalSubsetFunc?        { get set }
    var parseFatalError            : SAXFatalErrorFunc?            { get set }
    var parseGetEntity             : SAXGetEntityFunc?             { get set }
    var parseGetParameterEntity    : SAXGetParameterEntityFunc?    { get set }
    var parseHasExternalSubset     : SAXHasExternalSubsetFunc?     { get set }
    var parseHasInternalSubset     : SAXHasInternalSubsetFunc?     { get set }
    var parseIgnorableWhitespace   : SAXIgnorableWhitespaceFunc?   { get set }
    var parseInternalSubset        : SAXInternalSubsetFunc?        { get set }
    var parseIsStandalone          : SAXIsStandaloneFunc?          { get set }
    var parseNotationDecl          : SAXNotationDeclFunc?          { get set }
    var parseProcessingInstruction : SAXProcessingInstructionFunc? { get set }
    var parseReference             : SAXReferenceFunc?             { get set }
    var parseResolveEntity         : SAXResolveEntityFunc?         { get set }
    var parseSetDocumentLocator    : SAXSetDocumentLocatorFunc?    { get set }
    var parseStartDocument         : SAXStartDocumentFunc?         { get set }
    var parseStartElement          : SAXStartElementFunc?          { get set }
    var parseUnparsedEntityDecl    : SAXUnparsedEntityDeclFunc?    { get set }
    var parseWarning               : SAXWarningFunc?               { get set }
    var parseStartElementNs        : SAXStartElementNsFunc?        { get set }
    var parseEndElementNs          : SAXEndElementNsFunc?          { get set }
}
//@f:1
