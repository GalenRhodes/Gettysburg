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
        let fileName = "Tests/GettysburgTests/TestData/Test_UTF-32LE.xml"
        guard let stream = InputStream(fileAtPath: fileName) else { fatalError() }
        let handler = SAXTestHandler()
        let parser  = SAXParser(inputStream: stream, uri: "", handler: handler)
        try parser.parse()
    }

//    func testPerformanceExample() throws {
//        // This is an example of a performance test case.
//        self.measure {
//            // Put the code you want to measure the time of here.
//        }
//    }
}
