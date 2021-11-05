/************************************************************************//**
 *     PROJECT: Gettysburg
 *    FILENAME: main.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 2/7/21
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
import Rubicon

@usableFromInline let HX: [String] = [ "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F" ]

extension UnsignedInteger {
    @inlinable func toHex() -> String {
        var str: String = ""
        let m           = ((bitWidth < 21) ? bitWidth : 21)
        let ws:  Int    = ((m + 7) / 8)
        var val         = self

        for _ in (0 ..< ws) {
            let a = Int(truncatingIfNeeded: (val & 0x0f))
            let b = Int(truncatingIfNeeded: ((val & 0xf0) >> 4))
            val = (val >> 8)
            str = "\(HX[a])\(HX[b])\(str)"
        }

        return str
    }
}

do {
    guard CommandLine.arguments.count > 1 else { fatalError("Must specify filename.") }
    let data:   String            = try String(contentsOfFile: CommandLine.arguments[1], encoding: String.Encoding.utf8)
    let regex1: RegularExpression = RegularExpression(pattern: "^((?:\"[^\"]+\")|(?:[^,]+)),(.*)", options: .anchorsMatchLines)!
    let regex2: RegularExpression = RegularExpression(pattern: "([^,]+),?")!
    var map:    [String: String]  = [:]
    var tab:    Int               = 0

    // "quot":	""""""
    // "QUOT":	""""""
    // "comma":	"",""
    // "Tab":	""
    // "NewLine":	""
    // "nbsp":	""
    // "NonBreakingSpace":	""
    // "shy":	""
    //
    regex1.forEachMatch(in: data) { (match, _) in
        let name            = (match[1].subString ?? "\(UnicodeReplacementChar)").trimmed
        let entity          = (match[2].subString ?? "")
        var names: [String] = []

        if name[name.startIndex] == "\"" {
            let s = String(name[name.index(after: name.startIndex) ..< name.index(before: name.endIndex)])
            let r = regex2.matches(in: s)
            for m1 in r { names <+ m1[1].subString!.trimmed }
        }
        else {
            names <+ name.trimmed
        }

        for n in names {
            tab = max(tab, n.count)

            switch n {
                case "quot", "QUOT":             map[n] = "\\\""
                case "comma":                    map[n] = ","
                case "Tab":                      map[n] = "\\t"
                case "NewLine":                  map[n] = "\\n"
                case "bsol":                     map[n] = "\\\\"
                case "nbsp", "NonBreakingSpace": map[n] = String(Character(scalar: UnicodeScalar(UInt8(0xa0))))
                case "shy":                      map[n] = String(Character(scalar: UnicodeScalar(UInt8(0xad))))
                default:                         map[n] = entity
            }
        }
    }

    let spc:    String = "                                                                                                                                         "
    var output: String = """
                         /************************************************************************//**
                          *     PROJECT: Gettysburg
                          *    FILENAME: XMLEntities.swift
                          *         IDE: AppCode
                          *      AUTHOR: Galen Rhodes
                          *        DATE: 2/7/21
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

                         //@f:0
                         @usableFromInline let ENTITY_MAP: [String:String] = [
                         """

    for (name, entity) in map {
        let x: Int = (tab - name.count)
        output += "\n    \"\(name)\"\(String(spc[spc.startIndex ..< spc.index(spc.startIndex, offsetBy: x)])): \""
        for sc in entity.unicodeScalars {
            output += "\\u{\(sc.value.toHex())}"
        }
        output += "\","
    }
    output += "\n]\n//@f:1\n"

    try output.write(toFile: "Sources/Gettysburg/Tools/XMLEntities.swift", atomically: false, encoding: .utf8)
}
catch let e {
    fatalError("ERROR: \(e.localizedDescription)")
}
