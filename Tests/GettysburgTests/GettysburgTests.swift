//
//  GettysburgTests.swift
//  GettysburgTests
//
//  Created by Galen Rhodes on 11/7/20.
//

import XCTest
@testable import Gettysburg

class GettysburgTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testStart() throws {
        let fileName = "Tests/GettysburgTests/TestData/Test_UTF-16BE.xml"
        let handler = SAXTestHandler()
        if let parser  = SAXParser(fileAtPath: fileName, handler: handler) {
            try parser.parse()
        }
        else {
            XCTFail("Unable to open file \"\(fileName)\".")
        }
    }

//    func testPerformanceExample() throws {
//        // This is an example of a performance test case.
//        self.measure {
//            // Put the code you want to measure the time of here.
//        }
//    }
}
