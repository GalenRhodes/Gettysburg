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
            [ ("testDocTypeRegex", testDocTypeRegex), ("testAttrDeclRegex", testAttrDeclRegex), ("testEntityDeclRegex", testEntityDeclRegex), ]
        }
    #endif

    let bar = "======================================================================================================================================"

    enum TestError: Error {
        case Failed(description: String)
    }

    public override func setUpWithError() throws {}

    public override func tearDownWithError() throws {}

    func testElementRegex1() throws {
        let test = """
                   <gsr:Person xmlns:gsr="urn:GalenSherardRhodes"
                               xmlns:usa="urn:UnitedStatesOfAmerica"
                               xmlns:pgx="http://pgx.galenrhodes.com"
                               xmlns:ack="urn:dccommics"
                               xmlns:des="urn:rhodes"
                               xmlns:rho="urn:rhodes"
                               xmlns="urn:Canada">
                       <!-- - -->
                       <?herf nerf="berf"?>
                       <gsr:LastName pgx:type="German" gsr:type="nickname">Rhodes</gsr:LastName>
                       <gsr:LastName pgx:type="German" gsr:type="nickname"/>
                       <gsr:LastName pgx:type="German" gsr:type="nickname"
                   />
                       <gsr:FirstName>Galen</gsr:FirstName>
                       <MiddleName preferred="YES">Sherard</MiddleName>
                       <pgx:dob pgx:type="Julian">12 December 1967</pgx:dob>
                       <bob:info xmlns:bob="urn:minions" xmlns:ack="urn:bill.the.cat" id="1" type="demo" gsr:region="UK">
                           <bob:dob pgx:type="Gregorian">25 November 1970</bob:dob>
                           <ack:nickname>&smiley;Glenn&smiley;</ack:nickname>
                       </bob:info>
                       <usa:family des:type="fam" rho:type='fam'>Galen &copyright; Rhodes</usa:family>
                       <garfield />
                       <ack:Batman>Wonder Woman</ack:Batman>
                   </gsr:Person>
                   """
        let p = "\(RX_XML_DECL)*\(RX_SPCSQ)(/)?\\>"
        try doRegexTest(testData: test, pattern: "\\<\(RX_NAME)\(p)")
    }

    func testDocTypeRegex() throws {
        let patterns: [String] = [ //
            "^\(RX_SPCS)(\(RX_NAME))\(RX_SPCS)\\[$", //
            "^\(RX_SPCS)(\(RX_NAME))\(RX_SPCS)(SYSTEM)\(RX_SPCS)\(RX_QUOTED)((?:\(RX_SPCSQ)\\>)|(?:\(RX_SPCS)\\[))$", //
            "^\(RX_SPCS)(\(RX_NAME))\(RX_SPCS)(PUBLIC)\(RX_SPCS)\(RX_QUOTED)\(RX_SPCS)\(RX_QUOTED)\(RX_SPCSQ)\\>$", ]
        let tests:    [String] = [ //
            " Person [", //
            " Person PUBLIC \"pid\" \"sid\" >", //
            " Person SYSTEM \"sid\" >", //
            " Person PUBLIC \"pid\" \"sid\">", //
            " Person SYSTEM \"sid\">", //
            " Person SYSTEM \"sid\" [", //
            " gsr:Person [", //
            " gsr:Person PUBLIC \"pid\" \"sid\" >", //
            " gsr:Person SYSTEM \"sid\" >", //
            " gsr:Person PUBLIC \"pid\" \"sid\">", //
            " gsr:Person SYSTEM \"sid\">", //
            " gsr:Person SYSTEM \"sid\" [", //
            " Person PUBLIC 'pid' 'sid' >", //
            " Person SYSTEM 'sid' >", //
            " Person PUBLIC 'pid' 'sid'>", //
            " Person SYSTEM 'sid'>", //
            " Person SYSTEM 'sid' [", //
            " gsr:Person PUBLIC 'pid' 'sid' >", //
            " gsr:Person SYSTEM 'sid' >", //
            " gsr:Person PUBLIC 'pid' 'sid'>", //
            " gsr:Person SYSTEM 'sid'>", //
            " gsr:Person SYSTEM 'sid' [", ]

        for str in tests {
            for x in (0 ..< patterns.count) {
                let p:     String = patterns[x]
                var error: Error? = nil
                guard let rx = RegularExpression(pattern: p, error: &error) else { throw error ?? TestError.Failed(description: "Bad REGEX") }

                if let m = rx.firstMatch(in: str) {
                    print(bar)
                    print("\"\(str)\" matches #\(x) \"\(p)\"")
                    for i in (0 ..< m.count) {
                        print("        Group \("%2d".format(i)): ⎨\(m[i].subString ?? "␀")⎬")
                    }
                }
            }
        }
    }

    func testElementDeclRegex() throws {
        let test = """
                   <!ELEMENT gsr:Person (gsr:LastName,gsr:FirstName,MiddleName,(garfield|odie),pgx:dob,bob:info,ack:Batman,usa:family,foo?,bar?,foobar?,gsr:goat?,gsr:lamb?,gsr:duck?,gsr:cow?,pgx:goat?,pgx:lamb?,pgx:duck?,pgx:cow?)>
                   <!ELEMENT foo (ack:Batman)>
                   <!ELEMENT foobar (ack:Batman+)>
                   <!ELEMENT bar (#PCDATA|usa:family)*>
                   <!ELEMENT pgx:goat (ack:Batman|ack:nickname|usa:family+)+>
                   <!ELEMENT pgx:lamb (ack:Batman|ack:nickname|usa:family+)?>
                   <!ELEMENT pgx:duck (ack:Batman|ack:nickname|usa:family+)*>
                   <!ELEMENT pgx:cow  (ack:Batman|ack:nickname|usa:family+)>
                   <!ELEMENT gsr:goat (ack:Batman,ack:nickname,usa:family+)+>
                   <!ELEMENT gsr:lamb (ack:Batman,ack:nickname,usa:family+)?>
                   <!ELEMENT gsr:duck (ack:Batman,ack:nickname,usa:family+)*>
                   <!ELEMENT gsr:cow  (ack:Batman,ack:nickname,usa:family+)>
                   <!ELEMENT garfield EMPTY>
                   <!ELEMENT odie ANY>
                   <!ELEMENT gsr:LastName (#PCDATA)*>
                   <!ELEMENT gsr:FirstName (#PCDATA|ack:nickname|ack:Batman)*>
                   <!ELEMENT MiddleName (#PCDATA)>
                   <!ELEMENT usa:family ((pgx:dob|ack:nickname),(ack:Batman+|bob:dob|bob:info)?)>
                   <!ELEMENT bob:info (bob:dob,ack:nickname*)>
                   <!ELEMENT bob:dob (#PCDATA)>
                   <!ELEMENT pgx:dob (#PCDATA)>
                   <!ELEMENT ack:nickname (#PCDATA)>
                   <!ELEMENT ack:Batman (#PCDATA)>
                   """

        let p = "(\(RX_NAME))\\s+(EMPTY|ANY|\\([^>]+)"
        try doDTDRegexTest(declName: "ELEMENT", testData: test, pattern: p)
    }

    func testEntityDeclRegex() throws {
        let p0 = "(\(RX_NAME))"
        let p1 = "\\s+\(RX_QUOTED)"
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

        try doDTDRegexTest(declName: "ENTITY", testData: test, pattern: p)
    }

    func testAttrDeclRegex() throws {
        let p0 = "(\(RX_NAME))"
        let p1 = "(?:\\([^|)]+(?:\\|[^|)]+)*\\))"
        let p2 = "(CDATA|ID|IDREF|IDREFS|ENTITY|ENTITIES|NMTOKEN|NMTOKENS|NOTATION|\(p1))"
        let p3 = "(\\#REQUIRED|\\#IMPLIED|(?:(?:(#FIXED)\\s+)?\(RX_QUOTED)))"
        let p  = "\(p0)\\s+\(p0)\\s+\(p2)\\s+\(p3)"

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

        try doDTDRegexTest(declName: "ATTLIST", testData: test, pattern: p)
    }

    private func doDTDRegexTest(declName: String, testData str: String, pattern p: String) throws {
        try doRegexTest(testData: str, pattern: "\\<\\!\(declName)\\s+\(p)\\>")
    }

    private func doRegexTest(testData str: String, pattern p: String) throws {
        var error: Error? = nil
        guard let rx = RegularExpression(pattern: p, error: &error) else { throw error ?? TestError.Failed(description: "Bad REGEX") }

        print()
        print(str)
        rx.forEachMatch(in: str) { _m, _, stop in
            if let m: RegularExpression.Match = _m {
                print(bar)
                var i: Int = 0
                for g: RegularExpression.Group in m {
                    print("Group \("%2d".format(i++)): \(g.subString?.noLF().collapeWS().surroundedWith("⎨", "⎬") ?? "")")
                }
            }
        }
        print(bar)
        print()
    }
}
