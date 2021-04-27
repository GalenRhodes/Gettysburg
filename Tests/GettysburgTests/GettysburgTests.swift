//
//  GettysburgTests.swift
//  GettysburgTests
//
//  Created by Galen Rhodes on 11/7/20.
//

import XCTest
import Rubicon
@testable import Gettysburg

class GettysburgTests: XCTestCase {

    let testDataDir: String = "Tests/GettysburgTests/TestData"

    override func setUpWithError() throws {}

    override func tearDownWithError() throws {}

    func testParser() throws {
        do {
            let filename = "\(testDataDir)/Test_UTF-8.xml"
            let fileUrl = GetFileURL(filename: filename)

            guard let strm = InputStream(url: fileUrl) else { throw StreamError.FileNotFound(description: fileUrl.absoluteString) }

            let parser = try SAXParser(inputStream: strm, url: fileUrl, handler: SAXTestHandler())

            try parser.parse()
        }
        catch let e {
            XCTFail("ERROR: \(e)")
        }
    }

    func testSAXSimpleIConvCharInputStream() throws {
        let filename = "\(testDataDir)/Test_UTF-8.xml"
        let fileUrl  = GetFileURL(filename: filename)

        guard let stream = InputStream(url: fileUrl) else { throw StreamError.FileNotFound(description: fileUrl.absoluteString) }
        let iConvStream = try SAXSimpleIConvCharInputStream(inputStream: stream, url: fileUrl, skipXmlDecl: false)
        iConvStream.open()
        var data: [CharPos] = []

        guard try iConvStream.append(to: &data, maxLength: 1000) > 0 else { throw StreamError.UnexpectedEndOfInput() }
        print("\(String(data.map { $0.char }))")
    }

    //    func testPerformanceExample() throws {
    //        // This is an example of a performance test case.
    //        self.measure {
    //            // Put the code you want to measure the time of here.
    //        }
    //    }
}
