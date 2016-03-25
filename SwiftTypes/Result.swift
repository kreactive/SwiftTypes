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
}