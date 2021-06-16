import XCTest

import GettysburgTests

var tests = [ XCTestCaseEntry ]()
tests += GettysburgTests.testSAXParser()
XCTMain(tests)
