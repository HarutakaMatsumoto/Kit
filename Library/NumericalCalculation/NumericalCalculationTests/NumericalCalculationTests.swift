//
//  NumericalCalculationTests.swift
//  NumericalCalculationTests
//
//  Created by HarutakaMatsumoto on 2019/02/02.
//  Copyright © 2019 HarutakaMatsumoto. All rights reserved.
//

import XCTest
@testable import NumericalCalculation

class NumericalCalculationTests: XCTestCase {
    
    var matrix: Matrix<Int>!

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        matrix = Matrix(repeating: 2, rowCount: 4, columnCount: 5)
        
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        
    }

    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        print(matrix)
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
