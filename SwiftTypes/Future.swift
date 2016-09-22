//
//  Future.swift
//  SwiftTypes
//
//  Created by Antoine Palazzolo on 30/03/16.

import Foundation

private enum FutureState<T> {
    case inProgress
    case finished(Result<T>)
    case cancelled
}

public enum FutureError: Error {
    case cancelled
    case timeout
}

public protocol FutureType {
    associatedtype ResultType
    var canceled : Bool {get}
    func cancel()
    func result(_ handler : @escaping (Result<ResultType>) -> Void)
    func map<U>(_ transform : @escaping (ResultType) throws -> U) -> Future<U>
    func flatMap<U>(_ transform : @escaping (ResultType) throws -> Future<U>) -> Future<U>
    func get(timeout : TimeInterval?) -> Result<ResultType>
    func holdsMultipleHandlers() -> Bool
    func recover(_ recover : @escaping (Error) throws -> ResultType) -> Future<ResultType>
    func recoverWith(_ recover : @escaping (Error) throws -> Future<ResultType>) -> Future<ResultType>
    func fallback(_ to : ResultType) -> Future<ResultType>
    func dispatched(onQueue queue : DispatchQueue) -> Future<ResultType>
    func dispatched(onQueue queue : OperationQueue) -> Future<ResultType>
    func dispatched(afterDelay delay: TimeInterval, onQueue queue: DispatchQueue) -> Future<ResultType>
}
public extension FutureType {
    func map<U>(_ transform : @escaping (ResultType) throws -> U) -> Future<U> {
        return TransformedFuture(initialFuture: self, map : transform)
    }
    func flatMap<U>(_ transform : @escaping (ResultType) throws -> Future<U>) -> Future<U> {
        return FlatMappedFuture(initialFuture: self, map: transform)
    }
    func fallback(_ to : ResultType) -> Future<ResultType> {
        return self.recover {_ in to}
    }
    func recover(_ recover : @escaping (Error) throws -> ResultType) -> Future<ResultType> {
        return TransformedFuture(initialFuture: self, recover: recover)
    }
    func recoverWith(_ recover : @escaping (Error) throws -> Future<ResultType>) -> Future<ResultType> {
        return FlatMappedFuture(initialFuture: self, recover: recover)
    }
    func dispatched(onQueue queue : DispatchQueue) -> Future<ResultType> {
        return FutureDispatchedOnQueue(initial: self, dispatchQueue: queue)
    }
    func dispatched(onQueue queue : OperationQueue) -> Future<ResultType> {
        return FutureDispatchedOnQueue(initial: self, operationQueue: queue)
    }
    func dispatchedOnMain() -> Future<ResultType> {
        return self.dispatched(onQueue : DispatchQueue.main)
    }
    func dispatched(afterDelay delay: TimeInterval, onQueue queue: DispatchQueue) -> Future<ResultType> {
        return DelayedFuture(future: self, delay: delay, dispatchQueue: queue)
    }
}

public class Future<T> : FutureType {
    
    private var resultHandlers = Array<(Result<T>) -> Void>()
    private var successHandlers = Array<(T) -> Void>()
    private var failureHandlers = Array<(Error) -> Void>()
    
    public var canceled : Bool {
        self.stateLock.lock()
        defer {self.stateLock.unlock()}
        if case FutureState<T>.cancelled = self.state {
            return true
        }
        return false
    }
    
    private var state : FutureState<T> = .inProgress
    private var stateLock = NSLock()
    
    public func get(timeout : TimeInterval? = nil) -> Result<T> {
        let semaphore = DispatchSemaphore(value: 0)
        self.result { _ in semaphore.signal()}
        let timeout = timeout.map {
            DispatchTime.now() + Double(Int64(Double(NSEC_PER_SEC)*$0)) / Double(NSEC_PER_SEC)
        }
        let _ = semaphore.wait(timeout: timeout ?? DispatchTime.distantFuture)
        
        self.stateLock.lock()
        defer {self.stateLock.unlock()}
        
        switch self.state {
        case .cancelled:
            return Result(FutureError.cancelled)
        case .finished(let result):
            return result
        case .inProgress:
            return Result(FutureError.timeout)
        }
    }
    public func holdsMultipleHandlers() -> Bool {
        self.stateLock.lock()
        let result = self.resultHandlers.count + self.failureHandlers.count + self.successHandlers.count
        self.stateLock.unlock()
        return result > 1
    }
    
    public func cancel() {
        self.stateLock.lock()
        defer {self.stateLock.unlock()}
        guard case FutureState<T>.inProgress = self.state else {
            return
        }
        self.state = .cancelled
        self.dispatchResult(Result(FutureError.cancelled))
    }
    func completionHandler(_ result : Result<T>) {
        self.stateLock.lock()
        defer {self.stateLock.unlock()}
        guard case FutureState<T>.inProgress = self.state else {
            return
        }
        self.state = .finished(result)
        self.dispatchResult(result)
    }
    private func dispatchResult(_ result : Result<T>) {
        self.resultHandlers.forEach{$0(result)}
        switch result {
        case .failure(let error):
            self.failureHandlers.forEach{$0(error)}
        case .success(let value):
            self.successHandlers.forEach{$0(value)}
        }
        self.resultHandlers = []
        self.successHandlers = []
        self.failureHandlers = []
    }
    public func result(_ handler : @escaping (Result<T>) -> Void) {
        self.stateLock.lock()
        defer {self.stateLock.unlock()}
        
        switch self.state {
        case .cancelled:
            handler(Result(FutureError.cancelled))
        case .finished(let result):
            handler(result)
        case .inProgress:
            self.resultHandlers.append(handler)
        }
    }
    public func failure(_ handler : @escaping (Error) -> Void) {
        self.stateLock.lock()
        defer {self.stateLock.unlock()}
        
        switch self.state {
        case .finished(.success(_)):
            break
        case .cancelled:
            handler(FutureError.cancelled)
        case .finished(.failure(let error)):
            handler(error)
        case .inProgress:
            self.failureHandlers.append(handler)
        }
    }
    public func success(_ handler : @escaping (T) -> Void) {
        self.stateLock.lock()
        defer {self.stateLock.unlock()}
        
        switch self.state {
        case .cancelled,.finished(.failure(_)):
            break
        case .finished(.success(let value)):
            handler(value)
        case .inProgress:
            self.successHandlers.append(handler)
        }
    }
    public func copy() -> Future<T> {
        return self.map {$0}
    }
}

private class TransformedFuture<T,U : FutureType>: Future<T> {
    private let future : U
    override func cancel() {
        super.cancel()
        if !self.future.holdsMultipleHandlers() {
            self.future.cancel()
        }
    }
    init(initialFuture : U, transform : @escaping (Result<U.ResultType>) -> Result<T>) {
        self.future = initialFuture
        super.init()
        self.future.result {
            let transformed = transform($0)
            self.completionHandler(transformed)
        }
    }
    convenience init(initialFuture : U, map : @escaping (U.ResultType) throws -> T) {
        self.init(initialFuture : initialFuture) { (result : Result<U.ResultType>) in
            return result.wrappedMap(map)
        }
    }
}
extension TransformedFuture where T == U.ResultType {
    convenience init(initialFuture : U, recover : @escaping (Error) throws -> T) {
        self.init(initialFuture : initialFuture) { (result : Result<U.ResultType>) in
            return result.wrappedRecover(recover)
        }
    }
}

private class FlatMappedFuture<F : FutureType, T>: Future<T> {
    private let future : Future<Future<T>>
    
    private var next : Future<T>?
    private let futureLock = NSLock()
    
    override func cancel() {
        super.cancel()
        if !self.future.holdsMultipleHandlers() {
            self.future.cancel()
        }
        futureLock.lock()
        if let nextFuture = next, !nextFuture.holdsMultipleHandlers() {
            nextFuture.cancel()
        }
        futureLock.unlock()
    }
    init(initialFuture : F, transform : @escaping (Result<F.ResultType>) -> Result<Future<T>>) {
        self.future = TransformedFuture(initialFuture: initialFuture, transform: transform)
        super.init()
        self.future.result { nextFutureResult in
            switch nextFutureResult {
            case .success(let nextFuture):
                self.futureLock.lock()
                self.next = nextFuture
                self.futureLock.unlock()
                nextFuture.result {self.completionHandler($0)}
            case .failure(let error):
                self.completionHandler(Result(error))
            }
        }
    }
    convenience init(initialFuture : F, map : @escaping (F.ResultType) throws -> Future<T>) {
        self.init(initialFuture : initialFuture) { (result : Result<F.ResultType>) in
            return result.wrappedMap(map)
        }
    }
}

extension FlatMappedFuture where F.ResultType == T {
    convenience init(initialFuture : F, recover : @escaping (Error) throws -> Future<T>) {
        self.init(initialFuture : initialFuture) { (result : Result<F.ResultType>) in
            return result.wrappedReduce(success: Future.successful, failure: recover)
        }
    }
}

private class FutureURLDataTask : Future<(URLResponse,Data)> {
    override func cancel() {
        super.cancel()
        self.task.cancel()
    }
    private var task : URLSessionDataTask! = nil
    init(request : URLRequest, session : URLSession = URLSession.shared) {
        super.init()
        self.task = session.dataTask(with: request,completionHandler: self.taskCompletionHandler)
        self.task.resume()
    }
    init(url : URL, session : URLSession = URLSession.shared) {
        super.init()
        self.task = session.dataTask(with: url, completionHandler: self.taskCompletionHandler)
        self.task.resume()
    }
    private func taskCompletionHandler(_ data : Data?,response : URLResponse?, error : Error?) {
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
private class FutureFlattened<T : FutureType,S : Sequence> : Future<[T.ResultType]> where
  S.Iterator.Element == T {
    
    let source : S
    let group = DispatchGroup()
    private override func cancel() {
        super.cancel()
        self.source.forEach {
            if !$0.holdsMultipleHandlers() {$0.cancel()}
        }
    }
    init(source : S) {
        self.source = source
        super.init()
        self.source.forEach { f in
            self.group.enter()
            f.result { result in
                self.group.leave()
            }
        }
        self.group.notify(queue: DispatchQueue.global(qos: .default)) {
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
    init( dispatchQueue: DispatchQueue, operation : @escaping () throws -> T) {
        super.init()
        dispatchQueue.async {
            let result = Result<T> { try operation() }
            self.completionHandler(result)
        }
    }
    init(operationQueue: OperationQueue, operation : @escaping () throws -> T) {
        super.init()
        operationQueue.addOperation {
            let result = Result<T> { try operation() }
            self.completionHandler(result)
        }
    }
    init(afterDelay delay: TimeInterval, dispatchQueue: DispatchQueue, operation : @escaping () throws -> T) {
        super.init()
        let millis = Int(delay*1000)
        dispatchQueue.asyncAfter(deadline: DispatchTime.now()+DispatchTimeInterval.milliseconds(millis)) {
            if !self.canceled {
                let result = Result<T> { try operation() }
                self.completionHandler(result)
            }
        }
    }
}
private class FutureFinished<T> : Future<T> {
    init(result : Result<T>) {
        super.init()
        self.completionHandler(result)
    }
}


private class FutureDispatchedOnQueue<T : FutureType> : Future<T.ResultType> {
    init(initial : T, dispatchQueue: DispatchQueue) {
        super.init()
        initial.result { result in
            dispatchQueue.async {
                self.completionHandler(result)
            }
        }
    }
    init(initial : T, operationQueue: OperationQueue) {
        super.init()
        initial.result { result in
            operationQueue.addOperation {
                self.completionHandler(result)
            }
        }
    }
}

private class DelayedFuture<T : FutureType> : Future<T.ResultType> {
    init(future : T, delay : TimeInterval , dispatchQueue: DispatchQueue) {
        super.init()
        future.result { value in
            let delay = DispatchTime.now() + DispatchTimeInterval.milliseconds(Int(delay*1000.0))
            dispatchQueue.asyncAfter(deadline: delay) {
                self.completionHandler(value)
            }
        }
    }
}


public extension URLSession {
    func futureDataTaskWithRequest(_ request : URLRequest) -> Future<(URLResponse,Data)> {
        return FutureURLDataTask(request: request, session: self)
    }
    func futureDataTaskWithURL(_ url : URL) -> Future<(URLResponse,Data)> {
        return FutureURLDataTask(url: url, session: self)
    }
}

public extension Sequence where Iterator.Element : FutureType {
    var flattened : Future<[Iterator.Element.ResultType]> {
        return FutureFlattened(source: self)
    }
}

public extension Future {
    static func async(afterDelay delay: TimeInterval, dispatchQueue : DispatchQueue = DispatchQueue.global(), operation : @escaping () throws -> T)  -> Future<T> {
        return FutureDispatch(afterDelay: delay, dispatchQueue: dispatchQueue, operation: operation)
    }
    static func async(_ dispatchQueue : DispatchQueue = DispatchQueue.global(), operation : @escaping () throws -> T)  -> Future<T> {
        return FutureDispatch(dispatchQueue: dispatchQueue, operation: operation)
    }
    static func async(_ qosClass : DispatchQoS.QoSClass, operation : @escaping () throws -> T)  -> Future<T> {
        return self.async(DispatchQueue.global(qos: qosClass), operation: operation)
    }
    static func async(_ operationQueue : OperationQueue, operation : @escaping () throws -> T)  -> Future<T> {
        return FutureDispatch(operationQueue: operationQueue, operation: operation)
    }
    static func successful(_ result : T) -> Future<T> {
        return FutureFinished(result: Result(result))
    }
    static func failed(_ error : Error) -> Future<T> {
        return FutureFinished(result: Result(error))
    }
    static func withCompletionHandler(_ completionHandler : (@escaping (Result<T>) -> Void) -> Void) -> Future<T> {
        let result = Future<T>()
        completionHandler(result.completionHandler)
        return result
    }
}

