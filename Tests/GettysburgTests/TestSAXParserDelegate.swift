/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: TestSAXParserDelegate.swift
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
@testable import Gettysburg

class TestSAXParserDelegate: SAXParserDelegate {
//@f:0
    var parseAttributeDecl        : SAXAttributeDeclFunc?         = { (ctx: SAXParser, element:  String?, name:       String,  type:     Int,     defType:  Int,             defValue:   String?, enumer: [String]) in print("parseAttributeDecl:")                        }
    var parseStartElementNs       : SAXStartElementNsFunc?        = { (ctx: SAXParser, name:     String,  uri:        String?, pfx:      String?, nsMaps:   [String:String], attributes: [SAXParsedAttribute]           ) in print("parseStartElementNs:")                       }
    var parseEntityDecl           : SAXEntityDeclFunc?            = { (ctx: SAXParser, name:     String,  type:       Int,     publicId: String?, systemId: String?,         content:    [String]                 ) in print("parseEntityDecl:")                           }
    var parseUnparsedEntityDecl   : SAXUnparsedEntityDeclFunc?    = { (ctx: SAXParser, name:     String,  publicId:   String?, systemId: String?, notation: String?                                               ) in print("parseUnparsedEntityDecl:")                   }
    var parseElementDecl          : SAXElementDeclFunc?           = { (ctx: SAXParser, name:     String,  type:       Int,     content:  SAXElementContent                                                        ) in print("parseElementDecl:")                          }
    var parseInternalSubset       : SAXInternalSubsetFunc?        = { (ctx: SAXParser, name:     String,  publicId:   String?, systemId: String?                                                                  ) in print("parseInternalSubset:")                       }
    var parseNotationDecl         : SAXNotationDeclFunc?          = { (ctx: SAXParser, name:     String,  publicId:   String?, systemId: String?                                                                  ) in print("parseNotationDecl:")                         }
    var parseExternalSubset       : SAXExternalSubsetFunc?        = { (ctx: SAXParser, name:     String,  externalId: String?, systemId: String?                                                                  ) in print("parseExternalSubset:")                       }
    var parseEndElementNs         : SAXEndElementNsFunc?          = { (ctx: SAXParser, name:     String,  uri:        String?, pfx:      String?                                                                  ) in print("parseEndElementNs:")                         }
    var parseStartElement         : SAXStartElementFunc?          = { (ctx: SAXParser, name:     String,  attributes: [SAXParsedAttribute]                                                                              ) in print("parseStartElement:")                         }
    var parseResolveEntity        : SAXResolveEntityFunc?         = { (ctx: SAXParser, publicId: String?, systemId:   String?                                                                                     ) in print("parseResolveEntity:")        ; return nil    }
    var parseAttribute            : SAXAttributeFunc?             = { (ctx: SAXParser, name:     String,  value:      String                                                                                      ) in print("parseAttribute:")                            }
    var parseProcessingInstruction: SAXProcessingInstructionFunc? = { (ctx: SAXParser, target:   String,  data:       String                                                                                      ) in print("parseProcessingInstruction:")                }
    var parseSetDocumentLocator   : SAXSetDocumentLocatorFunc?    = { (ctx: SAXParser, locator:  SAXLocator                                                                                                       ) in print("parseSetDocumentLocator:")                   }
    var parseCdataBlock           : SAXCdataBlockFunc?            = { (ctx: SAXParser, content:  String                                                                                                           ) in print("parseCdataBlock:")                           }
    var parseCharacters           : SAXCharactersFunc?            = { (ctx: SAXParser, content:  String                                                                                                           ) in print("parseCharacters:")                           }
    var parseComment              : SAXCommentFunc?               = { (ctx: SAXParser, content:  String                                                                                                           ) in print("parseComment:")                              }
    var parseIgnorableWhitespace  : SAXIgnorableWhitespaceFunc?   = { (ctx: SAXParser, content:  String                                                                                                           ) in print("parseIgnorableWhitespace:")                  }
    var parseEndElement           : SAXEndElementFunc?            = { (ctx: SAXParser, name:     String                                                                                                           ) in print("parseEndElement:")                           }
    var parseGetEntity            : SAXGetEntityFunc?             = { (ctx: SAXParser, name:     String                                                                                                           ) in print("parseGetEntity:")            ;  return nil   }
    var parseGetParameterEntity   : SAXGetParameterEntityFunc?    = { (ctx: SAXParser, name:     String                                                                                                           ) in print("parseGetParameterEntity:")   ;  return nil   }
    var parseReference            : SAXReferenceFunc?             = { (ctx: SAXParser, name:     String                                                                                                           ) in print("parseReference:")                            }
    var parseWarning              : SAXWarningFunc?               = { (ctx: SAXParser, error:    Error                                                                                                            ) in print("parseWarning:")                              }
    var parseError                : SAXErrorFunc?                 = { (ctx: SAXParser, error:    Error                                                                                                            ) in print("parseError:")                                }
    var parseFatalError           : SAXFatalErrorFunc?            = { (ctx: SAXParser, error:    Error                                                                                                            ) in print("parseFatalError:")                           }
    var parseIsStandalone         : SAXIsStandaloneFunc?          = { (ctx: SAXParser                                                                                                                             ) in print("parseIsStandalone:")         ; return false  }
    var parseHasExternalSubset    : SAXHasExternalSubsetFunc?     = { (ctx: SAXParser                                                                                                                             ) in print("parseHasExternalSubset:")    ; return false  }
    var parseHasInternalSubset    : SAXHasInternalSubsetFunc?     = { (ctx: SAXParser                                                                                                                             ) in print("parseHasInternalSubset:")    ; return false  }
    var parseStartDocument        : SAXStartDocumentFunc?         = { (ctx: SAXParser                                                                                                                             ) in print("parseStartDocument:")                        }
    var parseEndDocument          : SAXEndDocumentFunc?           = { (ctx: SAXParser                                                                                                                             ) in print("parseEndDocument:")                          }
//@f:1
}
