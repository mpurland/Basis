//
//  Monoid.swift
//  Basis
//
//  Created by Robert Widmann on 9/10/14.
//  Copyright (c) 2014 TypeLift. All rights reserved.
//  Released under the MIT license.
//

/// Monoids are algebraic structures consisting of a set of elements, an associative binary operator
/// to combine two of those elements together, and a single specialized element called the identity 
/// (here, mempty) that respects the Monoid Laws:
///
/// - Closure    Composing two members of the set of elements yields another element still in that
///              set of elements.  This is much like addition over the integers where all the
///              numbers in the equation 1 + 1 = 2 are integers.  You would never, in a million 
///              years, expect it to produce a real or complex or any other type of number.  With
///
/// - Associativity    It does not matter which way you group your parenthesis when composing two
///                    members of the monoid's set.  Either way, the answer is the same.
///
/// - Identity    There is some element in the monoid's set of elements that, when composed
///               with other elements, doesn't alter their value.  Like 0 in addition of the
///               integers: 0 + 1 = 1 + 0 = 1
public protocol Monoid : Semigroup {
	/// The identity element of the Monoid.
	static var mzero : Self { get }
}

public func mconcat<S : Monoid>(t : [S]) -> S {
	return sconcat(S.mzero, t: t)
}

extension List : Monoid {
	public static var mzero : List<A> { return List() }
}

extension Array : Monoid {
	public static var mzero : [Element] { return [] }
}

extension All : Monoid {
	public static var mzero : All {
		return All(true)
	}
}

extension Any : Monoid {
	public static var mzero : Any {
		return Any(false)
	}
}

extension Dual : Monoid {
	public static var mzero : Dual<A> {
		return Dual(A.mzero)
	}
}

extension Endo : Monoid {
	public static var mzero : Endo<A> {
		return Endo(id)
	}
}

/// The `Monoid` of numeric types under addition.
public struct Sum<N : protocol<IntegerArithmeticType, IntegerLiteralConvertible>> : Monoid {
	public let value : () -> N
	
	public init(@autoclosure(escaping) _ x : () -> N) {
		value = x
	}
	
	public static var mzero : Sum<N> {
		return Sum(0)
	}
	
	public func op(other : Sum<N>) -> Sum<N> {
		return Sum(self.value() + other.value())
	}
}

/// The `Monoid` of numeric types under multiplication.
public struct Product<N : protocol<IntegerArithmeticType, IntegerLiteralConvertible>> : Monoid {
	public let value : () -> N
	
	public init(@autoclosure(escaping) _ x : () -> N) {
		value = x
	}
	
	public static var mzero : Product<N> {
		return Product(1)
	}
	
	public func op(other : Product<N>) -> Product<N> {
		return Product(self.value() * other.value())
	}
}

/// The `Semigroup`-lifting `Optional` `Monoid`
public struct AdjoinNil<A : Semigroup> : Monoid {
	public let value : () -> Optional<A>
	
	public init(@autoclosure(escaping) _ x : () -> Optional<A>) {
		value = x
	}
	
	public static var mzero : AdjoinNil<A> {
		return AdjoinNil(nil)
	}
	
	public func op(other : AdjoinNil<A>) -> AdjoinNil<A> {
		if let x = self.value() {
			if let y = other.value() {
				return AdjoinNil(.Some(x.op(y)))
			} else {
				return self
			}
		} else {
			return other
		}
	}
}

/// The left-biased `Optional` `Monoid`
public struct First<A : Comparable> : Monoid {
	public let getFirst : () -> Optional<A>
	
	public init(@autoclosure(escaping) _ x : () -> Optional<A>) {
		getFirst = x
	}
	
	public static var mzero : First<A> {
		return First(.None)
	}
	
	public func op(other : First<A>) -> First<A> {
		if self.getFirst() != nil {
			return self
		} else {
			return other
		}
	}
}

/// The right-biased `Optional` `Monoid`.
public struct Last<A : Comparable> : Monoid {
	public let getLast : () -> Optional<A>
	
	public init(@autoclosure(escaping) _ x : () -> Optional<A>) {
		getLast = x
	}
	
	public static var mzero : Last<A> {
		return Last(.None)
	}
	
	public func op(other : Last<A>) -> Last<A> {
		if other.getLast() != nil {
			return other
		} else {
			return self
		}
	}
}

/// The coproduct of `Monoid`s
public struct Dither<A : Monoid, B : Monoid> : Monoid {
	public let values : [Either<A, B>]
	
	public init(_ vs : [Either<A, B>]) {
		//	if vs.isEmpty {
		//		error("Cannot construct a \(Vacillate<A, B>.self) with no elements.")
		//	}
		var vals = [Either<A, B>]()
		for v in vs {
			if let z = vals.last {
				switch (z, v) {
				case let (.Left(x), .Left(y)): vals[vals.endIndex - 1] = Either.Left(x.op(y))
				case let (.Right(x), .Right(y)): vals[vals.endIndex - 1] = Either.Right(x.op(y))
				default: vals.append(v)
				}
			} else {
				vals = [v]
			}
		}
		self.values = vals
	}
	
	public static func left(x: A) -> Dither<A, B> {
		return Dither([Either.Left(x)])
	}
	
	public static func right(y: B) -> Dither<A, B> {
		return Dither([Either.Right(y)])
	}
	
	public func fold<C : Monoid>(onLeft f : A -> C, onRight g : B -> C) -> C {
		return values.reduce(C.mzero) { acc, v in either(f)(g)(v).op(acc) }
	}
	
	public static var mzero : Dither<A, B> {
		return Dither([])
	}
	
	public func op(other : Dither<A, B>) -> Dither<A, B> {
		return Dither(values + other.values)
	}
	
	public init(_ other: Vacillate<A, B>) {
		self.init(other.values)
	}
}

/// MARK: Equatable

public func ==<A : protocol<Equatable, Monoid>>(lhs : Dual<A>, rhs : Dual<A>) -> Bool {
	return lhs.getDual == rhs.getDual
}

public func !=<A : protocol<Equatable, Monoid>>(lhs: Dual<A>, rhs: Dual<A>) -> Bool {
	return !(lhs == rhs)
}

public func ==(lhs : All, rhs : All) -> Bool {
	return lhs.getAll == rhs.getAll
}

public func !=(lhs: All, rhs: All) -> Bool {
	return !(lhs == rhs)
}

public func ==(lhs : Any, rhs : Any) -> Bool {
	return lhs.getAny == rhs.getAny
}

public func !=(lhs: Any, rhs: Any) -> Bool {
	return !(lhs == rhs)
}

public func ==<A : Equatable>(lhs : First<A>, rhs : First<A>) -> Bool {
	return lhs.getFirst() == rhs.getFirst()
}

public func !=<A : Equatable>(lhs: First<A>, rhs: First<A>) -> Bool {
	return !(lhs == rhs)
}

public func ==<A : Equatable>(lhs : Last<A>, rhs : Last<A>) -> Bool {
	return lhs.getLast() == rhs.getLast()
}

public func !=<A : Equatable>(lhs: Last<A>, rhs: Last<A>) -> Bool {
	return !(lhs == rhs)
}

public func ==<A : protocol<Comparable, Bounded, Equatable>>(lhs : Max<A>, rhs : Max<A>) -> Bool {
	return lhs.getMax() == rhs.getMax()
}

public func !=<A : protocol<Comparable, Bounded, Equatable>>(lhs: Max<A>, rhs: Max<A>) -> Bool {
	return !(lhs == rhs)
}

public func ==<A : protocol<Comparable, Bounded, Equatable>>(lhs : Min<A>, rhs : Min<A>) -> Bool {
	return lhs.getMin() == rhs.getMin()
}

public func !=<A : protocol<Comparable, Bounded, Equatable>>(lhs: Min<A>, rhs: Min<A>) -> Bool {
	return !(lhs == rhs)
}

public func ==<T : protocol<IntegerArithmeticType, IntegerLiteralConvertible, Equatable>>(lhs: Sum<T>, rhs: Sum<T>) -> Bool {
	return lhs.value() == rhs.value()
}

public func !=<T : protocol<IntegerArithmeticType, IntegerLiteralConvertible, Equatable>>(lhs: Sum<T>, rhs: Sum<T>) -> Bool {
	return !(lhs == rhs)
}

public func ==<T : protocol<IntegerArithmeticType, IntegerLiteralConvertible, Equatable>>(lhs: Product<T>, rhs: Product<T>) -> Bool {
	return lhs.value() == rhs.value()
}

public func !=<T : protocol<IntegerArithmeticType, IntegerLiteralConvertible, Equatable>>(lhs: Product<T>, rhs: Product<T>) -> Bool {
	return !(lhs == rhs)
}

