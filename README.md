# ViewSnapshots

This is still a bit rough, but allows for easy snapshot testing of views.

```
final class RestaurantCellTests : XCTestCase, ViewSnapshotRecording {
    var viewSnapshotMode: ViewSnapshotMode = .Verify
    func test_MyView_snapshot() {
		let sut = MyView()
		sut.frame = CGRect(x: 0, y: 0, width: 127, height: 375)
        SnapshotVerifyView(self, view: sut)
    }
}
```
