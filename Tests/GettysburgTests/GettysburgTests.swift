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
            [ ("testCharacterEncodingDetection", testCharacterEncodingDetection), ("testElementAllowedContent", testElementAllowedContent), ]
        }
    #endif

    public override func setUpWithError() throws {}

    public override func tearDownWithError() throws {}

    func testURL_makeAbsolute() throws {
        let urls: [String] = [
            "galen.html",
            "./galen.html",
            "../galen.html",
            "http://foo.com/Projects/galen.html",
            "http://foo.com/Projects/galen.html?bar=foo",
            "http://foo.com/Projects/galen.html#bar",
            "http://foo.com/Projects/galen.html?bar=foo#bar",
            "http://foo.com:8080/Projects/galen.html",
            "http://foo.com:8080/Projects/galen.html?bar=foo",
            "http://foo.com:8080/Projects/galen.html#bar",
            "http://foo.com:8080/Projects/galen.html?bar=foo#bar",
            "http://foo.com/Projects/./galen.html",
            "http://foo.com/Projects/../galen.html",
            "file:///Users/grhodes/Projects/test.swift",
            "file:///Users/grhodes/Projects/./test.swift",
            "file:///Users/grhodes/Projects/../test.swift",
            "file://Users/grhodes/Projects/test.swift",
            "file://Users/grhodes/Projects/./test.swift",
            "file://Users/grhodes/Projects/../test.swift",
            "ftp://bossman:8080/",
            "/galen.html",
            "~/galen.html",
            "~galen.html",
        ]

        let cd   = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)

        for str in urls {
            print("-------------------------------------------------------------------")
            print(" URL IN: \(str)")
            do {
                guard let url = URL(string: str) else { throw URLErrors.MalformedURL(description: str) }
                let url2 = try url.normalize(relativeTo: cd)
                print("URL OUT: \(url2)")
            }
            catch let e {
                XCTFail("ERROR: \(str) - \(e)")
            }
        }
    }

    func testCharacterEncodingDetection() throws {
        do {
            let fm = FileManager.default
            let path = fm.currentDirectoryPath.appendingPathComponent("Tests/GettysburgTests/TestData")
            let files = try fm.contentsOfDirectory(atPath: path).compactMap({ ($0.hasSuffix(".xml") ? $0 : nil) }).map({ path.appendingPathComponent($0) })

            for filename in files {
                do {
                    let encoding = try getEncodingName(filename: filename)
                    print("\"\(encoding)\" -> \"\(filename.lastPathComponent)\"")
                }
                catch let e {
                    XCTFail("FAILED: \(e)")
                }
            }
        }
        catch let e {
            XCTFail("FAILED: \(e)")
        }
    }

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
