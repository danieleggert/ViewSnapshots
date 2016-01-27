//
//  ViewSnapshotHelpers.swift
//  ViewSnapshots
//
//  Created by Daniel Eggert on 30/12/2014.
//  Copyright (c) 2014 Daniel Eggert. All rights reserved.
//

import Foundation
import UIKit
import XCTest



/// A location in the test source code. Used for asserts.
struct SourceCodeLocation {
    let file: String
    let line: UInt
}

/// A named view snapshot, ie. an image and the test case and method it originated from.
struct ViewSnapshot {
    let image: UIImage
    let testCaseName: String
	let testMethodName: String
    let identifier: String
}

enum ViewSnapshotError : ErrorType {
    case Error(String)
}


/// Helper functions to create ViewSnapshot instances.
extension ViewSnapshot {
    init(view: UIView, identifier: String, testCase: ViewSnapshotTestCase) throws {
        self.init(image: try ViewSnapshot.imageFromView(view), identifier: identifier, testCase: testCase)
    }
    
    init(layer: CALayer, identifier: String, testCase: ViewSnapshotTestCase) throws {
        self.init(image: try ViewSnapshot.imageFromLayer(layer), identifier: identifier, testCase: testCase)
    }
    
    init(image: UIImage, identifier: String, testCase: ViewSnapshotTestCase) {
        self.image = image
        self.testCaseName = testCase.testCaseName
        self.testMethodName = testCase.testMethodName
        self.identifier = identifier
    }
    
    private static func imageFromView(view: UIView) throws -> UIImage {
        return try renderImageWithSize(view.frame.size) {
            view.drawViewHierarchyInRect(view.bounds, afterScreenUpdates: true)
            return
        }
    }
    
    private static func imageFromLayer(layer: CALayer) throws -> UIImage {
        let bounds = layer.bounds
        guard 0 != CGRectGetWidth(bounds) else { throw ViewSnapshotError.Error("Zero width for layer \(layer)") }
        guard 0 != CGRectGetHeight(bounds) else { throw ViewSnapshotError.Error("Zero height for layer \(layer)") }
        return try renderImageWithSize(bounds.size) {
            layer.renderInContext(UIGraphicsGetCurrentContext()!)
        }
    }
    
    private static func renderImageWithSize(size: CGSize, renderBlock: () -> Void) throws -> UIImage {
        guard size.height != 0 else { throw ViewSnapshotError.Error("Image height is 0.") }
        guard size.width != 0 else { throw ViewSnapshotError.Error("Image width is 0.") }
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        renderBlock()
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
}


extension ViewSnapshot {
    
    /// Writes the snapshot to the file system.
    func recordSnapshotForLocation(location: SourceCodeLocation) -> Void {
        createParentDirectoryForURL(imageURL())
        let url = imageURL()

        print("saving file at url, with size: \(image.size)")
        try! UIImagePNGRepresentation(image)!.writeToURL(url, options: NSDataWritingOptions())
        XCTFail("Recorded new reference image at \"\(url.path!)\"", file: location.file, line: location.line)
    }
    
    
    /// Verifies that the snapshot matches the file in the file system.
    func verifySnapshotForLocation(location: SourceCodeLocation) throws -> Void {
        let maybeReferenceImage = UIImage(contentsOfFile: imageURL().path!)
        XCTAssertNotNil(maybeReferenceImage, "Unable to load reference image \"\(imageURL().path!)\"", file: location.file, line: location.line)
        if let referenceImage = maybeReferenceImage {
            try compareWithReferenceImage(referenceImage, location: location)
        }
    }
}

func ReferenceImageDirectoryURL() -> NSURL {
    let variableName = "SnapshotReferenceImages"
    if let path = NSProcessInfo.processInfo().environment[variableName] {
        return NSURL(fileURLWithPath: path, isDirectory: true)
    } else {
        assert(false, "Set the \(variableName) environment variable to point to the reference image directory.")
    }
}

/// File URL / path related
extension ViewSnapshot {
    private func imageURL() -> NSURL {
        let subDir = ReferenceImageDirectoryURL().URLByAppendingPathComponent(testCaseName)
        return subDir.URLByAppendingPathComponent(imageFilename(""))
    }
    
    private enum ImageType {
        case Reference
        case Failed
        case Diff
        
        func name() -> String {
            switch self {
            case .Reference:
                return "reference"
            case .Failed:
                return "failed"
            case .Diff:
                return "diff"
            }
        }
    }
    
    private func temporaryImageURLForType(type: ImageType) -> NSURL {
        let subDir = NSURL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).URLByAppendingPathComponent(testCaseName)
        createDirectoryAtURL(subDir)
        return subDir.URLByAppendingPathComponent(imageFilename(type.name()))
    }
    
    private func imageFilename(typeName: String) -> String {
        let scale = UIScreen.mainScreen().scale
        let suffix = (scale == 1) ? "" : "@\(scale)x"
        let type = (typeName == "") ? "" : "%\(typeName)"
        return ("\(testMethodName)-\(identifier)\(type)\(suffix)" as NSString).stringByAppendingPathExtension("png")!
    }

    private func createParentDirectoryForURL(url: NSURL) {
        let parentURL = url.URLByDeletingLastPathComponent!
        createDirectoryAtURL(parentURL)
    }
    
    private func createDirectoryAtURL(url: NSURL) {
        try! NSFileManager.defaultManager().createDirectoryAtURL(url, withIntermediateDirectories: true, attributes: nil)
    }
}

/// Comparing images / contexts
extension ViewSnapshot {
    private func compareWithReferenceImage(referenceImage: UIImage, location: SourceCodeLocation) throws {
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.drawInRect(CGRect(origin: CGPoint(), size: image.size), blendMode: .Copy, alpha: 1)
        let snapshotContext = UIGraphicsGetCurrentContext()!
        
        UIGraphicsBeginImageContextWithOptions(referenceImage.size, false, referenceImage.scale)
        referenceImage.drawInRect(CGRect(origin: CGPoint(), size: referenceImage.size), blendMode: .Copy, alpha: 1)
        let referenceContext = UIGraphicsGetCurrentContext()!
        
        let matches = try compareBitmapContext(snapshotContext, withReferenceContext: referenceContext, location: location)
        
        UIGraphicsEndImageContext()
        
        UIGraphicsEndImageContext()
        
        if !matches {
            saveDiffToolImagesWithReferenceImage(referenceImage)
        }
    }
    
    private func saveDiffToolImagesWithReferenceImage(referenceImage: UIImage) {
        print("To compare with Kaleidoscope.app run:\nksdiff '\(saveTemporaryImage(referenceImage, type: .Reference))' '\(saveTemporaryImage(self.image, type: .Failed))'")
    }
    
    private func saveTemporaryImage(image: UIImage, type: ImageType) -> String {
        let imageURL = temporaryImageURLForType(type)
        try! UIImagePNGRepresentation(image)!.writeToURL(imageURL, options: NSDataWritingOptions())
        return imageURL.path!
    }
    
    private func compareBitmapContext(snapshotContext: CGContextRef, withReferenceContext referenceContext: CGContextRef, location: SourceCodeLocation) throws -> Bool {
        
        guard CGBitmapContextGetBitmapInfo(snapshotContext) == CGBitmapContextGetBitmapInfo(referenceContext) else { throw ViewSnapshotError.Error("Bitmap info mismatch") }
        guard CGBitmapContextGetWidth(snapshotContext) == CGBitmapContextGetWidth(referenceContext) else {
            throw ViewSnapshotError.Error("Width does not match: \(CGBitmapContextGetWidth(snapshotContext)) == \(CGBitmapContextGetWidth(referenceContext))")
        }
        guard CGBitmapContextGetHeight(snapshotContext) == CGBitmapContextGetHeight(referenceContext) else {
            throw ViewSnapshotError.Error("Height does not match: \(CGBitmapContextGetHeight(snapshotContext)) == \(CGBitmapContextGetHeight(referenceContext))")
        }
        guard (CGBitmapContextGetWidth(snapshotContext) == CGBitmapContextGetWidth(referenceContext)) &&
            (CGBitmapContextGetHeight(snapshotContext) == CGBitmapContextGetHeight(referenceContext)) else { return false }
        
        // These checks will only fail if the reference image was not created with this code.
        guard CGBitmapContextGetBytesPerRow(snapshotContext) == CGBitmapContextGetBytesPerRow(referenceContext) else { fatalError("bytes-per-row mismatch") }
        guard CGBitmapContextGetBitsPerPixel(snapshotContext) == CGBitmapContextGetBitsPerPixel(referenceContext) else { fatalError("bytes-per-row mismatch") }
        
        let length = CGBitmapContextGetBytesPerRow(snapshotContext) * CGBitmapContextGetHeight(snapshotContext)
        let result = memcmp(CGBitmapContextGetData(snapshotContext), CGBitmapContextGetData(referenceContext), length)
        let perfectMatch = result == Int32(0)
        if perfectMatch {
//            return true
        }
        
        // If this is RGBA data, we'll try to do fuzzy matching
        if (CGBitmapContextGetBytesPerRow(snapshotContext) == CGBitmapContextGetWidth(snapshotContext) * 4) &&
            (CGBitmapContextGetBitmapInfo(snapshotContext) == CGBitmapInfo(rawValue: CGImageAlphaInfo.PremultipliedLast.rawValue))
        {
            
        }
        
        
        
        XCTAssert(result == Int32(0), "Image data does not match reference", file: location.file, line: location.line)
        return (result == 0)
    }
}
