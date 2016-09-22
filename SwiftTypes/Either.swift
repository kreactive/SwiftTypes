//
//  Either.swift
//
//  Created by Antoine Palazzolo on 31/07/15.
//

import Foundation

public enum Either<LeftType,RightType> {
    case left(LeftType)
    case right(RightType)
    
    public init(_ left : LeftType) {
        self = .left(left)
    }
    public init(_ right : RightType) {
        self = .right(right)
    }
    public var left : LeftType? {
        if case Either.left(let val) = self {
            return val
        }
        return nil
    }
    public var right : RightType? {
        if case Either.right(let val) = self {
            return val
        }
        return nil
    }
    public func reduce<T>(left : (LeftType) throws -> T,right : (RightType) throws -> T) rethrows -> T {
        switch self {
        case .left(let v): return try left(v)
        case .right(let v): return try right(v)
        }
    }
}
