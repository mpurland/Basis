//
//  Map.swift
//  Basis
//
//  Created by Robert Widmann on 9/16/14.
//  Copyright (c) 2014 TypeLift. All rights reserved.
//  Released under the MIT license.
//

public enum MapD<K, A> {
	case Empty
	case Destructure(UInt, K, A, Map<K, A>!, Map<K, A>!)
}

/// An immutable map between keys and values.
public final class Map<K, A> : K2<K, A> {
	let size : UInt
	let k : K!
	let a : A!
	let l : Map<K, A>!
	let r : Map<K, A>!

	init(_ size : UInt, _ k : K!, _ a : A!, _ l : Map<K, A>!, _ r : Map<K, A>!) {
		self.size = size
		self.k = k
		self.a = a
		self.l = l
		self.r = r
	}

	public func match() -> MapD<K, A> {
		if self.size == 0 || k == nil || a == nil {
			return .Empty
		}
		return .Destructure(size, k, a, l, r)
	}
}

/// Produces an empty map.
public func empty<K, A>() -> Map<K, A> {
	return Map<K, A>(0, nil, nil, nil, nil)
}

/// Produces a map with one key-value pair.
public func singleton<K, A>(key : K) -> A -> Map<K, A> {
	return { val in Map<K, A>(1, key, val, nil, nil) }
}

/// Builds a map from an association list.
///
/// This function is left-biased in that if there are multiple keys for one value, only the last is
/// retained.
public func fromArray<K : Comparable, A>(xs : [(K, A)]) -> Map<K, A> {
	return foldl({ insert(fst($1))(snd($1))($0) })(empty())(xs)
}

/// Builds an association list from a map.
public func toArray<K, A>(m : Map<K, A>) -> [(K, A)] {
	return foldrWithKey({ k in
		return { x in
			return { l in
				return (k, x) <| l
			}
		}
	})([])(m)
}

/// Inserts a new key-value pair and returns a new map.
///
/// This function is left-biased in that it will replace any old value in the map with the new given
/// value if the two keys are the same.
public func insert<K : Comparable, A>(key : K) -> A -> Map<K, A> -> Map<K, A> {
	return { val in { m in
		switch m.match() {
			case .Empty:
				return singleton(key)(val)
			case .Destructure(let sz, let ky, let y, let l, let r):
				if key < ky {
					return balance(ky)(x: y)(l: insert(key)(val)(l))(r: r)
				} else if key > ky {
					return balance(ky)(x: y)(l: l)(r: insert(key)(val)(r))
				}
				return Map(sz, key, val, l, r)
		}
	} }
}

/// Inserts a new key-value pair after applying a function to the new value and old value and
/// returns a new map.
///
/// If a value does not exist for a given key, this function inserts a new key-value pair and
/// returns a new map.  If the a value does exist, the function will be called with the old and new
/// values for that key, and the key-value pair of the key and the result of the function call is
/// inserted.
public func insertWith<K : Comparable, A>(f : A -> A -> A) -> K -> A -> Map<K, A> -> Map<K, A> {
	return { key in { val in { m in
		return insertWithKey({ _ in { x in { y in f(x)(y) } } })(key)(val)(m)
	} } }
}

/// Inserts a new key-value pair after applying a function to the key, new value, and old value and
/// returns a new map.
///
/// If a value does not exist for a given key, this function inserts a new key-value pair and
/// returns a new map.  If the a value does exist, the function will be called with the key, and the
/// old and new values for that key, and the key-value pair of the key and the result of the
/// function call is inserted.
public func insertWithKey<K : Comparable, A>(f : K -> A -> A -> A) -> K -> A -> Map<K, A> -> Map<K, A> {
	return { key in { val in { m in
		switch m.match() {
			case .Empty:
				return singleton(key)(val)
			case .Destructure(let sy, let ky, let y, let l, let r):
				if key < ky {
					return balance(ky)(x: y)(l: insertWithKey(f)(key)(val)(l))(r: r)
				} else if key > ky {
					return balance(ky)(x: y)(l: l)(r: insertWithKey(f)(key)(val)(r))
				}
				return Map(sy, key, (f(key)(val)(y)), l, r)
		}
	} } }
}

/// Deletes a key and its associated value from the map and returns a new map.
///
/// If the key does not exist in the map, it is returned unmodified.
public func delete<K : Comparable, A>(k : K) -> Map<K, A> -> Map<K, A> {
	return { m in
		switch m.match() {
			case .Empty:
				return empty()
			case .Destructure(_, let kx, let x, let l, let r):
				if k < kx {
					return balance(kx)(x: x)(l: delete(k)(m))(r: r)
				} else if k > kx {
					return balance(kx)(x: x)(l: l)(r: delete(k)(m))
				}
				return glue(l, r: r)
		}
	}
}

/// Finds and deletes the minimal element in a map of ordered keys.
///
/// This function is partial with respect to empty maps.
public func deleteFindMin<K, A>(m : Map<K, A>) -> ((K, A), Map<K, A>) {
	switch m.match() {
		case .Empty:
			return error("Cannot delete the minimal element of an empty map.")
		case .Destructure(_, let k, let x, let l, let r):
			switch l.match() {
				case .Empty:
					return ((k, x), r)
				case .Destructure(_, _, _, _, _):
					let (km, l1) = deleteFindMin(l)
					return (km, balance(k)(x: x)(l: l1)(r: r))
			}
	}
}

/// Finds and deletes the maximal element in a map of ordered keys.
///
/// This function is partial with respect to empty maps.
public func deleteFindMax<K, A>(m : Map<K, A>) -> ((K, A), Map<K, A>) {
	switch m.match() {
		case .Empty:
			return error("Cannot delete the maximal element of an empty map.")
		case .Destructure(_, let k, let x, let l, let r):
			switch l.match() {
				case .Empty:
					return ((k, x), r)
				case .Destructure(_, _, _, _, _):
					let (km, r1) = deleteFindMin(l)
					return (km, balance(k)(x: x)(l: l)(r: r1))
			}
	}
}

/// Balancing based on unoptimized algorithm in Data.Map.Base
/// http://www.haskell.org/ghc/docs/7.8.3/html/libraries/containers-0.5.5.1/src/Data-Map-Base.html#balance
/// which is, in turn, based on the paper
/// http://groups.csail.mit.edu/mac/users/adams/BB/
private func balance<K, A>(k : K)(x : A)(l : Map<K, A>)(r : Map<K, A>) -> Map<K, A> {
	if l.size + r.size <= 1 {
		return Map(l.size + r.size + 1, k, x, l, r)
	} else if r.size > l.size * 3 {
		return rotateL(k)(x: x)(l: l)(r: r)
	} else if l.size > r.size * 3 {
		return rotateR(k)(x: x)(l: l)(r: r)
	}
	return Map(l.size + r.size, k, x, l, r)
}

private func rotateL<K, A>(k : K)(x : A)(l : Map<K, A>)(r : Map<K, A>) -> Map<K, A> {
	switch r.match() {
	case .Empty:
		return error("")
	case .Destructure(_, _, _, let ly, let ry):
		if ly.size < 2 * ry.size {
			return single(k)(x1: x)(t1: l)(t2: r)
		}
		return double(k)(x1: x)(t1: l)(t2: r)
	}
}

private func rotateR<K, A>(k : K)(x : A)(l : Map<K, A>)(r : Map<K, A>) -> Map<K, A> {
	switch l.match() {
	case .Empty:
		return error("")
	case .Destructure(_, _, _, let ly, let ry):
		if ly.size < 2 * ry.size {
			return single(k)(x1: x)(t1: l)(t2: r)
		}
		return double(k)(x1: x)(t1: l)(t2: r)
	}
}

private func single<K, A>(k1 : K)(x1 : A)(t1 : Map<K, A>)(t2 : Map<K, A>) -> Map<K, A> {
	switch t2.match() {
	case .Empty:
		switch t1.match() {
		case .Empty:
			return error("")
		case .Destructure(_, let k2, let x2, let t1, let t3):
			return bin(k2, x: x2, l: t1, r: bin(k1, x: x1, l: t3, r: t2))
		}
	case .Destructure(_, let k2, let x2, let t2, let t3):
		return bin(k2, x: x2, l: bin(k1, x: x1, l: t1, r: t2), r: t3)
	}
}

private func double<K, A>(k1 : K)(x1 : A)(t1 : Map<K, A>)(t2 : Map<K, A>) -> Map<K, A> {
	switch t2.match() {
	case .Empty:
		switch t1.match() {
		case .Empty:
			return error("")
		case .Destructure(_, let k2, let x2, let b, let t4):
			switch b.match() {
			case .Empty:
				return error("")
			case .Destructure(_, let k3, let x3, let t2, let t3):
				return bin(k3, x: x3, l: bin(k2, x: x2, l: t1, r: t2), r: bin(k1, x: x1, l: t3, r: t4))
			}
		}
	case .Destructure(_, let k2, let x2, let b, let t4):
		switch b.match() {
		case .Empty:
			return error("")
		case .Destructure(_, let k3, let x3, let t2, let t3):
			return bin(k3, x: x3, l: bin(k1, x: x1, l: t1, r: t2), r: bin(k2, x: x2, l: t3, r: t4))
		}
	}
}

private func glue<K, A>(l : Map<K, A>, r : Map<K, A>) -> Map<K, A> {
	if l.size == 0 {
		return r
	}
	if r.size == 0 {
		return l
	}

	if l.size > r.size {
		let ((km, m), l1) = deleteFindMax(l)
		return balance(km)(x: m)(l: l1)(r: r)
	}
	let ((km, m), r1) = deleteFindMin(r)
	return balance(km)(x: m)(l: l)(r: r1)
}

private func bin<K, A>(k : K, x : A, l : Map<K, A>, r : Map<K, A>) -> Map<K, A> {
	return Map(l.size + r.size + 1, k, x, l, r)
}
