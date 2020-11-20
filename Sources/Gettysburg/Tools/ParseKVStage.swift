/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: ParseKVStage.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 11/17/20
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
import Rubicon

/*===============================================================================================================================*/
/// Used by `parseKeyValueData(data:willThrow:)`
///
enum ParseKVStage: Int {
    case PreKey       = 0
    case InKey        = 10
    case PostKey      = 20
    case PostEquals   = 30
    case PreInValue   = 35
    case InValue      = 40
    case InWhiteSpace = 50

    var expecting: CharacterSet {
        switch self {//@f:0
            case .PreKey                           : return .xmlNameStartChar
            case .InKey, .PostKey                  : return CharacterSet(charactersIn: "=")
            case .PostEquals, .PreInValue, .InValue: return CharacterSet(charactersIn: "\"'")
            case .InWhiteSpace                     : return .xmlWhiteSpace
        }//@f:1
    }

    var expectingChar: Character {
        switch self {//@f:0
            case .InKey, .PostKey                  : return "="
            case .PostEquals, .PreInValue, .InValue: return "\""
            case .PreKey, .InWhiteSpace            : return " "
        }//@f:1
    }

    var nextStage: [ParseKVStage] {
        switch self { //@f:0
            case .PreKey      : return [ .InKey       , .InKey        ]
            case .InKey       : return [ .PostEquals  , .PostKey      ]
            case .PostKey     : return [ .PostEquals  , .PostEquals   ]
            case .PostEquals  : return [ .InValue     , .PreInValue   ]
            case .PreInValue  : return [ .InValue     , .InValue      ]
            case .InValue     : return [ .PreKey      , .PreKey       ]
            case .InWhiteSpace: return [ .InWhiteSpace, .InWhiteSpace ]
        }//@f:1
    }

    var whiteSpaceCanTerminate: Bool {
        switch self { //@f:0
            case .InKey, .PostEquals: return true
            default                 : return false
        }//@f:1
    }

    func isIn(_ others: ParseKVStage...) -> Bool {
        for o in others { if self == o { return true } }
        return false
    }
}
