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
    func testWrappedMap() {
        let success = Result(2.0)
        let wrappedSuccess = success.wrappedMap {Int($0)+2}
        switch wrappedSuccess {
        case .Success(let v):
            XCTAssertEqual(v, 4)
        case .Failure(let errorType):
            XCTFail("should be a success \(errorType)")
        }
        
        let error = NSError(domain: "ResultTest", code: 1, userInfo: nil)
        let wrappedFailure = success.wrappedMap {_ in throw error}
        switch wrappedFailure {
        case .Success(_):
            XCTFail("should be a failure")
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
    
    func testWrappedFlatMap() {
        let success = Result(2.0)
        let wrappedSuccess = success.wrappedFlatMap {_ in Result(2)}
        switch wrappedSuccess {
        case .Success(let v):
            XCTAssertEqual(v, 2)
        case .Failure(let errorType):
            XCTFail("should be a success \(errorType)")
        }
        
        let error = NSError(domain: "ResultTest", code: 1, userInfo: nil)
        let wrappedFailure = success.wrappedFlatMap {_ -> Result<Int> in throw error}
        switch wrappedFailure {
        case .Success(_):
            XCTFail("should be a failure")
        case .Failure(let errorType):
            let err = errorType as NSError
            XCTAssertEqual(err, error)
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
    func testTransform() {
        
        let success = Result(2.0)
        
        let transformedSuccess = success.transform(success : { value in
            Result(Int(value))
        }, failure : { error in
            Result(error)
        })
        
        switch transformedSuccess {
        case .Success(let value):
            XCTAssertEqual(2, value)
        case .Failure(let error):
            XCTFail("should not be a failure \(error)")
        }
        
        
        let error = NSError(domain: "ResultTest", code: 1, userInfo: nil)
        let error2 = NSError(domain: "ResultTest", code: 2, userInfo: nil)
        let failure = Result<Int> {throw error}

        let transformedFailure = failure.transform(success : { value in
            Result(value)
        }, failure : { error in
            Result(error2)
        })
        
        switch transformedFailure {
        case .Success(_):
            XCTFail("should be a failure")
        case .Failure(let errorType):
            let err = errorType as NSError
            XCTAssertEqual(error2, err)
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
    func testFold() {
        let success = Result<Double> {
            return 2.0
        }
        let foldedS = success.fold(success: {v in Int(v)}, failure: {_ in 4})
        XCTAssert(try! foldedS.get() == 2)
        
        let error = Result<Double> {
            throw NSError(domain: "testFold", code: 1, userInfo: nil)
        }
        let foldedE = error.fold(success: {v in Int(v)}, failure: {_ in 4})
        XCTAssert(try! foldedE.get() == 4)
        
        
        let wsuccess = Result<Double> {
            return 2.0
        }
        let wfoldedS = wsuccess.wrappedFold(success: {v in Int(v)}, failure: {_ in 4})
        XCTAssert(try! wfoldedS.get() == 2)
        
        let werror = Result<Double> {
            throw NSError(domain: "testFold", code: 1, userInfo: nil)
        }
        let wfoldedE = werror.wrappedFold(success: {v in Int(v)}, failure: {_ in 4})
        XCTAssert(try! wfoldedE.get() == 4)
    }
    func testRecover() {
        let success = Result<Double> {
            return 2.0
        }
        let recoveredS = success.recover {_ in 4}
        XCTAssert(try! recoveredS.get() == 2)
        
        let error = Result<Double> {
            throw NSError(domain: "testFold", code: 1, userInfo: nil)
        }
        let recoveredE = error.recover {_ in 4}
        XCTAssert(try! recoveredE.get() == 4)
        
        
        let wsuccess = Result<Double> {
            return 2.0
        }
        let wrecoveredS = wsuccess.wrappedRecover {_ in 4}
        XCTAssert(try! wrecoveredS.get() == 2)
        
        let werror = Result<Double> {
            throw NSError(domain: "testFold", code: 1, userInfo: nil)
        }
        let wrecoveredE = werror.wrappedRecover {_ in 4}
        XCTAssert(try! wrecoveredE.get() == 4)
        
    }
    func testToOptional() {
        let success = Result<Int> {
            return 2
        }
        let optSuccess = Optional(fromResult : success)
        if let v = optSuccess {
            XCTAssertEqual(v,2)
        } else {
            XCTFail()
        }
        
        let failure = Result<Int> {
            throw NSError(domain: "ResultTest", code: 1, userInfo: nil)
        }
        let optFailure = Optional(fromResult : failure)
        XCTAssertEqual(optFailure, nil)

    }
}
