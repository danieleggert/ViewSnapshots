//
//  ViewSnapshotTestCase.swift
//  ViewSnapshots
//
//  Created by Daniel Eggert on 30/12/2014.
//  Copyright (c) 2014 Daniel Eggert. All rights reserved.
//

import UIKit
import XCTest
import Foundation


//
//func SnapshotVerifyView(testCase: FBSnapshotTestCase, view : @autoclosure () -> UIView, identifier : String, file: String = __FILE__, line: UWord = __LINE__) {
//        let referenceImagesDir = NSProcessInfo().environment["REFERENCE_IMAGES_DIR"] as String
//        
//        var error: NSError?
//        let success = testCase.compareSnapshotOfView(view(), referenceImagesDirectory: referenceImagesDir, identifier: identifier, error: &error)
//        XCTAssertTrue(success, "Snapshot compoarison failed: \(error)", file: file, line: line)
//        XCTAssertFalse(testCase.recordMode, "Test ran in record mode. Reference image is now saved. Disable record mode to perform an actual snapshot comparison!", file: file, line: line)
//}




/// Akin to the beloved XCTAssert() functions, this one will check that the specified view matches the snapshot on disk.
///
/// The XCTestClass subclass must implement the ViewSnapshotRecording protocol.
///
/// Use like this
///
///     let view: UIView <- assume we have this
///     SnapshotVerifyView(self, view, "normal")
///
/// Set the viewSnapshotMode inside the setUp method to .Record to create files or to .Verify to compare the view(s) against recorded snapshots.
public func SnapshotVerifyView(testCase: ViewSnapshotTestCase, @autoclosure view :  () -> UIView, identifier : String = "", file: String = __FILE__, line: UInt = __LINE__) {
    do {
        let snapshot = try ViewSnapshot(view: view(), identifier: identifier, testCase: testCase)
        let location = SourceCodeLocation(file: file, line: line)
        switch testCase.viewSnapshotMode {
        case .Record:
            snapshot.recordSnapshotForLocation(location)
        case .Verify:
            try snapshot.verifySnapshotForLocation(location)
        }
    } catch ViewSnapshotError.Error(let message) {
        XCTFail(message, file: file, line: line)
    } catch let error {
        XCTFail("Error: \(error)", file: file, line: line)
    }
}


public typealias ViewSnapshotTestCase = protocol<NamedTestCase, ViewSnapshotRecording>

public enum ViewSnapshotMode {
    case Record
    case Verify
}

// Need NSObjectProtocol here, otherwise the swift compiler crashes.
public protocol ViewSnapshotRecording : NSObjectProtocol  {
    var viewSnapshotMode: ViewSnapshotMode { get }
}

public protocol NamedTestCase : NSObjectProtocol  {
    var testMethodName: String { get }
    var testCaseName: String { get }
}

extension XCTestCase : NamedTestCase {
    public var testMethodName: String {
        get {
            return NSStringFromSelector(self.invocation!.selector)
        }
    }
    public var testCaseName: String {
        get {
            return NSStringFromClass(self.dynamicType)
        }
    }
}
