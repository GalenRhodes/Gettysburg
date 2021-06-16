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

    #if os(macOS) || os(tvOS) || os(iOS) || os(watchOS)
        let testDataDir: String = "Tests/GettysburgTests/TestData"
    #else
        public static var allTests: [(String, (GettysburgTests) -> () throws -> Void)] {
            [ ("testSAXSimpleIConvCharInputStream", testSAXSimpleIConvCharInputStream), ("testSAXParser", testSAXParser), ]
        }
        let testDataDir: String = ".build/debug/Gettysburg_GettysburgTests.resources/TestData"
    #endif

    public override func setUpWithError() throws {}

    public override func tearDownWithError() throws {}

    func testSAXSimpleIConvCharInputStream() throws {
        do {
            let filename = "\(testDataDir)/Test_UTF-8.xml"
            let fileUrl  = GetFileURL(filename: filename)

            nDebug(.In, "File URL: \"\(fileUrl.absoluteString)\"")
            guard let inputStream = MarkInputStream(url: fileUrl) else { XCTFail("Could not open file \"\(fileUrl.absoluteString)\""); return }
            nDebug(.None, "File Opened: \"\(fileUrl.absoluteString)\"")
            let encodingName = try hardGuess("UTF-8", inputStream)
            nDebug(.Out, "Encoding Name: \"\(encodingName)\"")
        }
        catch let e {
            XCTFail("ERROR: \(e)")
        }
    }

    func testSAXParser() throws {
        do {
            let filename = "\(testDataDir)/Test_UTF-8.xml"
            let fileUrl  = GetFileURL(filename: filename)

            nDebug(.None, "File URL: \"\(fileUrl)\"")
            guard let inputStream = MarkInputStream(url: fileUrl) else { XCTFail("Could not open file \"\(fileUrl)\""); return }

            let handler: SAXTestHandler = SAXTestHandler()
            let parser:  SAXParser      = try SAXParser(inputStream: inputStream, url: fileUrl, handler: handler)

            try parser.parse()
        }
        catch let e {
            XCTFail("ERROR: \(e.localizedDescription)")
        }
    }

    //    func testPerformanceExample() throws {
    //        // This is an example of a performance test case.
    //        self.measure {
    //            // Put the code you want to measure the time of here.
    //        }
    //    }
}
