//
//  PolymorphicTypesTestsFromJSON.swift
//  ObjectMapper
//
//  Created by Cosmin Radu on 4/17/15.
//  Copyright (c) 2015 hearst. All rights reserved.
//

import UIKit
import XCTest
import ObjectMapper
import Nimble

class PolymorphicTypesTestsFromJSON: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
		MappableInfo<Base>.setJsonSerializationTypeTag(.ContractDataJson)
		MappableInfo<Base>.configure("Base")
		MappableInfo<Subclass>.configure("Subclass")
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
		MappableInfo<Base>.reset()
        super.tearDown()
    }

    func testMappingPolyFromJSON() {
		var value1 = "base var"
		var value2 = "sub var"
		let JSONString = "{\"__type\" : \"Subclass\", \"base\" : \"\(value1)\", \"sub\" : \"\(value2)\"}"

		let mappedObject: Base = Mapper().map(JSONString)!
		expect(mappedObject).notTo(beNil())
		expect(mappedObject.base).to(equal(value1))
		
		let mappedSubclassObject = mappedObject as! Subclass
		expect(mappedSubclassObject).notTo(beNil())
		expect(mappedSubclassObject.sub).to(equal(value2))
		
		let newString = Mapper().toJSONString(mappedObject, prettyPrint: true)
		println(newString)
    }

	func testMappingPolyArrayFromJSON() {
		var value1 = "base var"
		var value2 = "sub var"
		let JSONString = "[ {\"__type\" : \"Subclass\", \"base\" : \"\(value1)\", \"sub\" : \"\(value2)\"} ]"

		let mappedObject: [Base]? = Mapper().mapArray(JSONString)
		expect(mappedObject).notTo(beNil())
		let mappedSubclassObject = mappedObject![0] as! Subclass
		
		expect(mappedSubclassObject).notTo(beNil())
		expect(mappedSubclassObject.base).to(equal(value1))
		expect(mappedSubclassObject.sub).to(equal(value2))
	}
	
	class NestedPoly: Mappable {
		var int: Int?
		var nested: Base?
		required init?(_ map: Map) {
			mapping(map)
		}
		
		func mapping(map: Map) {
			int		<- map["int"]
			nested	<- map["nested"]
		}
	}
	func testMappingNestedPolyFromJSON() {
		var value0 = 10
		var value1 = "base var"
		var value2 = "sub var"
		let JSONString = "{\"int\" : \(value0), \"nested\" : {\"__type\" : \"Subclass\", \"base\" : \"\(value1)\", \"sub\" : \"\(value2)\"} }"

		let nestedPoly: NestedPoly? = Mapper().map(JSONString)
		expect(nestedPoly).notTo(beNil())
		expect(nestedPoly?.int).to(equal(value0))
		
		let mappedObject = nestedPoly!.nested
		expect(mappedObject).notTo(beNil())

		let mappedSubclassObject = mappedObject as! Subclass
		expect(mappedSubclassObject).notTo(beNil())
		expect(mappedSubclassObject.base).to(equal(value1))
		expect(mappedSubclassObject.sub).to(equal(value2))
		
		let newString = Mapper().toJSONString(nestedPoly!, prettyPrint: true)
		println(newString)
	}

	class NestedPolyArray: Mappable {
		var int: Int?
		var nested: [Base]?
		required init?(_ map: Map) {
			mapping(map)
		}
		
		func mapping(map: Map) {
			int		<- map["int"]
			nested	<- map["nested"]
		}
	}
	func testMappingNestedPolyArrayFromJSON() {
		var value0 = 10
		var value1 = "base var"
		var value2 = "sub var"
		let JSONString = "{\"int\" : \(value0), \"nested\" : [ {\"__type\" : \"Subclass\", \"base\" : \"\(value1)\", \"sub\" : \"\(value2)\"} ] }"
		
		let nestedPoly: NestedPolyArray? = Mapper().map(JSONString)
		expect(nestedPoly).notTo(beNil())
		expect(nestedPoly?.int).to(equal(value0))
		
		let mappedObject = nestedPoly!.nested![0]
		expect(mappedObject).notTo(beNil())
		
		let mappedSubclassObject = mappedObject as! Subclass
		expect(mappedSubclassObject).notTo(beNil())
		expect(mappedSubclassObject.base).to(equal(value1))
		expect(mappedSubclassObject.sub).to(equal(value2))
		
		let newString = Mapper().toJSONString(nestedPoly!, prettyPrint: true)
		println(newString)
	}
}
