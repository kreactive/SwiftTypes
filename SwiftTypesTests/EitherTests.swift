//
//  EitherTests.swift
//  SwiftTypes
//
//  Created by Antoine Palazzolo on 07/12/15.
//  Copyright © 2015 Antoine Palazzolo. All rights reserved.
//

import XCTest
import SwiftTypes

class EitherTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testInit() {        
        
        let left2 = Either<String,Int>("left")
        
        switch left2 {
        case .left(let value):
            XCTAssertEqual(value, "left")
        case .right(_):
            XCTFail("should be left value")
        }
        
        let right2 = Either<Int,String>("right")
        
        switch right2 {
        case .left(_):
            XCTFail("should be right value")
        case .right(let value):
            XCTAssertEqual(value, "right")
        }
        
    }
    func testGetters() {
        let left = Either<String,String>.left("left")
        XCTAssertNotNil(left.left)
        XCTAssertEqual(left.left, "left")
        XCTAssertNil(left.right)

        let right = Either<String,String>.right("right")
        XCTAssertNotNil(right.right)
        XCTAssertEqual(right.right, "right")
        XCTAssertNil(right.left)
    }

    func testFold() {
        let left = Either<Int,Int>.left(2)
        let folded = left.reduce(left: {String($0*2)}, right: {String($0)})
        XCTAssertEqual(folded, "4")
        
        let right = Either<Int,Int>.right(2)
        let rightFolded = right.reduce(left: {String($0)}, right: {String($0*2)})
        XCTAssertEqual(rightFolded, "4")
        
    }

}
