//
//  ResultTests.swift
//
//  Created by Antoine Palazzolo on 07/12/15.
//

import XCTest
import SwiftTypes
class ResultTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testMap() {
        let mapSuccess = Result(2).map {String($0)}
        
        switch mapSuccess {
        case .Success(let value):
            XCTAssertEqual("2", value)
        case .Failure(let error):
            XCTFail("should not be a failure \(error)")
        }
        
        
        let error = NSError(domain: "ResultTest", code: 1, userInfo: nil)
        let mapFailure = Result<Int>(error).map {String($0)}
        
        switch mapFailure {
        case .Success(let value):
            XCTFail("should be a failure \(value)")
        case .Failure(let errorType):
            let err = errorType as NSError
            XCTAssertEqual(err, error)
        }
    }

    func testFlatMap() {
        
        let error = NSError(domain: "ResultTest", code: 1, userInfo: nil)

        let flatMapSuccess = Result("2").flatMap { stringValue -> Result<Int> in
            if let intValue = Int(stringValue) {
                return Result(intValue)
            } else {
                return Result(error)
            }
        }
        
        switch flatMapSuccess {
        case .Success(let value):
            XCTAssertEqual(2, value)
        case .Failure(let error):
            XCTFail("should not be a failure \(error)")
        }
        
        
        
        let flatMapFailure = Result("not_an_int").flatMap { stringValue -> Result<Int> in
            if let intValue = Int(stringValue) {
                return Result(intValue)
            } else {
                return Result(error)
            }
        }
        
        switch flatMapFailure {
        case .Success(let value):
            XCTFail("should be a failure \(value)")
        case .Failure(let errorType):
            let err = errorType as NSError
            XCTAssertEqual(err, error)
        }
        
        let error2 = NSError(domain: "ResultTest", code: 2, userInfo: nil)
        let flatMapFailure2 = Result<String>(error2).flatMap { stringValue -> Result<Int> in
            if let intValue = Int(stringValue) {
                return Result(intValue)
            } else {
                return Result(error)
            }
        }
        
        switch flatMapFailure2 {
        case .Success(let value):
            XCTFail("should be a failure \(value)")
        case .Failure(let errorType):
            let err = errorType as NSError
            XCTAssertEqual(err, error2)
        }
    }
    
    func testGetter() {
        
        let success = Result(2)
        
        do {
            let value = try success.get()
            XCTAssertEqual(value, 2)
        } catch {
            XCTFail("should not be a failure \(error)")
        }
        
        let failureError = NSError(domain: "ResultTest", code: 1, userInfo: nil)
        let failure = Result<Int>(failureError).map {String($0)}
        
        do {
            let _ = try failure.get()
            XCTFail("should fail")
        } catch {
            XCTAssertEqual(error as NSError, failureError)
        }
        
    }
    
    func testInit() {
        
        let success = Result<Int> {
            return 2
        }
        
        switch success {
        case .Success(let value):
            XCTAssertEqual(2, value)
        case .Failure(let error):
            XCTFail("should not be a failure \(error)")
        }
        
        let error = NSError(domain: "ResultTest", code: 1, userInfo: nil)
        let failure = Result<Int> {
            throw error
        }
        
        switch failure {
        case .Success(let value):
            XCTFail("should be a failure \(value)")
        case .Failure(let errorType):
            let err = errorType as NSError
            XCTAssertEqual(err, error)
        }
        
    }
}
