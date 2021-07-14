//
//  GettysburgTests.swift
//  GettysburgTests
//
//  Created by Galen Rhodes on 11/7/20.
//

import XCTest
import Rubicon
@testable import Gettysburg

public class GettysburgTests: XCTestCase {

    let testDataDir: String = "Tests/GettysburgTests/TestData"
    #if !os(macOS) || os(tvOS) || os(iOS) || os(watchOS)
        public static var allTests: [(String, (GettysburgTests) -> () throws -> Void)] {
            [ ("testSAXSimpleIConvCharInputStream", testSAXSimpleIConvCharInputStream), ("testSAXParser", testSAXParser), ]
        }
    #endif

    public override func setUpWithError() throws {}

    public override func tearDownWithError() throws {}

    func testElementAllowedContent() throws {
        let data: [String] = [
            "( ack:Batman)",
            "( gsr:LastName ,  gsr:FirstName ,  MiddleName+ ,  pgx:dob ,  bob:info ,  usa:family ,  ( garfield  | odie)* ,  ack:Batman ,  foo? ,  bar?)",
            "( #PCDATA  | usa:family)*",
            "EMPTY",
            "ANY",
            "( #PCDATA)",
            "( ( #PDCATA)  | one  | two+  | three)+",
            "( one? ,  two* ,  #PCDATA ,  three)",
            "( one? ,  two* ,  ( #PCDATA) ,  three)",
            "( one ,  two  | three)",
            "( )",
            "( one ,  two ,  ( ) ,  three)",
            "( ( rain  | snow  | hail)+ ,  gsr:LastName ,  gsr:FirstName ,  MiddleName+ ,  ( one ,  two ,  buckle ,  my ,  ( shoe  | boot  | sandle  | crock)) ,  pgx:dob ,  bob:info ,  usa:family ,  ( garfield  | odie)* ,  ack:Batman ,  foo? ,  bar?)",
        ]

        for str in data {
            do {
                let ac = try DTDElement.AllowedContent.getAllowedContent(content: str)
                switch ac {
                    case .Empty:
                        print("SUCCESS: EMPTY")
                    case .Any:
                        print("SUCCESS: ANY")
                    case .Elements(content: let cl):
                        print("SUCCESS: \(cl.description)")
                    case .Mixed(content: let cl):
                        print("SUCCESS: \(cl.description)")
                }
            }
            catch let e {
                print("FAILED: \(e)\n\t\(str)")
            }
        }
    }

    //    func testPerformanceExample() throws {
    //        // This is an example of a performance test case.
    //        self.measure {
    //            // Put the code you want to measure the time of here.
    //        }
    //    }
}
