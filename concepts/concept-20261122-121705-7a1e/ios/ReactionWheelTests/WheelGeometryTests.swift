import XCTest
@testable import ReactionWheel

final class WheelGeometryTests:XCTestCase {
    func testMidScreenPlacementUsesUpAxisAndSixUniqueTargets(){let p=WheelGeometry.place(anchor:CGPoint(x:195,y:500),safeRect:CGRect(x:0,y:59,width:390,height:751),scale:1,rtl:false,persistent:false);XCTAssertFalse(p.compact);XCTAssertEqual(p.axis,.up);XCTAssertEqual(Set(p.itemCenters.map{"\(round($0.x)),\(round($0.y))"}).count,6);XCTAssertTrue(p.itemCenters.allSatisfy{CGRect(x:42,y:101,width:306,height:667).contains($0)})}
    func testIndexOrderMirrorsInRTL(){let l=WheelGeometry.centers(center:CGPoint(x:200,y:400),axis:.up,scale:1,rtl:false);let r=WheelGeometry.centers(center:CGPoint(x:200,y:400),axis:.up,scale:1,rtl:true);XCTAssertLessThan(l[0].x,l[5].x);XCTAssertGreaterThan(r[0].x,r[5].x)}
    func testTinyWindowUsesCompact(){let p=WheelGeometry.place(anchor:CGPoint(x:120,y:200),safeRect:CGRect(x:0,y:0,width:240,height:400),scale:1.3,rtl:false,persistent:true);XCTAssertTrue(p.compact)}
    func testHeldAnchorInvariant(){let a=CGPoint(x:195,y:500);let p=WheelGeometry.place(anchor:a,safeRect:CGRect(x:0,y:59,width:390,height:751),scale:1,rtl:false,persistent:false);XCTAssertGreaterThanOrEqual(p.itemCenters.map{hypot($0.x-a.x,$0.y-a.y)}.min()!,96)}
}
