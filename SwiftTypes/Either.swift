//
//  Either.swift
//
//  Created by Antoine Palazzolo on 31/07/15.
//

import Foundation

public enum Either<LeftType,RightType> {
    case Left(LeftType)
    case Right(RightType)
    
    public init(_ left : LeftType) {
        self = .Left(left)
    }
    public init(_ right : RightType) {
        self = .Right(right)
    }
    public var left : LeftType? {
        if case Either.Left(let val) = self {
            return val
        }
        return nil
    }
    public var right : RightType? {
        if case Either.Right(let val) = self {
            return val
        }
        return nil
    }
    public func fold<T>(leftF : (LeftType) throws -> T,_ rightF : (RightType) throws -> T) rethrows -> T {
        switch self {
        case .Left(let v): return try leftF(v)
        case .Right(let v): return try rightF(v)
        }
    }
}