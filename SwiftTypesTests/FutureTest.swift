//
//  FutureTest.swift
//  SwiftTypes
//
//  Created by Antoine Palazzolo on 30/03/16.
//

import Foundation
import SwiftTypes
import XCTest


class FutureTests: XCTestCase {
    
    func testAsync_dispatch() {
        let expectation = self.expectation(description: "testAsync_dispatch")
        let future = Future.async(.default) {
            Thread.sleep(forTimeInterval: 0.1)
        }
        future.success { _ in
            expectation.fulfill()
        }
        self.waitForExpectations(timeout: 0.5, handler: nil)
    }
    func testAsync_operationQueue() {
        let expectation = self.expectation(description: "testAsync_operationQueue")
        let operationQueue = OperationQueue()
        let future = Future.async(operationQueue) {
            Thread.sleep(forTimeInterval: 0.1)
            XCTAssert(OperationQueue.current == operationQueue)
        }
        future.success { _ in
            expectation.fulfill()
        }
        self.waitForExpectations(timeout: 0.5, handler: nil)
    }
    func testGet() {
        
        let future = Future.async { () -> Int in
            Thread.sleep(forTimeInterval: 0.2)
            return 2
        }
        switch future.get(timeout: 10.0) {
        case .success(let result):
            XCTAssertEqual(result, 2)
        case .failure(let error):
            XCTFail("failed with error \(error)")
        }
        
        let futureCancelled = Future.async { () -> Int in
            Thread.sleep(forTimeInterval: 0.2)
            return 2
        }
        futureCancelled.cancel()
        switch futureCancelled.get() {
        case .success(_):
            XCTFail()
        case .failure(let error):
            XCTAssert(FutureUtils.isCancelled(error))
        }
        
        
        let futureTimout = Future.async { () -> Int in
            Thread.sleep(forTimeInterval: 0.3)
            return 2
        }
        switch futureTimout.get(timeout : 0.1) {
        case .success(_):
            XCTFail()
        case .failure(let error):
            XCTAssert(FutureUtils.isTimeout(error))
        }
    }
    func testGetFailed() {
        let error = NSError(domain: "testGetFailed", code: 1, userInfo: nil)
        let future = Future.async { () -> Int in
            Thread.sleep(forTimeInterval: 0.3)
            throw error
        }
        switch future.get(timeout: 10) {
        case .failure(let err):
            XCTAssertTrue((err as NSError).domain == error.domain, "should be throwed error, is \(err)")
        case .success(_):
            XCTFail("should be an error")
        }
    }
    func testGetInifinite() {
        let future = Future.async { () -> Int in
            Thread.sleep(forTimeInterval: 0.3)
            return 2
        }
        switch future.get() {
        case .failure(let err):
            XCTFail("failed with error \(err)")
        case .success(let result):
            XCTAssertEqual(2, result)
        }
        
    }
    func testFutureHandlers() {
        let t_error = NSError(domain: "errrr", code: 12, userInfo: nil)
        
        let future = Future.async { () -> Int in
            Thread.sleep(forTimeInterval: 0.1)
            return 2
        }
        future.failure { _ in
            XCTFail()
        }
        let expectation = self.expectation(description: "testFailureHandler")
        let expectation_1 = self.expectation(description: "testFailureHandler_1")

        future.success { v in
            XCTAssertEqual(v, 2)
            expectation.fulfill()
        }
        future.result { r in
            switch r {
            case .success(let v):
                XCTAssertEqual(v, 2)
            case .failure(_):
                XCTFail()
            }
            expectation_1.fulfill()
        }
        self.waitForExpectations(timeout: 0.3, handler: nil)

        let future2 = Future.async {2}
        FutureUtils.waitForFutureToFinish(future2)
        future2.failure { _ in
            XCTFail()
        }
        let expectation2 = self.expectation(description: "testFailureHandler2")
        future2.success { _ in
            expectation2.fulfill()
        }
        self.waitForExpectations(timeout: 0.1, handler: nil)
        
        let futureFailure = Future.async { () -> Int in
            Thread.sleep(forTimeInterval: 0.1)
            throw t_error
        }
        let expectation3 = self.expectation(description: "testFailureHandler3")
        futureFailure.success { _ in
            XCTFail()
        }
        futureFailure.failure { e in
            XCTAssertEqual(t_error, e as NSError)
            expectation3.fulfill()
        }
        self.waitForExpectations(timeout: 0.3, handler: nil)
 
        
        let futureFailure2 = Future.async { () -> Int in
            throw t_error
        }
        FutureUtils.waitForFutureToFinish(futureFailure2)
        let expectation4 = self.expectation(description: "testFailureHandler4")
        futureFailure2.success { _ in
            XCTFail()
        }
        futureFailure2.failure { e in
            XCTAssertEqual(t_error, e as NSError)
            expectation4.fulfill()
        }
        self.waitForExpectations(timeout: 0.3, handler: nil)
        
        
        let futureCancel = Future.async { () -> Int in
            Thread.sleep(forTimeInterval: 0.1)
            return 2
        }
        futureCancel.cancel()
        let expectation5 = self.expectation(description: "testFailureHandler5")
        let expectation5_1 = self.expectation(description: "testFailureHandler5_1")

        futureCancel.success { _ in
            XCTFail()
        }
        futureCancel.failure { err in
            XCTAssert(FutureUtils.isCancelled(err))
            expectation5.fulfill()
        }
        futureCancel.result {
            switch $0 {
            case .success(_):
                XCTFail()
            case .failure(let er):
                XCTAssert(FutureUtils.isCancelled(er))
            }
            expectation5_1.fulfill()
        }
        
        self.waitForExpectations(timeout: 0.3, handler: nil)
 
        
        let futureResult = Future.async { () -> Int in
            throw t_error
        }
        FutureUtils.waitForFutureToFinish(futureResult)
        let expectation6 = self.expectation(description: "testFailureHandler6")
        futureResult.result {
            switch $0 {
            case .success(_):
                XCTFail()
            case .failure(let e):
                XCTAssertEqual(t_error, e as NSError)
            }
            expectation6.fulfill()
        }
        self.waitForExpectations(timeout: 0.3, handler: nil)
        
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
        
        let expectation = self.expectation(description: "testFlattenedFuturesSuccess")
        
        flattened.success { result in
            XCTAssertEqual([1,2,3], result)
            expectation.fulfill()
        }
        self.waitForExpectations(timeout: 0.4, handler: nil)
    }
    func testFlattenedFuturesFailure() {
        let future1 = Future.async { () -> Int in
            Thread.sleep(forTimeInterval: 0.02)
            return 1
        }
        let error = NSError(domain: "TestFlattenedFuturesFailure", code: 1, userInfo: nil)
        let future2 = Future.async { () -> Int in
            throw error
        }
        let future3 = Future.async { () -> Int in
            Thread.sleep(forTimeInterval: 0.02)
            return 3
        }
        let flattened = [future1,future2,future3].flattened
        let expectation = self.expectation(description: "testFlattenedFuturesSuccess")
        
        flattened.failure { result in
            XCTAssertEqual(error, result as NSError)
            expectation.fulfill()
        }
        self.waitForExpectations(timeout: 0.3, handler: nil)
    }
    func testFlattenedFuturesCancelAfter() {
        let toFlatten = FutureUtils.createFlattenedFuture123()
        let flattened = toFlatten.flattened
        let expectation = self.expectation(description: "testFlattenedFuturesCancelAfter")
        
        flattened.failure { result in
            XCTAssert(FutureUtils.isCancelled(result))
            expectation.fulfill()
        }
        XCTAssert(!flattened.canceled)
        flattened.cancel()
        XCTAssert(flattened.canceled)
        toFlatten.forEach { XCTAssert($0.canceled) }
        self.waitForExpectations(timeout: 0.4, handler: nil)
    }
    func testFlattenedFuturesCancelBefore() {
        let toFlatten = FutureUtils.createFlattenedFuture123()
        let flattened = toFlatten.flattened
        let expectation = self.expectation(description: "testFlattenedFuturesCancelAfter")
        
        XCTAssert(!flattened.canceled)
        flattened.cancel()
        XCTAssert(flattened.canceled)
        toFlatten.forEach { XCTAssert($0.canceled) }
        flattened.failure { result in
            XCTAssert(FutureUtils.isCancelled(result))
            expectation.fulfill()
        }
        self.waitForExpectations(timeout: 0.4, handler: nil)
    }
    func testMap() {
        let future = Future.async { 2.0 }
        let mappedFuture = future.map { Int($0)*2 }
        let expectation = self.expectation(description: "testMap")
        mappedFuture.success {
            XCTAssertEqual($0,4)
            expectation.fulfill()
        }
        self.waitForExpectations(timeout: 0.05, handler: nil)
    }
    func testMapCancelBefore() {
        let future = Future<Double>.async {
            Thread.sleep(forTimeInterval: 0.1)
            return 2.0
        }
        let mappedFuture = future.map {
            Int($0)*2
        }
        let expectation = self.expectation(description: "testMapCancelBefore")
        XCTAssert(!mappedFuture.canceled)
        XCTAssert(!future.canceled)
        mappedFuture.cancel()
        XCTAssert(mappedFuture.canceled)
        XCTAssert(future.canceled)
        
        mappedFuture.failure { result in
            XCTAssert(FutureUtils.isCancelled(result))
            expectation.fulfill()
        }
        self.waitForExpectations(timeout: 0.2, handler: nil)
    }
    func testMapCancelAfter() {
        let future = Future<Double>.async {
            Thread.sleep(forTimeInterval: 0.1)
            return 2.0
        }
        let mappedFuture = future.map {
            Int($0)*2
        }
        let expectation = self.expectation(description: "testMapCancelBefore")
        mappedFuture.failure { result in
            XCTAssert(FutureUtils.isCancelled(result))
            expectation.fulfill()
        }
        XCTAssert(!mappedFuture.canceled)
        XCTAssert(!future.canceled)
        mappedFuture.cancel()
        XCTAssert(mappedFuture.canceled)
        XCTAssert(future.canceled)
        
        self.waitForExpectations(timeout: 0.2, handler: nil)
    }
    
    func testFlatMap() {
        let future = Future.async { () -> Float in
            Thread.sleep(forTimeInterval: 0.1)
            return 2.0
        }.flatMap { v -> Future<Int> in
            return Future.async {Int(v)*2}
        }
        let expectation = self.expectation(description: "testFlatMap")
        future.success {
            XCTAssertEqual($0,4)
            expectation.fulfill()
        }
        self.waitForExpectations(timeout: 0.3, handler: nil)
    }
    func testFlatMap2() {
        let future = Future.async { () -> Float in
            Thread.sleep(forTimeInterval: 0.1)
            return 2.0
        }
        let future2 = Future.async { () -> Float in
            Thread.sleep(forTimeInterval: 0.3)
            return 2.0
        }
        
        let flatFuture = future.flatMap { v -> Future<Int> in
            return future2.map {Int($0*v)}
        }
        let expectation = self.expectation(description: "testFlatMap2")
        flatFuture.success {
            XCTAssertEqual($0,4)
            expectation.fulfill()
        }
        self.waitForExpectations(timeout: 1.0, handler: nil)
    }
    
    func testFlatMapCancelFirst() {
        let future = Future.async { () -> Float in
            Thread.sleep(forTimeInterval: 0.1)
            return 2.0
        }
        let flatFuture = future.flatMap { v -> Future<Int> in
            Thread.sleep(forTimeInterval: 0.1)
            return Future.async {Int(v)*2}
        }
        future.cancel()
        XCTAssert(future.canceled)
        XCTAssert(!flatFuture.canceled)
        let expectation = self.expectation(description: "testFlatMap")
        flatFuture.failure {
            XCTAssert(FutureUtils.isCancelled($0))
            expectation.fulfill()
        }
        self.waitForExpectations(timeout: 0.3, handler: nil)
    }
   
    
    
    func testFlatMapCancel() {
        let future = Future.async { () -> Float in
            Thread.sleep(forTimeInterval: 0.1)
            return 2.0
        }
        let flatFuture = future.flatMap { v -> Future<Int> in
            Thread.sleep(forTimeInterval: 0.1)
            return Future.async {Int(v)*2}
        }
        flatFuture.cancel()
        XCTAssert(future.canceled)
        XCTAssert(flatFuture.canceled)
        let expectation = self.expectation(description: "testFlatMap")
        flatFuture.failure {
            XCTAssert(FutureUtils.isCancelled($0))
            expectation.fulfill()
        }
        self.waitForExpectations(timeout: 0.3, handler: nil)
    }
    func testFlatMapCancelSecond() {
        let expectation1 = self.expectation(description: "testFlatMapFirst")
        let future = Future.async { () -> Float in
            Thread.sleep(forTimeInterval: 0.1)
            expectation1.fulfill()
            return 2.0
        }
        let future2 = Future.async { () -> Int in
            Thread.sleep(forTimeInterval: 0.3)
            return 2
        }
        let flatFuture = future.flatMap { v -> Future<Int> in
            return future2
        }
        self.waitForExpectations(timeout: 0.5, handler: nil)
        flatFuture.cancel()
        XCTAssert(future.canceled == false)
        XCTAssert(future2.canceled == true)
        XCTAssert(flatFuture.canceled)
        let expectation = self.expectation(description: "testFlatMap")
        flatFuture.failure {
            XCTAssert(FutureUtils.isCancelled($0))
            expectation.fulfill()
        }
        self.waitForExpectations(timeout: 0.5, handler: nil)
    }
    
    func testURLTask() {
        let url = URL(string :"http://httpbin.org/get?test=coucou")!
        let future = URLSession.shared.futureDataTaskWithURL(url)
        let expectation = self.expectation(description: "testURLTask")
        future.result {
            let check = FutureUtils.checkHTTPBinGetWithParams($0, params: ["test" : "coucou"])
            XCTAssert(check.0,check.1 ?? "")
            expectation.fulfill()
        }
        self.waitForExpectations(timeout: 10, handler: nil)
    }
    func testRequestURLTask() {
        let url = URL(string :"http://httpbin.org/get?test=coucou")!
        let request = URLRequest(url: url)
        let future = URLSession.shared.futureDataTaskWithRequest(request)
        
        let expectation = self.expectation(description: "testURLTask")
        future.result {
            let check = FutureUtils.checkHTTPBinGetWithParams($0, params: ["test" : "coucou"])
            XCTAssert(check.0,check.1 ?? "")
            expectation.fulfill()
        }
        self.waitForExpectations(timeout: 10, handler: nil)
    }
    func testURLTaskCancel() {
        let url = URL(string :"http://httpbin.org/get?test=coucou")!
        let future = URLSession.shared.futureDataTaskWithURL(url)
        let expectation = self.expectation(description: "testURLTask")
        
        XCTAssert(!future.canceled)
        future.cancel()
        XCTAssert(future.canceled)
        
        future.failure {
            XCTAssert(FutureUtils.isCancelled($0))
            expectation.fulfill()
        }
        self.waitForExpectations(timeout: 0.5, handler: nil)
    }
    func testURLTaskFailure() {
        let url = URL(string :"http://adressdoesnotexistee.comf")!
        let future = URLSession.shared.futureDataTaskWithURL(url)
        let expectation = self.expectation(description: "testURLTask")
        
        future.failure { err in
            expectation.fulfill()
        }
        self.waitForExpectations(timeout: 10.0, handler: nil)
    }
    func testFinishedFuture()  {
        let futureOk = Future.successful(2)
        let expectation = self.expectation(description: "testFinishedFuture1")
        futureOk.success { v in
            XCTAssertEqual(2, v)
            expectation.fulfill()
        }
        self.waitForExpectations(timeout: 0, handler: nil)

        let error = NSError(domain: "", code: 1, userInfo: nil)
        let futureKO = Future<Int>.failed(error)
        let expectation2 = self.expectation(description: "testFinishedFuture2")
        futureKO.failure { err in
            XCTAssertEqual(error, err as NSError)
            expectation2.fulfill()
        }
        self.waitForExpectations(timeout: 0, handler: nil)
    }
    
    func testCancelWithMultipleHandlersMap() {
        let future = Future.async { () -> Float in
            Thread.sleep(forTimeInterval: 0.1)
            return 2.0
        }
        let expectation = self.expectation(description: "testCancelWithMultipleHandlersMap1")
        future.success { _ in
            expectation.fulfill()
        }
        let mapped = future.map { v -> Int in
            return Int(v)
        }
        
        let expectation2 = self.expectation(description: "testCancelWithMultipleHandlersMap2")
        mapped.failure { err in
            XCTAssert(FutureUtils.isCancelled(err))
            expectation2.fulfill()
        }
        mapped.cancel()
        XCTAssert(mapped.canceled)
        XCTAssert(!future.canceled)
        self.waitForExpectations(timeout: 0.5, handler: nil)
    }
    func testCancelWithMultipleHandlersFlatMap() {
        let future = Future.async { () -> Float in
            Thread.sleep(forTimeInterval: 0.1)
            return 2.0
        }
        let expectation = self.expectation(description: "testCancelWithMultipleHandlersFlatMap1")
        future.success { _ in
            expectation.fulfill()
        }
        let flatMapped = future.flatMap { v -> Future<Int> in
            Future.async { Int(v) }
        }
        
        let expectation2 = self.expectation(description: "testCancelWithMultipleHandlersFlatMap2")
        flatMapped.failure { err in
            XCTAssert(FutureUtils.isCancelled(err))
            expectation2.fulfill()
        }
        flatMapped.cancel()
        XCTAssert(flatMapped.canceled)
        XCTAssert(!future.canceled)
        self.waitForExpectations(timeout: 0.5, handler: nil)
    }
    func testCancelWithMultipleHandlersFlatten() {
        let futureList = FutureUtils.createFlattenedFuture123()
        let first = futureList.first!
        let last = futureList.last!
        precondition(first !== last)
        
        let expectation = self.expectation(description: "testCancelWithMultipleHandlersFlatten1")
        first.success { _ in
            expectation.fulfill()
        }
        let flattened = futureList.flattened
        
        let expectation2 = self.expectation(description: "testCancelWithMultipleHandlersFlatMap2")
        flattened.failure { err in
            XCTAssert(FutureUtils.isCancelled(err))
            expectation2.fulfill()
        }
        flattened.cancel()
        XCTAssert(flattened.canceled)
        XCTAssert(!first.canceled)
        XCTAssert(last.canceled)
        self.waitForExpectations(timeout: 0.5, handler: nil)
    }
    
    func testCopy() {
        let future = Future.async { () -> Float in
            Thread.sleep(forTimeInterval: 0.1)
            return 2.0
        }
        let copy = future.copy()
        XCTAssert(future !== copy)
    }
    func testCompletionHandlerConversion() {
        let asyncOperation : (@escaping (Int) -> Void) -> Void = { completionHandler in
            DispatchQueue.global(qos: .default).async {
                Thread.sleep(forTimeInterval: 0.1)
                completionHandler(2)
            }
        }
        
        
        
        let future = Future<Int>.withCompletionHandler { completionHandler in
            asyncOperation {
                completionHandler(Result($0))
            }
        }
        
        let expectation = self.expectation(description: "testCompletionHandlerConversion")
        future.success { result in
            XCTAssertEqual(result,2)
            expectation.fulfill()
        }
        self.waitForExpectations(timeout: 10.0, handler: nil)
        
    }
    
    func testRecover() {
        
        let expectation = self.expectation(description: "testRecover")
        let future = Future<Int>.async {
            Thread.sleep(forTimeInterval: 0.1)
            return 1
        }
        let recovered = future.fallback(2)
        recovered.success {v in
            XCTAssertEqual(v, 1)
            expectation.fulfill()
        }
        
        self.waitForExpectations(timeout: 0.5, handler: nil)
        
        
        let expectationFailure = self.expectation(description: "testRecoverFailure")
        let futureFailure = Future<Int>.async {
            Thread.sleep(forTimeInterval: 0.1)
            throw NSError(domain: "testRecover", code: 1, userInfo: nil)
        }
        
        let recoveredFailure = futureFailure.fallback(2)
        recoveredFailure.success {v in
            XCTAssertEqual(v, 2)
            expectationFailure.fulfill()
        }
        self.waitForExpectations(timeout: 0.6, handler: nil)
    }
    
    func testRecoverWith() {
        
        let expectation = self.expectation(description: "testRecover")
        let future = Future<Int>.async {
            Thread.sleep(forTimeInterval: 0.1)
            return 1
        }
        let recovered = future.recoverWith {_ in
            return Future<Int>.async {
                Thread.sleep(forTimeInterval: 0.1)
                return 2
            }
        }
        recovered.success {v in
            XCTAssertEqual(v, 1)
            expectation.fulfill()
        }
        
        self.waitForExpectations(timeout: 0.3, handler: nil)
        
        
        let expectationFailure = self.expectation(description: "testRecoverFailure")
        let futureFailure = Future<Int>.async {
            Thread.sleep(forTimeInterval: 0.1)
            throw NSError(domain: "testRecover", code: 1, userInfo: nil)
        }
        
        let recoveredFailure = futureFailure.recoverWith {_ in
            return Future<Int>.async {
                Thread.sleep(forTimeInterval: 0.1)
                return 2
            }
        }
        recoveredFailure.success {v in
            XCTAssertEqual(v, 2)
            expectationFailure.fulfill()
        }
        self.waitForExpectations(timeout: 0.6, handler: nil)
    }
    func testDispatched() {
        let executionQueue = OperationQueue()
        let dispatchQueue = OperationQueue()
        
        let future = Future<Int>.async(executionQueue) {
            XCTAssert(executionQueue === OperationQueue.current)
            Thread.sleep(forTimeInterval: 0.1)
            return 1
        }.dispatched(onQueue : dispatchQueue)
        
        let expectation = self.expectation(description: "testDispatched")
        future.result { _ in
            XCTAssert(dispatchQueue === OperationQueue.current)
            expectation.fulfill()
        }
        let expectation2 = self.expectation(description: "testDispatched2")
        future.success { _ in
            XCTAssert(dispatchQueue === OperationQueue.current)
            expectation2.fulfill()
        }
        
        self.waitForExpectations(timeout: 0.4, handler: nil)
    }
    func testDispatchedQueue() {
        let executionQueue = DispatchQueue.global(qos: .default)
        
        let future = Future<Int>.async(executionQueue) {
            XCTAssertFalse(Thread.isMainThread)
            Thread.sleep(forTimeInterval: 0.1)
            throw NSError(domain: "", code: 0, userInfo: nil)
        }.dispatchedOnMain()
        
        let expectation = self.expectation(description: "testDispatched")
        future.result { _ in
            XCTAssert(Thread.isMainThread)
            expectation.fulfill()
        }
        let expectation2 = self.expectation(description: "testDispatched2")
        future.failure { _ in
            XCTAssert(Thread.isMainThread)
            expectation2.fulfill()
        }
        
        self.waitForExpectations(timeout: 0.4, handler: nil)
    }
    func testRecoveredCanceledFutureBehavior() {
        
        let expectation = self.expectation(description: "testRecoveredCanceledFutureBehavior")
        let future = Future<Int>.async {
            Thread.sleep(forTimeInterval: 0.1)
            return 1
        }
        let recovered = future.fallback(2)
        recovered.cancel()
        recovered.failure {e in
            if case FutureError.cancelled = e {} else {
                XCTFail("cancelled future must not fallback")
            }
            expectation.fulfill()
        }
        self.waitForExpectations(timeout: 0.3, handler: nil)
    }
    func testRecoveredWith_CanceledFutureBehavior() {
        let expectation = self.expectation(description: "testRecoveredCanceledFutureBehavior")
        let future = Future<Int>.async {
            Thread.sleep(forTimeInterval: 0.1)
            return 1
        }
        let recovered = future.recoverWith {_ in 
            return Future<Int>.async {
                Thread.sleep(forTimeInterval: 0.1)
                return 1
            }
        }
        recovered.cancel()
        recovered.failure {e in
            if case FutureError.cancelled = e {} else {
                XCTFail("cancelled future must not fallback")
            }
            expectation.fulfill()
        }
        self.waitForExpectations(timeout: 0.3, handler: nil)
    }
    
    func testDelayedCallback() {
        let expectation = self.expectation(description: "testDelayedFuture")
        let future = Future.successful(3).dispatched(afterDelay : 1.0, onQueue : DispatchQueue.global(qos: .default))
        let startDate = Date()
        future.result { _ in
            let delay = -startDate.timeIntervalSinceNow
            XCTAssertEqual(delay, 1.0, accuracy: 0.2)
            expectation.fulfill()
        }
        
        self.waitForExpectations(timeout: 2, handler: nil)
    }
    func testDelayedCallbackCancel() {
        let expectation = self.expectation(description: "testDelayedFutureCanceled")
        let future = Future.successful(3).dispatched(afterDelay : 0.1, onQueue : DispatchQueue.global(qos: .default))
        let startDate = Date()
        future.result { _ in
            let delay = -startDate.timeIntervalSinceNow
            XCTAssertEqual(delay, 0.0, accuracy: 0.2)
            expectation.fulfill()
        }
        future.cancel()
        self.waitForExpectations(timeout: 2, handler: nil)
    }
    func testDelayedDispatch() {
        let expectation = self.expectation(description: "testDelayedDispatch")
        let startDate = Date()
        let _ = Future.async(afterDelay: 1.0) {
            let delay = -startDate.timeIntervalSinceNow
            XCTAssertEqual(delay, 1.0, accuracy: 0.2)
            expectation.fulfill()
        }
        self.waitForExpectations(timeout: 2, handler: nil)
    }
    func testDelayedDispatchCancel() {
        let expectation = self.expectation(description: "testDelayedDispatchCancel")
        let startDate = Date()
        let f = Future.async(afterDelay: 0.1) {
            XCTFail()
        }
        f.result { _ in
            let delay = -startDate.timeIntervalSinceNow
            XCTAssertEqual(delay, 0.0, accuracy: 0.2)
            expectation.fulfill()
        }
        f.cancel()
        self.waitForExpectations(timeout: 2, handler: nil)
    }
    
}
enum FutureUtils {
    static func checkHTTPBinGetWithParams(_ result :Result<(URLResponse,Data)>,params :[String : [String]]) -> (Bool,String?) {
        switch result {
        case .success(let r,let data):
            let response = r as! HTTPURLResponse
            guard 200...299 ~= response.statusCode else {
                return (false,"bad http status code \(response.statusCode)")
            }
            let json = try! JSONSerialization.jsonObject(with: data, options: []) as! [String : AnyObject]
            let args = json["args"] as! [String : AnyObject]
            
            for (key,value) in args {
                if let arrayValues = value as? [String] {
                    if arrayValues.sorted() != (params[key] ?? []).sorted() {
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
        case .failure(let err):
            return (false,"\(err)")
        }
    }
    static func checkHTTPBinGetWithParams(_ result :Result<(URLResponse,Data)>,params :[String : String]) -> (Bool,String?) {
        var p = [String : [String]]()
        
        params.forEach {
            p[$0.0] = [$0.1]
        }
        return self.checkHTTPBinGetWithParams(result, params: p)
    } 
    static func createFlattenedFuture123() -> [Future<Int>] {
        let future1 = Future.async { () -> Int in
            Thread.sleep(forTimeInterval: 0.02)
            return 1
        }
        let future2 = Future.async { () -> Int in
            Thread.sleep(forTimeInterval: 0.03)
            return 2
        }
        let future3 = Future.async { () -> Int in
            Thread.sleep(forTimeInterval: 0.02)
            return 3
        }
        return [future1,future2,future3]
    }
    
    static func waitForFutureToFinish<T>(_ future : Future<T>) {
        let _ = future.get(timeout: 10.0)
    }
    static func isCancelled(_ error : Error) -> Bool {
        if case FutureError.cancelled = error {
            return true
        }
        return false
    }
    static func isTimeout(_ error : Error) -> Bool {
        if case FutureError.timeout = error {
            return true
        }
        return false
    }
}

