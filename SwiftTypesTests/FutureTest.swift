//
//  FutureTest.swift
//  SwiftTypes
//
//  Created by Antoine Palazzolo on 30/03/16.
//  Copyright © 2016 Antoine Palazzolo. All rights reserved.
//

import Foundation
import SwiftTypes
import XCTest


class FutureTests: XCTestCase {
    
    func testAsync_dispatch() {
        let expectation = self.expectationWithDescription("testAsync_dispatch")
        let future = Future.async(QOS_CLASS_DEFAULT) {
            NSThread.sleepForTimeInterval(0.1)
        }
        future.success {
            expectation.fulfill()
        }
        self.waitForExpectationsWithTimeout(0.3, handler: nil)
    }
    func testAsync_operationQueue() {
        let expectation = self.expectationWithDescription("testAsync_operationQueue")
        let operationQueue = NSOperationQueue()
        let future = Future.async(operationQueue) {
            NSThread.sleepForTimeInterval(0.1)
            XCTAssert(NSOperationQueue.currentQueue() == operationQueue)
        }
        future.success {
            expectation.fulfill()
        }
        self.waitForExpectationsWithTimeout(0.3, handler: nil)
    }
    func testGet() {
        
        let future = Future.async {2}
        XCTAssertEqual(2, try! future.get().get())
        
        let future2 = Future.async { () -> Int in
            NSThread.sleepForTimeInterval(0.2)
            return 2
        }
        XCTAssertEqual(2, try! future2.get().get())
        
        let futureCancelled = Future.async { () -> Int in
            NSThread.sleepForTimeInterval(0.2)
            return 2
        }
        futureCancelled.cancel()
        switch futureCancelled.get() {
        case .Success(_):
            XCTFail()
        case .Failure(let error):
            XCTAssert(FutureUtils.isCancelled(error))
        }
        
        
        let futureTimout = Future.async { () -> Int in
            NSThread.sleepForTimeInterval(0.3)
            return 2
        }
        switch futureTimout.get(timeout : 0.1) {
        case .Success(_):
            XCTFail()
        case .Failure(let error):
            XCTAssert(FutureUtils.isTimeout(error))
        }
    }
    func testFutureHandlers() {
        let t_error = NSError(domain: "errrr", code: 12, userInfo: nil)
        
        let future = Future.async { () -> Int in
            NSThread.sleepForTimeInterval(0.1)
            return 2
        }
        future.failure { _ in
            XCTFail()
        }
        let expectation = self.expectationWithDescription("testFailureHandler")
        let expectation_1 = self.expectationWithDescription("testFailureHandler_1")

        future.success { v in
            XCTAssertEqual(v, 2)
            expectation.fulfill()
        }
        future.result { r in
            switch r {
            case .Success(let v):
                XCTAssertEqual(v, 2)
            case .Failure(_):
                XCTFail()
            }
            expectation_1.fulfill()
        }
        self.waitForExpectationsWithTimeout(0.3, handler: nil)

        let future2 = Future.async {2}
        FutureUtils.waitForFutureToFinish(future2)
        future2.failure { _ in
            XCTFail()
        }
        let expectation2 = self.expectationWithDescription("testFailureHandler2")
        future2.success { _ in
            expectation2.fulfill()
        }
        self.waitForExpectationsWithTimeout(0.1, handler: nil)
        
        let futureFailure = Future.async { () -> Int in
            NSThread.sleepForTimeInterval(0.1)
            throw t_error
        }
        let expectation3 = self.expectationWithDescription("testFailureHandler3")
        futureFailure.success { _ in
            XCTFail()
        }
        futureFailure.failure { e in
            XCTAssertEqual(t_error, e as NSError)
            expectation3.fulfill()
        }
        self.waitForExpectationsWithTimeout(0.3, handler: nil)
 
        
        let futureFailure2 = Future.async { () -> Int in
            throw t_error
        }
        FutureUtils.waitForFutureToFinish(futureFailure2)
        let expectation4 = self.expectationWithDescription("testFailureHandler4")
        futureFailure2.success { _ in
            XCTFail()
        }
        futureFailure2.failure { e in
            XCTAssertEqual(t_error, e as NSError)
            expectation4.fulfill()
        }
        self.waitForExpectationsWithTimeout(0.3, handler: nil)
        
        
        let futureCancel = Future.async { () -> Int in
            NSThread.sleepForTimeInterval(0.1)
            return 2
        }
        futureCancel.cancel()
        let expectation5 = self.expectationWithDescription("testFailureHandler5")
        let expectation5_1 = self.expectationWithDescription("testFailureHandler5_1")

        futureCancel.success { _ in
            XCTFail()
        }
        futureCancel.failure { err in
            XCTAssert(FutureUtils.isCancelled(err))
            expectation5.fulfill()
        }
        futureCancel.result {
            switch $0 {
            case .Success(_):
                XCTFail()
            case .Failure(let er):
                XCTAssert(FutureUtils.isCancelled(er))
            }
            expectation5_1.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(0.3, handler: nil)
 
        
        let futureResult = Future.async { () -> Int in
            throw t_error
        }
        FutureUtils.waitForFutureToFinish(futureResult)
        let expectation6 = self.expectationWithDescription("testFailureHandler6")
        futureResult.result {
            switch $0 {
            case .Success(_):
                XCTFail()
            case .Failure(let e):
                XCTAssertEqual(t_error, e as NSError)
            }
            expectation6.fulfill()
        }
        self.waitForExpectationsWithTimeout(0.3, handler: nil)
        
    }
    
    func testCancelFinishedFuture() {
        let future = Future.async {
            2.0
        }
        FutureUtils.waitForFutureToFinish(future)
        XCTAssert(!future.canceled)
        //cancel finished future does nothing
        future.cancel()
        XCTAssert(!future.canceled)
    }
    
    func testFlattenedFuturesSuccess() {
        let flattened = FutureUtils.createFlattenedFuture123().flattened
        
        let expectation = self.expectationWithDescription("testFlattenedFuturesSuccess")
        
        flattened.success { result in
            XCTAssertEqual([1,2,3], result)
            expectation.fulfill()
        }
        self.waitForExpectationsWithTimeout(0.4, handler: nil)
    }
    func testFlattenedFuturesFailure() {
        let future1 = Future.async { () -> Int in
            NSThread.sleepForTimeInterval(0.02)
            return 1
        }
        let error = NSError(domain: "TestFlattenedFuturesFailure", code: 1, userInfo: nil)
        let future2 = Future.async { () -> Int in
            throw error
        }
        let future3 = Future.async { () -> Int in
            NSThread.sleepForTimeInterval(0.02)
            return 3
        }
        let flattened = [future1,future2,future3].flattened
        let expectation = self.expectationWithDescription("testFlattenedFuturesSuccess")
        
        flattened.failure { result in
            XCTAssertEqual(error, result as NSError)
            expectation.fulfill()
        }
        self.waitForExpectationsWithTimeout(0.3, handler: nil)
    }
    func testFlattenedFuturesCancelAfter() {
        let toFlatten = FutureUtils.createFlattenedFuture123()
        let flattened = toFlatten.flattened
        let expectation = self.expectationWithDescription("testFlattenedFuturesCancelAfter")
        
        flattened.failure { result in
            XCTAssert(FutureUtils.isCancelled(result))
            expectation.fulfill()
        }
        XCTAssert(!flattened.canceled)
        flattened.cancel()
        XCTAssert(flattened.canceled)
        toFlatten.forEach { XCTAssert($0.canceled) }
        self.waitForExpectationsWithTimeout(0.4, handler: nil)
    }
    func testFlattenedFuturesCancelBefore() {
        let toFlatten = FutureUtils.createFlattenedFuture123()
        let flattened = toFlatten.flattened
        let expectation = self.expectationWithDescription("testFlattenedFuturesCancelAfter")
        
        XCTAssert(!flattened.canceled)
        flattened.cancel()
        XCTAssert(flattened.canceled)
        toFlatten.forEach { XCTAssert($0.canceled) }
        flattened.failure { result in
            XCTAssert(FutureUtils.isCancelled(result))
            expectation.fulfill()
        }
        self.waitForExpectationsWithTimeout(0.4, handler: nil)
    }
    func testMap() {
        let future = Future.async { 2.0 }
        let mappedFuture = future.map { Int($0)*2 }
        let expectation = self.expectationWithDescription("testMap")
        mappedFuture.success {
            XCTAssertEqual($0,4)
            expectation.fulfill()
        }
        self.waitForExpectationsWithTimeout(0.05, handler: nil)
    }
    func testMapCancelBefore() {
        let future = Future.async {
            NSThread.sleepForTimeInterval(0.1)
            2.0
        }
        let mappedFuture = future.map {
            Int($0)*2
        }
        let expectation = self.expectationWithDescription("testMapCancelBefore")
        XCTAssert(!mappedFuture.canceled)
        XCTAssert(!future.canceled)
        mappedFuture.cancel()
        XCTAssert(mappedFuture.canceled)
        XCTAssert(future.canceled)
        
        mappedFuture.failure { result in
            XCTAssert(FutureUtils.isCancelled(result))
            expectation.fulfill()
        }
        self.waitForExpectationsWithTimeout(0.2, handler: nil)
    }
    func testMapCancelAfter() {
        let future = Future.async {
            NSThread.sleepForTimeInterval(0.1)
            2.0
        }
        let mappedFuture = future.map {
            Int($0)*2
        }
        let expectation = self.expectationWithDescription("testMapCancelBefore")
        mappedFuture.failure { result in
            XCTAssert(FutureUtils.isCancelled(result))
            expectation.fulfill()
        }
        XCTAssert(!mappedFuture.canceled)
        XCTAssert(!future.canceled)
        mappedFuture.cancel()
        XCTAssert(mappedFuture.canceled)
        XCTAssert(future.canceled)
        
        
        self.waitForExpectationsWithTimeout(0.2, handler: nil)
    }
    
    func testFlatMap() {
        let future = Future.async { () -> Float in
            NSThread.sleepForTimeInterval(0.1)
            return 2.0
        }.flatMap { v -> Future<Int> in
            return Future.async {Int(v)*2}
        }
        let expectation = self.expectationWithDescription("testFlatMap")
        future.success {
            XCTAssertEqual($0,4)
            expectation.fulfill()
        }
        self.waitForExpectationsWithTimeout(0.3, handler: nil)
    }
    func testFlatMap2() {
        let future = Future.async { () -> Float in
            NSThread.sleepForTimeInterval(0.1)
            return 2.0
        }
        let future2 = Future.async { () -> Float in
            NSThread.sleepForTimeInterval(0.3)
            return 2.0
        }
        
        let flatFuture = future.flatMap { v -> Future<Int> in
            return future2.map {Int($0*v)}
        }
        let expectation = self.expectationWithDescription("testFlatMap2")
        flatFuture.success {
            XCTAssertEqual($0,4)
            expectation.fulfill()
        }
        self.waitForExpectationsWithTimeout(0.4, handler: nil)
    }
    
    func testFlatMapCancel() {
        let future = Future.async { () -> Float in
            NSThread.sleepForTimeInterval(0.1)
            return 2.0
        }
        let flatFuture = future.flatMap { v -> Future<Int> in
            NSThread.sleepForTimeInterval(0.1)
            return Future.async {Int(v)*2}
        }
        future.cancel()
        XCTAssert(future.canceled)
        XCTAssert(!flatFuture.canceled)
        let expectation = self.expectationWithDescription("testFlatMap")
        flatFuture.failure {
            FutureUtils.isCancelled($0)
            expectation.fulfill()
        }
        self.waitForExpectationsWithTimeout(0.3, handler: nil)
    }
   
    
    
    func testFlatMapCancel2() {
        let future = Future.async { () -> Float in
            NSThread.sleepForTimeInterval(0.1)
            return 2.0
        }
        let flatFuture = future.flatMap { v -> Future<Int> in
            NSThread.sleepForTimeInterval(0.1)
            return Future.async {Int(v)*2}
        }
        flatFuture.cancel()
        XCTAssert(future.canceled)
        XCTAssert(flatFuture.canceled)
        let expectation = self.expectationWithDescription("testFlatMap")
        flatFuture.failure {
            FutureUtils.isCancelled($0)
            expectation.fulfill()
        }
        self.waitForExpectationsWithTimeout(0.3, handler: nil)
    }
    func testFlatMapCancel3() {
        let future = Future.async { () -> Float in
            NSThread.sleepForTimeInterval(0.1)
            return 2.0
        }
        let flatFuture = future.flatMap { v -> Future<Int> in
            NSThread.sleepForTimeInterval(0.1)
            return Future.async {Int(v)*2}
        }
        flatFuture.cancel()
        XCTAssert(future.canceled)
        XCTAssert(flatFuture.canceled)
        let expectation = self.expectationWithDescription("testFlatMap")
        flatFuture.failure {
            FutureUtils.isCancelled($0)
            expectation.fulfill()
        }
        self.waitForExpectationsWithTimeout(0.3, handler: nil)
    }
    
    func testURLTask() {
        let url = NSURL(string :"http://httpbin.org/get?test=coucou")!
        let future = NSURLSession.sharedSession().futureDataTaskWithURL(url)
        let expectation = self.expectationWithDescription("testURLTask")
        future.result {
            let check = FutureUtils.checkHTTPBinGetWithParams($0, params: ["test" : "coucou"])
            XCTAssert(check.0,check.1 ?? "")
            expectation.fulfill()
        }
        self.waitForExpectationsWithTimeout(10, handler: nil)
    }
    func testRequestURLTask() {
        let url = NSURL(string :"http://httpbin.org/get?test=coucou")!
        let request = NSURLRequest(URL: url)
        let future = NSURLSession.sharedSession().futureDataTaskWithRequest(request)
        
        let expectation = self.expectationWithDescription("testURLTask")
        future.result {
            let check = FutureUtils.checkHTTPBinGetWithParams($0, params: ["test" : "coucou"])
            XCTAssert(check.0,check.1 ?? "")
            expectation.fulfill()
        }
        self.waitForExpectationsWithTimeout(10, handler: nil)
    }
    func testURLTaskCancel() {
        let url = NSURL(string :"http://httpbin.org/get?test=coucou")!
        let future = NSURLSession.sharedSession().futureDataTaskWithURL(url)
        let expectation = self.expectationWithDescription("testURLTask")
        
        XCTAssert(!future.canceled)
        future.cancel()
        XCTAssert(future.canceled)
        
        future.failure {
            XCTAssert(FutureUtils.isCancelled($0))
            expectation.fulfill()
        }
        self.waitForExpectationsWithTimeout(0.5, handler: nil)
    }
    func testURLTaskFailure() {
        let url = NSURL(string :"http://adressdoesnotexistee.comf")!
        let future = NSURLSession.sharedSession().futureDataTaskWithURL(url)
        let expectation = self.expectationWithDescription("testURLTask")
        
        future.failure { err in
            expectation.fulfill()
        }
        self.waitForExpectationsWithTimeout(10.0, handler: nil)
    }
    
    
}
enum FutureUtils {
    static func checkHTTPBinGetWithParams(result :Result<(NSURLResponse,NSData)>,params :[String : [String]]) -> (Bool,String?) {
        switch result {
        case .Success(let r,let data):
            let response = r as! NSHTTPURLResponse
            guard 200...299 ~= response.statusCode else {
                return (false,"bad http status code \(response.statusCode)")
            }
            let json = try! NSJSONSerialization.JSONObjectWithData(data, options: []) as! [String : AnyObject]
            let args = json["args"] as! [String : AnyObject]
            
            for (key,value) in args {
                if let arrayValues = value as? [String] {
                    if arrayValues.sort() != (params[key] ?? []).sort() {
                        return (false, "invalid values for key \(key)")
                    }
                } else if let singleValue = value as? String {
                    guard let values = params[key] else {
                        return (false, "missing value for key \(key)")
                    }
                    if values.count > 1 || values.count == 0 {
                        return (false, "missing value for key \(key)")
                    }
                    if values.first! != singleValue {
                        return (false, "invalid value for key \(key)")
                    }
                } else {
                    return (false, "invalid response arg type")
                }
            }
            return (true, nil)
        case .Failure(let err):
            return (false,"\(err)")
        }
    }
    static func checkHTTPBinGetWithParams(result :Result<(NSURLResponse,NSData)>,params :[String : String]) -> (Bool,String?) {
        var p = [String : [String]]()
        
        params.forEach {
            p[$0.0] = [$0.1]
        }
        return self.checkHTTPBinGetWithParams(result, params: p)
    } 
    static func createFlattenedFuture123() -> [Future<Int>] {
        let future1 = Future.async { () -> Int in
            NSThread.sleepForTimeInterval(0.02)
            return 1
        }
        let future2 = Future.async { () -> Int in
            NSThread.sleepForTimeInterval(0.03)
            return 2
        }
        let future3 = Future.async { () -> Int in
            NSThread.sleepForTimeInterval(0.02)
            return 3
        }
        return [future1,future2,future3]
    }
    
    static func waitForFutureToFinish<T>(future : Future<T>) {
        let _ = future.get(timeout: 10.0)
    }
    static func isCancelled(error : ErrorType) -> Bool {
        if case FutureError.Cancelled = error {
            return true
        }
        return false
    }
    static func isTimeout(error : ErrorType) -> Bool {
        if case FutureError.Timeout = error {
            return true
        }
        return false
    }
}
