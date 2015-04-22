//
//  Mapper.swift
//  ObjectMapper
//
//  Created by Tristan Himmelman on 2014-10-09.
//  Copyright (c) 2014 hearst. All rights reserved.
//

import Foundation

public protocol Mappable {
	init?(_ map: Map)
	mutating func mapping(map: Map)
}

public enum MappingType {
	case FromJSON
	case ToJSON
}

/**
* A class used for holding mapping data
*/
public final class Map {
	public let mappingType: MappingType

	var JSONDictionary: [String : AnyObject] = [:]
	var currentValue: AnyObject?
	var currentKey: String?

	/// Counter for failing cases of deserializing values to `let` properties.
	private var failedCount: Int = 0

	private init(mappingType: MappingType, JSONDictionary: [String : AnyObject]) {
		self.mappingType = mappingType
		self.JSONDictionary = JSONDictionary
	}
	
	/**
	* Sets the current mapper value and key.
	* 
	* The Key paramater can be a period separated string (ex. "distance.value") to access sub objects.
	*/
	public subscript(key: String) -> Map {
		// save key and value associated to it
		currentKey = key
		// break down the components of the key
		currentValue = valueFor(key.componentsSeparatedByString("."), JSONDictionary)
		
		return self
	}

	// MARK: Immutable Mapping

	public func value<T>() -> T? {
		return currentValue as? T
	}

	public func valueOr<T>(@autoclosure defaultValue: () -> T) -> T {
		return value() ?? defaultValue()
	}

	/// Returns current JSON value of type `T` if it is existing, or returns a
	/// unusable proxy value for `T` and collects failed count.
	public func valueOrFail<T>() -> T {
		if let value: T = value() {
			return value
		} else {
			// Collects failed count
			failedCount++

			// Returns dummy memory as a proxy for type `T`
			let pointer = UnsafeMutablePointer<T>.alloc(0)
			pointer.dealloc(0)
			return pointer.memory
		}
	}

	/// Returns whether the receiver is success or failure.
	public var isValid: Bool {
		return failedCount == 0
	}
}

/**
* Fetch value from JSON dictionary, loop through them until we reach the desired object.
*/
private func valueFor(keyPathComponents: [String], dictionary: [String : AnyObject]) -> AnyObject? {
	// Implement it as a tail recursive function.

	if keyPathComponents.isEmpty {
		return nil
	}

	if let object: AnyObject = dictionary[keyPathComponents.first!] {
		switch object {
		case is NSNull:
			return nil

		case let dict as [String : AnyObject] where keyPathComponents.count > 1:
			let tail = Array(keyPathComponents[1..<keyPathComponents.count])
			return valueFor(tail, dict)

		default:
			return object
		}
	}

	return nil
}

/*
* Specifies the JSON type tag
*	ContractDataJson - "__type"
*	JsonDotNetJson   - "$type"
*	Custom
*/
public enum JsonSerializationTypeTag {
	case Default, ContractDataJson, JsonDotNetJson
	case Custom(String)
}

/**
* The MappableInfo class provides convenience methods for configuring polymorphic support in
* the JSON serialization/deserialization framework
*/
public final class MappableInfo<T: Mappable> {
	/** A generated hashable key per-T, allowing storage of per-type information in a Dictionary */
	private static var objId: ObjectIdentifier {
		return ObjectIdentifier(T.self)
	}
	
	/** This method is independent from <T>. It's here only to avoid defining yet another type */
	public static func reset() {
		MapperBase.reset()
	}
	
	/** This method is independent from <T>. It's here only to avoid defining yet another type */
	public static func setJsonSerializationTypeTag(style: JsonSerializationTypeTag) {
		MapperBase.jsonStyle = style
	}
	
	/**
	This method associates the native type T with the passed in jsonTypeName. 
	On deserialization the occurrence of jsonTypeName in a "$type"/"__type" field is treated as an
	indication to create an instance of <T>.
	On serialization, instances of type <T> will include a "$type"/"__type" field in their JSON
	representation.
	*/
	public static func configure(jsonTypeName: String) {
		MapperBase.factories[jsonTypeName] = { map in T(map) as Mappable? }
		MapperBase.native2jsonTypeName[objId] = jsonTypeName
	}

	internal static func getFactory(jsonTypeName: String) -> (Map -> Mappable?)? {
		return MapperBase.factories[jsonTypeName]
	}

	internal static func getJsonTypeNameFromType(nativeType: T.Type) -> String? {
		return MapperBase.native2jsonTypeName[ObjectIdentifier(nativeType)]
	}
	
	internal static func getJsonSerializationTypeTag() -> String {
		switch MapperBase.jsonStyle {
		case .Default:
			fallthrough
		case .ContractDataJson:
			return "__type"
		case .JsonDotNetJson:
			return "$type"
		case .Custom(let tag):
			return tag
		}
	}
}

/*
* MapperBase is an internal type that stores the common Mapper<> configuration. This is a non-generic
* class that allows for its fields to be shared across all the generic Mapper instances. This
* architecture enables deserialization of heterogeneous class hierarchies without the need for 
* extending the Mappable protocol, or for passing this metadata in each call, and then somehow
* propagating it as the deserialization proceeds
*/
public class MapperBase {
	internal static var jsonStyle: JsonSerializationTypeTag = .Default
	internal static var factories: [String : Map -> Mappable?] = [:]
	internal static var native2jsonTypeName: [ObjectIdentifier : String] = [:]
	internal static func reset() {
		jsonStyle = .Default
		factories = [:]
		native2jsonTypeName = [:]
	}
}

/**
* The Mapper class provides methods for converting Model objects to JSON and methods for converting JSON to Model objects
*/
public final class Mapper<N: Mappable>: MapperBase {

	public override init() {

	}
	
	// MARK: Mapping functions that map to an existing object toObject
	
	/**
	* Map a JSON string onto an existing object
	*/
	public func map(JSONString: String, var toObject object: N) -> N {
		if let JSON = parseJSONDictionary(JSONString) {
			return map(JSON, toObject: object)
		}
		return object
	}
	
	/**
	* Maps a JSON object to an existing Mappable object if it is a JSON dictionary, or returns the passed object as is
	*/
	public func map(JSON: AnyObject?, var toObject object: N) -> N {
		if let JSON = JSON as? [String : AnyObject] {
			return map(JSON, toObject: object)
		}
		
		return object
	}
	
	/**
	* Maps a JSON dictionary to an existing object that conforms to Mappable.
	* Usefull for those pesky objects that have crappy designated initializers like NSManagedObject
	*/
	public func map(JSONDictionary: [String : AnyObject], var toObject object: N) -> N {
		let map = Map(mappingType: .FromJSON, JSONDictionary: JSONDictionary)
		object.mapping(map)
		return object
	}

	//MARK: Mapping functions that create an object
	
	/**
	* Map a JSON string to an object that conforms to Mappable
	*/
	public func map(JSONString: String) -> N? {
		if let JSON = parseJSONDictionary(JSONString) {
			return map(JSON)
		}
		return nil
	}

	/**
	* Maps a JSON object to a Mappable object if it is a JSON dictionary, or returns nil.
	*/
	public func map(JSON: AnyObject?) -> N? {
		if let JSON = JSON as? [String : AnyObject] {
			return map(JSON)
		}

		return nil
	}

	/**
	* Maps a JSON dictionary to an object that conforms to Mappable
	*/
	public func map(JSONDictionary: [String : AnyObject]) -> N? {
		let map = Map(mappingType: .FromJSON, JSONDictionary: JSONDictionary)
		var object: N?
		if let jsonTypeName = getJsonTypeName(JSONDictionary) {
			object = MappableInfo<N>.getFactory(jsonTypeName)?(map) as! N?
		}
		if object == nil {
			object = N(map)
		}
		return object
	}

	//MARK: Mapping functions for Arrays and Dictionaries
	
	/**
	* Maps a JSON array to an object that conforms to Mappable
	*/
	public func mapArray(JSONString: String) -> [N] {
		let parsedJSON: AnyObject? = parseJSONString(JSONString)

		if let objectArray = mapArray(parsedJSON) {
			return objectArray
		}

		// failed to parse JSON into array form
		// try to parse it into a dictionary and then wrap it in an array
		if let object = map(parsedJSON) {
			return [object]
		}

		return []
	}

	/** Maps a JSON object to an array of Mappable objects if it is an array of
	* JSON dictionary, or returns nil.
	*/
	public func mapArray(JSON: AnyObject?) -> [N]? {
		if let JSONArray = JSON as? [[String : AnyObject]] {
			return mapArray(JSONArray)
		}

		return nil
	}
	
	/**
	* Maps an array of JSON dictionary to an array of object that conforms to Mappable
	*/
	public func mapArray(JSONArray: [[String : AnyObject]]) -> [N] {
		return JSONArray.reduce([]) { (var values, JSON) in
			// map every element in JSON array to type N
			if let value = self.map(JSON) {
				values.append(value)
			}
			return values
		}
	}

	/** Maps a JSON object to a dictionary of Mappable objects if it is a JSON
	* dictionary of dictionaries, or returns nil.
	*/
	public func mapDictionary(JSON: AnyObject?) -> [String : N]? {
		if let JSONDictionary = JSON as? [String : [String : AnyObject]] {
			return mapDictionary(JSONDictionary)
		}

		return nil
	}

	/**
	* Maps a JSON dictionary of dictionaries to a dictionary of objects that conform to Mappable.
	*/
	public func mapDictionary(JSONDictionary: [String : [String : AnyObject]]) -> [String : N] {
		return reduce(JSONDictionary, [String: N]()) { (var values, element) in
			let (key, value) = element

			// map every value in dictionary to type N
			if let newValue = self.map(value) {
				values[key] = newValue
			}
			return values
		}
	}

	// MARK: Functions that create JSON from objects
	
	/**
	* Maps an object that conforms to Mappable to a JSON dictionary <String : AnyObject>
	*/
	public func toJSON(var object: N) -> [String : AnyObject] {
		let map = Map(mappingType: .ToJSON, JSONDictionary: [:])
		if let jsonTypeName = MappableInfo<N>.getJsonTypeNameFromType(object.dynamicType) {
			let typeTag = MappableInfo<N>.getJsonSerializationTypeTag()
			map.JSONDictionary[typeTag] = jsonTypeName
		}
		object.mapping(map)
		return map.JSONDictionary
	}
	
	/** 
	* Maps an array of Objects to an array of JSON dictionaries [[String : AnyObject]]
	*/
	public func toJSONArray(array: [N]) -> [[String : AnyObject]] {
		return array.map {
			// convert every element in array to JSON dictionary equivalent
			self.toJSON($0)
		}
	}

	/**
	* Maps a dictionary of Objects that conform to Mappable to a JSON dictionary of dictionaries.
	*/
	public func toJSONDictionary(dictionary: [String : N]) -> [String : [String : AnyObject]] {
		return dictionary.map { k, v in
			// convert every value in dictionary to its JSON dictionary equivalent			
			return (k, self.toJSON(v))
		}
	}

	/** 
	* Maps an Object to a JSON string
	*/
	public func toJSONString(object: N, prettyPrint: Bool) -> String? {
		let JSONDict = toJSON(object)

		var err: NSError?
		if NSJSONSerialization.isValidJSONObject(JSONDict) {
			let options: NSJSONWritingOptions = prettyPrint ? .PrettyPrinted : .allZeros
			let JSONData: NSData? = NSJSONSerialization.dataWithJSONObject(JSONDict, options: options, error: &err)
			if let error = err {
				println(error)
			}

			if let JSON = JSONData {
				return NSString(data: JSON, encoding: NSUTF8StringEncoding) as? String
			}
		}

		return nil
	}

	// MARK: Private utility functions for converting strings to JSON objects
	
	/** 
	* Convert a JSON String into a Dictionary<String, AnyObject> using NSJSONSerialization 
	*/
	private func parseJSONDictionary(JSON: String) -> [String : AnyObject]? {
		let parsedJSON: AnyObject? = parseJSONString(JSON)
		return parseJSONDictionary(parsedJSON)
	}

	/**
	* Convert a JSON Object into a Dictionary<String, AnyObject> using NSJSONSerialization
	*/
	private func parseJSONDictionary(JSON: AnyObject?) -> [String : AnyObject]? {
		if let JSONDict = JSON as? [String : AnyObject] {
			return JSONDict
		}

		return nil
	}

	/**
	* Convert a JSON String into an Object using NSJSONSerialization 
	*/
	private func parseJSONString(JSON: String) -> AnyObject? {
		let data = JSON.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true)
		if let data = data {
			var error: NSError?
			let parsedJSON: AnyObject? = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments, error: &error)
			if parsedJSON == nil {
				println("Error parsing JSON: \(error!)")
			}
			return parsedJSON
		}

		return nil
	}
	
	/**
	* Retrieves type/polymorphism indicators in JSONDictionary (__subclass and __type)
	*/
	private func getJsonTypeName(jsonDictionary: [String : AnyObject]) -> String? {
		let typeTag = MappableInfo<N>.getJsonSerializationTypeTag()
		if let typeHint = jsonDictionary[typeTag] as? String {
			return typeHint
		}
		return nil
	}
}

extension Dictionary {
	private func map<K: Hashable, V>(f: Element -> (K, V)) -> [K : V] {
		var mapped = [K : V]()

		for element in self {
			let newElement = f(element)
			mapped[newElement.0] = newElement.1
		}

		return mapped
	}
}
