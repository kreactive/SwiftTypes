//
//  Future.swift
//  SwiftTypes
//
//  Created by Antoine Palazzolo on 30/03/16.
//  Copyright © 2016 Antoine Palazzolo. All rights reserved.
//
//
//  Future.swift
//  testFuture
//
//  Created by Antoine Palazzolo on 29/03/16.
//  Copyright © 2016 Kreactive. All rights reserved.
//

import Foundation

private enum FutureState<T> {
    case InProgress
    case Finished(Result<T>)
    case Cancelled
}

public enum FutureError: ErrorType {
    case Cancelled
    case Timeout
}

public protocol FutureType {
    associatedtype ResultType
    var canceled : Bool {get}
    func cancel()
    func result(handler : Result<ResultType> -> Void)
    func failure(handler : ErrorType -> Void)
    func success(handler : ResultType -> Void)
    func map<U>(transform : ResultType throws -> U) -> Future<U>
    func flatMap<U>(transform : ResultType throws -> Future<U>) -> Future<U>
    func get(timeout timeout : NSTimeInterval?) -> Result<ResultType>
}
public extension FutureType {
    func map<U>(transform : ResultType throws -> U) -> Future<U> {
        return MappedFuture(initialFuture: self, transform: transform)
    }
    func flatMap<U : FutureType>(transform : ResultType throws -> U) -> Future<U.ResultType> {
        return FlatMappedFuture(initialFuture: self, transform: transform)
    }
}

public class Future<T> : FutureType {
    
    private var resultHandlers = Array<Result<T> -> Void>()
    private var successHandlers = Array<T -> Void>()
    private var failureHandlers = Array<ErrorType -> Void>()
    
    public var canceled : Bool {
        self.stateLock.lock()
        defer {self.stateLock.unlock()}
        if case FutureState<T>.Cancelled = self.state {
            return true
        }
        return false
    }
    
    private var state : FutureState<T> = .InProgress
    private var stateLock = NSLock()
    
    public func get(timeout timeout : NSTimeInterval? = nil) -> Result<T> {
        let semaphore = dispatch_semaphore_create(0)
        self.result { _ in dispatch_semaphore_signal(semaphore)}
        let timeout = timeout.map(UInt64.init) ?? DISPATCH_TIME_FOREVER
        dispatch_semaphore_wait(semaphore, timeout)
        
        self.stateLock.lock()
        defer {self.stateLock.unlock()}
        
        switch self.state {
        case .Cancelled:
            return Result(FutureError.Cancelled)
        case .Finished(let result):
            return result
        case .InProgress:
            return Result(FutureError.Timeout)
        }
    }
    
    public func cancel() {
        self.stateLock.lock()
        defer {self.stateLock.unlock()}
        guard case FutureState<T>.InProgress = self.state else {
            return
        }
        self.state = .Cancelled
        self.dispatchResult(Result(FutureError.Cancelled))
    }
    func completionHandler(result : Result<T>) {
        self.stateLock.lock()
        defer {self.stateLock.unlock()}
        guard case FutureState<T>.InProgress = self.state else {
            return
        }
        self.state = .Finished(result)
        self.dispatchResult(result)
    }
    private func dispatchResult(result : Result<T>) {
        self.resultHandlers.forEach{$0(result)}
        switch result {
        case .Failure(let error):
            self.failureHandlers.forEach{$0(error)}
        case .Success(let value):
            self.successHandlers.forEach{$0(value)}
        }
        self.resultHandlers = []
        self.successHandlers = []
        self.failureHandlers = []
    }
    public func result(handler : Result<T> -> Void) {
        self.stateLock.lock()
        defer {self.stateLock.unlock()}
        
        switch self.state {
        case .Cancelled:
            handler(Result(FutureError.Cancelled))
        case .Finished(let result):
            handler(result)
        case .InProgress:
            self.resultHandlers.append(handler)
        }
    }
    public func failure(handler : ErrorType -> Void) {
        self.stateLock.lock()
        defer {self.stateLock.unlock()}
        
        switch self.state {
        case .Finished(.Success(_)):
            break
        case .Cancelled:
            handler(FutureError.Cancelled)
        case .Finished(.Failure(let error)):
            handler(error)
        case .InProgress:
            self.failureHandlers.append(handler)
        }
    }
    public func success(handler : T -> Void) {
        self.stateLock.lock()
        defer {self.stateLock.unlock()}
        
        switch self.state {
        case .Cancelled,.Finished(.Failure(_)):
            break
        case .Finished(.Success(let value)):
            handler(value)
        case .InProgress:
            self.successHandlers.append(handler)
        }
    }
    
}

private class MappedFuture<T,U : FutureType>: Future<T> {
    private let future : U
    override func cancel() {
        super.cancel()
        self.future.cancel()
    }
    init(initialFuture : U, transform : U.ResultType throws -> T) {
        self.future = initialFuture
        super.init()
        self.future.result {
            self.completionHandler($0.wrappedMap(transform))
        }
    }
}
private class FlatMappedFuture<T : FutureType,U : FutureType>: Future<T.ResultType> {
    private let initial : U
    private var next : T?
    
    private let futureLock = NSLock()
    
    override func cancel() {
        super.cancel()
        self.futureLock.lock()
        defer {self.futureLock.unlock()}
        self.initial.cancel()
        self.next?.cancel()
    }
    
    init(initialFuture : U, transform : U.ResultType throws -> T) {
        self.initial = initialFuture
        super.init()
        self.initial.result { result in           
            let nextR = result.wrappedMap(transform)
            switch nextR {
            case .Failure(let error):
                self.completionHandler(Result(error))
            case .Success(let value):
                self.futureLock.lock()
                self.next = value
                self.futureLock.unlock()
                value.result {
                    self.completionHandler($0)
                }
            }
        }
    }
}

private class FutureURLDataTask : Future<(NSURLResponse,NSData)> {
    override func cancel() {
        super.cancel()
        self.task.cancel()
    }
    private var task : NSURLSessionDataTask! = nil
    init(request : NSURLRequest, session : NSURLSession = NSURLSession.sharedSession()) {
        super.init()
        self.task = session.dataTaskWithRequest(request,completionHandler: self.taskCompletionHandler)
        self.task.resume()
    }
    init(url : NSURL, session : NSURLSession = NSURLSession.sharedSession()) {
        super.init()
        self.task = session.dataTaskWithURL(url, completionHandler: self.taskCompletionHandler)
        self.task.resume()
    }
    private func taskCompletionHandler(data : NSData?,response : NSURLResponse?, error : NSError?) {
        if let error = error {
            self.completionHandler(Result(error))
            return
        }
        guard let response = response, let data = data else {
            //should be unreachable
            let error = NSError(domain: "URLDataTaskFutureDomain", code: 1, userInfo: ["debug" : "no data or response from datatasks"])
            self.completionHandler(Result(error))
            return
        }
        self.completionHandler(Result((response,data)))
    }
}
private class FutureFlattened<T : FutureType,S : SequenceType where S.Generator.Element == T> : Future<[T.ResultType]> {
    let source : S
    let group = dispatch_group_create()
    private override func cancel() {
        super.cancel()
        self.source.forEach {$0.cancel()}
    }
    init(source : S) {
        self.source = source
        super.init()
        self.source.forEach { f in
            dispatch_group_enter(self.group)
            f.result { result in
                dispatch_group_leave(self.group)
            }
        }
        dispatch_group_notify(self.group, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0)) {
            do {
                let result = try self.source.map {try $0.get(timeout : nil).get()}
                self.completionHandler(Result(result))
            } catch {
                self.completionHandler(Result(error))
            }
        }
    }
}
private class FutureDispatch<T> : Future<T> {
    init( dispatchQueue: dispatch_queue_t, operation : () throws -> T) {
        super.init()
        dispatch_async(dispatchQueue) {
            let result = Result<T> { try operation() }
            self.completionHandler(result)
        }
    }
    init(operationQueue: NSOperationQueue, operation : () throws -> T) {
        super.init()
        operationQueue.addOperationWithBlock {
            let result = Result<T> { try operation() }
            self.completionHandler(result)
        }
    }
}



public extension NSURLSession {
    func futureDataTaskWithRequest(request : NSURLRequest) -> Future<(NSURLResponse,NSData)> {
        return FutureURLDataTask(request: request, session: self)
    }
    func futureDataTaskWithURL(url : NSURL) -> Future<(NSURLResponse,NSData)> {
        return FutureURLDataTask(url: url, session: self)
    }
}

public extension SequenceType where Generator.Element : FutureType {
    var flattened : Future<[Generator.Element.ResultType]> {
        return FutureFlattened(source: self)
    }
}

public extension Future {
    static func async(dispatchQueue : dispatch_queue_t = dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), operation : () throws -> T)  -> Future<T> {
        return FutureDispatch(dispatchQueue: dispatchQueue, operation: operation)
    }
    static func async(qosClass : dispatch_qos_class_t, operation : () throws -> T)  -> Future<T> {
        let dispatchQueue = dispatch_get_global_queue(qosClass, 0)
        return self.async(dispatchQueue, operation: operation)
    }
    static func async(operationQueue : NSOperationQueue, operation : () throws -> T)  -> Future<T> {
        return FutureDispatch(operationQueue: operationQueue, operation: operation)
    }
}

