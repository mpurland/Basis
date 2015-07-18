//
//  String.swift
//  Basis
//
//  Created by Robert Widmann on 9/14/14.
//  Copyright (c) 2014 TypeLift. All rights reserved.
//  Released under the MIT license.
//

extension String {
	public func unpack() -> [Character] {
		return Array(self.characters)
	}
	
	public func destructure() -> ArrayMatcher<Character> {
		return match(unpack())
	}
}

/// Packs an array of characters into a String.
public func pack(x : [Character]) -> String {
	return String(x)
}

/// Unpacks a string into an array of characters.
public func unpack(s : String) -> [Character] {
	return Array(s.characters)
}
