//
//  Result.swift
//
//  Created by Antoine Palazzolo on 31/07/15.
//

import Foundation

public enum Result<T> {
    
    case success(T)
    case failure(Error)
    
    public init(_ value: T) {
        self = .success(value)
    }
    public init(_ value : Error) {
        self = .failure(value)
    }
    public init(_ value : () throws -> T) {
        do {
            self = try Result<T>(value())
        } catch {
            self = Result<T>(error)
        }
    }
    public func get() throws -> T {
        switch self {
        case .success(let value): return value;
        case .failure(let error): throw error;
        }
    }
    public func map<U>(_ transform : (T) throws -> U) rethrows -> Result<U> {
        switch self {
        case .success(let value): return try Result<U>(transform(value));
        case .failure(let error): return Result<U>(error);
        }
    }
    public func wrappedMap<U>(_ transform : (T) throws -> U) -> Result<U> {
        do {
            return try self.map(transform)
        } catch {
            return .failure(error)
        }
    }
    public func flatMap<U>(_ transform : (T) throws -> Result<U>) rethrows -> Result<U> {
        switch self {
        case .success(let value): return try transform(value)
        case .failure(let error): return Result<U>(error)
        }
    }
    public func wrappedFlatMap<U>(_ transform : (T) throws -> Result<U>) -> Result<U> {
        do {
            return try self.flatMap(transform)
        } catch {
            return .failure(error)
        }
    }
    public func transform<U>(success : (T) throws -> Result<U>, failure : (Error) throws -> Result<U>) rethrows -> Result<U> {
        switch self {
        case .success(let value): return try success(value)
        case .failure(let error): return try failure(error)
        }
    }
    public func reduce<U>(success : (T) throws -> U, failure : (Error) throws -> U) rethrows -> U {
        switch self {
        case .success(let value): return try success(value)
        case .failure(let error): return try failure(error)
        }
    }
    public func wrappedReduce<U>(success : (T) throws -> U, failure : (Error) throws -> U) -> Result<U> {
        switch self {
        case .success(let value): return Result<U> {try success(value)}
        case .failure(let error): return Result<U> {try failure(error)}
        }
    }
    public func recover(_ transform : (Error) throws -> T) rethrows -> T {
        switch self {
        case .success(let result):
            return result
        case .failure(let error):
            return try transform(error)
        }
    }
    public func wrappedRecover(_ transform : (Error) throws -> T) -> Result<T> {
        switch self {
        case .success(_):
            return self
        case .failure(let error):
            return Result {try transform(error) }
        }
    }
    
}

public extension Optional {
    public init(fromResult result : Result<Wrapped>) {
        switch result {
        case .success(let v):
            self = .some(v)
        case .failure(_):
            self = .none
        }
    }
}
