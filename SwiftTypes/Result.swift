//
//  Result.swift
//
//  Created by Antoine Palazzolo on 31/07/15.
//

import Foundation

public enum Result<T> {
    
    case Success(T)
    case Failure(ErrorType)
    
    public init(_ value: T) {
        self = .Success(value)
    }
    public init(_ value : ErrorType) {
        self = .Failure(value)
    }
    public init(@noescape _ value : () throws -> T) {
        do {
            self = try Result<T>(value())
        } catch {
            self = Result<T>(error)
        }
    }
    public func get() throws -> T {
        switch self {
        case .Success(let value): return value;
        case .Failure(let error): throw error;
        }
    }
    public func map<U>(@noescape transform : T throws -> U) rethrows -> Result<U> {
        switch self {
        case .Success(let value): return try Result<U>(transform(value));
        case .Failure(let error): return Result<U>(error);
        }
    }
    public func wrappedMap<U>(@noescape transform : T throws -> U) -> Result<U> {
        do {
            return try self.map(transform)
        } catch {
            return .Failure(error)
        }
    }
    public func flatMap<U>(@noescape transform : T throws -> Result<U>) rethrows -> Result<U> {
        switch self {
        case .Success(let value): return try transform(value)
        case .Failure(let error): return Result<U>(error)
        }
    }
    public func wrappedFlatMap<U>(@noescape transform : T throws -> Result<U>) -> Result<U> {
        do {
            return try self.flatMap(transform)
        } catch {
            return .Failure(error)
        }
    }
    public func transform<U>(@noescape success success : T throws -> Result<U>, @noescape failure : ErrorType throws -> Result<U>) rethrows -> Result<U> {
        switch self {
        case .Success(let value): return try success(value)
        case .Failure(let error): return try failure(error)
        }
    }
    public func fold<U>(@noescape success success : T throws -> U, @noescape failure : ErrorType throws -> U) rethrows -> Result<U> {
        switch self {
        case .Success(let value): return try Result<U>.Success(success(value))
        case .Failure(let error): return try Result<U>.Success(failure(error))
        }
    }
    public func wrappedFold<U>(@noescape success success : T throws -> U, @noescape failure : ErrorType throws -> U) -> Result<U> {
        switch self {
        case .Success(let value): return Result<U> {try success(value)}
        case .Failure(let error): return Result<U> {try failure(error)}
        }
    }
    public func recover(@noescape transform : ErrorType throws -> T) rethrows -> Result<T> {
        switch self {
        case .Success(_):
            return self
        case .Failure(let error):
            return try Result(transform(error))
        }
    }
    public func wrappedRecover(@noescape transform : ErrorType throws -> T) -> Result<T> {
        switch self {
        case .Success(_):
            return self
        case .Failure(let error):
            return Result {try transform(error) }
        }
    }
    
}

public extension Optional {
    public init(fromResult result : Result<Wrapped>) {
        switch result {
        case .Success(let v):
            self = .Some(v)
        case .Failure(_):
            self = .None
        }
    }
}