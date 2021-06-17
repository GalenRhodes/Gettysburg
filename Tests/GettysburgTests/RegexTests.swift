/*******************************************************************************************************************************************************************************//*
 *     PROJECT: Gettysburg
 *    FILENAME: RegexTests.swift
 *         IDE: AppCode
 *      AUTHOR: Galen Rhodes
 *        DATE: 6/17/21
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

import XCTest
import Rubicon
@testable import Gettysburg

public class RegexTests: XCTestCase {

    #if !os(macOS) || os(tvOS) || os(iOS) || os(watchOS)
        public static var allTests: [(String, (RegexTests) -> () throws -> Void)] {
            [ ("testAttrDeclRegex", testAttrDeclRegex), ("testEntityDeclRegex", testEntityDeclRegex), ]
        }
    #endif

    let bar = "=========================================================================="

    enum TestError: Error {
        case Failed(description: String)
    }

    public override func setUpWithError() throws {}

    public override func tearDownWithError() throws {}

    func testEntityDeclRegex() throws {
        let p0 = "(\(rxNamePattern))"
        let p1 = "\\s+\(rxQuotedString)"
        let p2 = "(?:\(p1))"
        let p3 = "\\s+(?:(?:(SYSTEM)|(PUBLIC)\(p1))\(p1))"
        let p4 = "(?:\\s+(NDATA)\\s+\(p0))?"
        let p5 = "(?:\(p3)\(p4))"
        let p6 = "(?:\(p3))"
        let p7 = "\(p0)(?:\(p2)|\(p5))"
        let p8 = "(\\%)\\s+\(p0)(?:\(p2)|\(p6))"
        let p  = "(?:\(p7)|\(p8))"

        let test = """
                   <!ENTITY entA "valA">
                   <!ENTITY entB SYSTEM "sysIdB">
                   <!ENTITY entC PUBLIC "pubIdC" "sysIdC">
                   <!ENTITY entD SYSTEM "sysIdD" NDATA noteD>
                   <!ENTITY entE PUBLIC "pubIdE" "sysIdE" NDATA noteE>
                   <!ENTITY % entF "valF">
                   <!ENTITY % entG SYSTEM "sysIdG">
                   <!ENTITY % entH PUBLIC "pubIdH" "sysIdH">
                   <!ENTITY entI 'valI'>
                   <!ENTITY entJ SYSTEM 'sysIdJ'>
                   <!ENTITY entK PUBLIC 'pubIdK' 'sysIdK'>
                   <!ENTITY entL SYSTEM 'sysIdL' NDATA noteL>
                   <!ENTITY entM PUBLIC 'pubIdM' 'sysIdM' NDATA noteM>
                   <!ENTITY % entN 'valN'>
                   <!ENTITY % entO SYSTEM 'sysIdO'>
                   <!ENTITY % entP PUBLIC 'pubIdP' 'sysIdP'>
                   """

        try doRegexTest(declName: "ENTITY", testData: test, pattern: p)
    }

    func testAttrDeclRegex() throws {
        let p0 = "(\(rxNamePattern))"
        let p1 = "\\s+\(rxQuotedString)"
        let p2 = "(?:\\([^|)]+(?:\\|[^|)]+)*\\))"
        let p3 = "(CDATA|ID|IDREF|IDREFS|ENTITY|ENTITIES|NMTOKEN|NMTOKENS|NOTATION|\(p2))"
        let p4 = "(\\#REQUIRED|\\#IMPLIED|(?:(?:#FIXED\\s+)?\(rxQuotedString)))"

        let p = "\(p0)\\s+\(p0)\\s+\(p3)\\s+\(p4)"

        let test = """
                   <!ATTLIST MiddleName preferred (YES|NO) "NO">
                   <!ATTLIST gsr:LastName pgx:type CDATA #REQUIRED>
                   <!ATTLIST pgx:dob pgx:type (Gregorian|Julian) #REQUIRED>
                   <!ATTLIST bob:dob pgx:type (Gregorian|Julian) #IMPLIED>
                   <!ATTLIST bob:info type CDATA #IMPLIED>
                   <!ATTLIST bob:info gsr:region (USA|UK|CAN) "CAN">
                   <!ATTLIST gsr:LastName gsr:type CDATA #IMPLIED>
                   <!ATTLIST bob:info id ID #IMPLIED>
                   <!ATTLIST bob:info lid CDATA #FIXED "DUDE!">
                   """

        try doRegexTest(declName: "ATTLIST", testData: test, pattern: p)
    }

    private func doRegexTest(declName: String, testData str: String, pattern p: String) throws {
        var error: Error? = nil
        guard let rx = RegularExpression(pattern: "\\<\\!\(declName)\\s+\(p)\\>", error: &error) else { throw error ?? TestError.Failed(description: "Bad REGEX") }

        print()
        print(str)
        rx.forEachMatch(in: str) { m, _, stop in
            if let m = m {
                print(bar)
                for i in (0 ..< m.count) {
                    print("Group \("%2d".format(i)): ⎨\(m[i].subString ?? "␀")⎬")
                }
            }
        }
        print(bar)
        print()
    }
}
