//
//  ViewTests.swift
//  ViewSnapshots
//
//  Created by Daniel Eggert on 10/08/2015.
//  Copyright © 2015 Daniel Eggert. All rights reserved.
//

import XCTest



/// Returns `iOS9` for iOS 9.
/// Can be used for snapshot identifiers eg. when using the system font which is different between iOS 8 and iOS 9.
public var MajorOSVersion: String {
    let version = NSProcessInfo.processInfo().operatingSystemVersion.majorVersion
    return "iOS\(version)"
}


protocol ViewTestCase {
}

public class ViewTests : XCTestCase, ViewTestCase {
    func setupViewUnderTest() -> UIView {
        fatalError("Need to override this")
    }
    
    private var window: UIWindow?
    private var viewUnderTest: UIView?
    
    private var dimensionConstraints: [NSLayoutConstraint] = []
    
    public override func setUp() {
        super.setUp()
        
        viewUnderTest = setupViewUnderTest()
        
        window = UIWindow()
        let vc = UIViewController(nibName: nil, bundle: nil)
        window?.rootViewController = vc
        window?.addSubview(viewUnderTest!)
        window?.makeKeyAndVisible()
    }
    
    public override func tearDown() {
        viewUnderTest?.removeFromSuperview()
        viewUnderTest = nil
        window = nil
        super.tearDown()
    }
    
    private func removeAllDimensionConstraints() {
        viewUnderTest?.removeConstraints(dimensionConstraints)
        dimensionConstraints.removeAll()
    }
    private func addConstraint(constaint: NSLayoutConstraint?) {
        if let c = constaint {
            c.active = true
            dimensionConstraints.append(c)
        }
    }
    
    func resizeTo(size: CGSize) {
        viewUnderTest!.translatesAutoresizingMaskIntoConstraints = false
        
        removeAllDimensionConstraints()
        addConstraint(viewUnderTest?.heightAnchor.constraintEqualToConstant(size.height))
        addConstraint(viewUnderTest?.widthAnchor.constraintEqualToConstant(size.width))

        window?.setNeedsLayout()
        window?.layoutIfNeeded()
    }
    
    func resizeToHeight(newHeight: CGFloat) {
        viewUnderTest!.translatesAutoresizingMaskIntoConstraints = false
        removeAllDimensionConstraints()
        addConstraint(viewUnderTest?.heightAnchor.constraintEqualToConstant(newHeight))
        window?.setNeedsLayout()
        window?.layoutIfNeeded()
    }
}

public class CollectionCellTests: XCTestCase, ViewTestCase {
    
    public let cellIdentifier = "Cell"
    private let window = UIWindow()
    private var collectionView: UICollectionView?
    public private(set) var cellUnderTest: UICollectionViewCell?
    private var dataSourceAndDelegate: CollectionDataSourceAndDelegate?
    
    /// Subclasses can override this to configure the cell
    func configureCellUnderTest(cell: UICollectionViewCell) {}
    
    
    public override func setUp() {
        super.setUp()
        
        let cvt = UICollectionViewController(collectionViewLayout: UICollectionViewFlowLayout())
        collectionView = cvt.collectionView
        
        window.frame = UIScreen.mainScreen().bounds
        window.rootViewController = cvt
        window.makeKeyAndVisible()
        
        registerWithCollectionView(collectionView!)
        dataSourceAndDelegate = CollectionDataSourceAndDelegate(test: self, itemSize: 500)
        collectionView?.dataSource = dataSourceAndDelegate
        collectionView?.delegate = dataSourceAndDelegate
        
        window.addSubview(collectionView!)
    }
    
    public override func tearDown() {
        collectionView?.removeFromSuperview()
        cellUnderTest = nil
        collectionView = nil
        super.tearDown()
    }
    
    public func registerWithCollectionView(tableView: UICollectionView) {
        fatalError("Need to override this and call registerClass(_:forCellReuseIdentifier:) or similar.")
    }
    
    
    func resizeTo(size: CGSize) {
        let l = collectionView!.collectionViewLayout as! UICollectionViewFlowLayout
        l.itemSize = size
        collectionView?.layoutIfNeeded()
    }
    
    private class CollectionDataSourceAndDelegate : NSObject, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
        unowned var test: CollectionCellTests
        var itemSize: Int!
        init(test: CollectionCellTests, itemSize: Int) {
            self.test = test
            self.itemSize = itemSize
            super.init()
        }
        
        @objc func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            return 1
        }
        
        @objc func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCellWithReuseIdentifier(test.cellIdentifier, forIndexPath: indexPath)
            XCTAssertGreaterThan(cell.frame.size.height, 0, "Height should never be 0")
            test.cellUnderTest = cell
            return cell
        }
        
        @objc func collectionView(collectionView: UICollectionView, willDisplayCell cell: UICollectionViewCell, forItemAtIndexPath indexPath: NSIndexPath) {
            test.configureCellUnderTest(cell)
        }
    }
}

public class AutosizingCellTests : XCTestCase, ViewTestCase {
    
    /// Subclasses can override this to configure the cell
    func configureCellUnderTest(cell: UITableViewCell, forTableView tableView: UITableView) {}
    
    public private(set) var cellUnderTest: UITableViewCell?
    public let cellIdentifier = "Cell"
    
    private let window = UIWindow()
    private var tableView: UITableView?
    private var dataSourceAndDelegate: AutosizingTableViewDataSourceAndDelegate?
    
    public override func setUp() {
        super.setUp()
        
        window.frame = UIScreen.mainScreen().bounds
        let tvc = UITableViewController()
        window.rootViewController = tvc
        window.makeKeyAndVisible()
        
        tableView = tvc.tableView
        registerWithTableView(tableView!)
        dataSourceAndDelegate = AutosizingTableViewDataSourceAndDelegate(test: self)
        tableView!.separatorStyle = .None
        tableView!.delegate = dataSourceAndDelegate
        tableView!.dataSource = dataSourceAndDelegate
        tableView!.estimatedRowHeight = 40
        tableView!.rowHeight = UITableViewAutomaticDimension
        tableView!.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
        tableView!.layoutIfNeeded()
        tableView!.reloadData()
        
        window.addSubview(tableView!)
    }
    
    public func registerWithTableView(tableView: UITableView) {
        fatalError("Need to override this and call registerClass(_:forCellReuseIdentifier:) or similar.")
    }
    
    public override func tearDown() {
        tableView?.removeFromSuperview()
        cellUnderTest = nil
        tableView = nil
        super.tearDown()
    }
    
    func withCellWidth(newWidth: CGFloat, file: String = __FILE__, line: UInt = __LINE__, @noescape block: () -> ()) {
        let old = UIView.areAnimationsEnabled()
        UIView.setAnimationsEnabled(false)
        
        tableView!.frame = CGRect(origin: CGPoint(), size: CGSize(width: newWidth, height: 1000))
        tableView!.layoutIfNeeded()
        tableView!.reloadData()
        
        dataSourceAndDelegate!.hideCell = false
        tableView?.reloadRowsAtIndexPaths([dataSourceAndDelegate!.sutIndexPath], withRowAnimation: .Fade)
        NSRunLoop.currentRunLoop().runUntilDate(NSDate(timeIntervalSinceNow: 0.001))
        
        precondition(cellUnderTest != nil)
        XCTAssertFalse(cellUnderTest?.contentView.hasAmbiguousLayout() ?? false, "Cell layout is ambiguous. Use cellUnderTest!.contentView.constraintsAffectingLayoutForAxis() to debug.", file: file, line: line)
        block()
        
        dataSourceAndDelegate?.hideCell = true
        tableView?.reloadRowsAtIndexPaths([dataSourceAndDelegate!.sutIndexPath], withRowAnimation: .Fade)
        
        UIView.setAnimationsEnabled(old)
    }
    
    private class AutosizingTableViewDataSourceAndDelegate : NSObject, UITableViewDataSource, UITableViewDelegate {
        unowned var test: AutosizingCellTests
        var hideCell = true
        init(test: AutosizingCellTests) {
            self.test = test
            super.init()
        }
        var sutIndexPath: NSIndexPath { return NSIndexPath(forRow: 0, inSection: 0) }
        @objc func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            return 1
        }
        @objc func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
            let isSUT = !hideCell
            if isSUT {
                let cell = tableView.dequeueReusableCellWithIdentifier(test.cellIdentifier)!
                test.cellUnderTest = cell
                return cell
            } else {
                let cell = UITableViewCell(style: .Default, reuseIdentifier: "foo")
                let view = UIView()
                cell.contentView.addSubview(view)
                view.heightAnchor.constraintEqualToConstant(50)
                view.topAnchor.constraintEqualToAnchor(view.superview!.topAnchor)
                view.bottomAnchor.constraintEqualToAnchor(view.superview!.bottomAnchor)
                view.leftAnchor.constraintEqualToAnchor(view.superview!.leftAnchor)
                view.rightAnchor.constraintEqualToAnchor(view.superview!.rightAnchor)
                return cell
            }
        }
        
        @objc func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
            let isSUT = !hideCell
            if isSUT {
                XCTAssertTrue(cell.translatesAutoresizingMaskIntoConstraints, "Do not set translatesAutoresizingMaskIntoConstraints = false on the cell inside setup()")
                test.configureCellUnderTest(cell, forTableView: tableView)
            }
        }
    }
}

extension CGFloat {
    /// The widths that we're testing.
    /// There's something hard coded in UIKit about 320, so we'll add 1 to make everyone sane and happy.
    static let deviceWidthsToTest = [iPhone5Width + 1, iPhone6Width, iPhone6PlusWidth]
    static let iPhone5Width = CGFloat(320)
    static let iPhone6Width = CGFloat(375)
    static let iPhone6PlusWidth = CGFloat(414)
    
    var formatted: String {
        return String(format: "%g", self)
    }
}
