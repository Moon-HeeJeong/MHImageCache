import XCTest
@testable import MHImageCache

final class MHImageCacheTests: XCTestCase {
    
    var ic: MHImageCache?

    override func setUpWithError() throws {
        self.ic = MHImageCache()
    }
    
    override func tearDownWithError() throws {
        self.ic = nil
    }
    
    func testGetImgWithFilePath() throws {
        /**
         local :
         Bundle.module.resourcePath
         Bundle.main.resourcePath
         **/
        
        let exception = self.expectation(description: "test get img from file path")
        let directory: String = "\(Bundle.module.resourcePath!)"
    
        let dataSource: ImageFrom = .folder(fileDirectory: directory, imgName: "icons_1")
        
        self.ic?.loadImage(imageFrom: dataSource, completionCallback: { image, isCompleted, error in
            exception.fulfill()
            XCTAssertNotNil(image)
        })
        wait(for: [exception], timeout: 5)
    }
    
    func testGetImgWithUrl() throws{
        let exception = self.expectation(description: "test get img from url")
        let urlStr = "input image url"
        
        self.ic?.loadImage(imageFrom: .url(imgUrl: urlStr), completionCallback: { image, isCompleted, error in
            exception.fulfill()
            XCTAssertNotNil(image)
        })
        wait(for: [exception], timeout: 5)
        
    }
}
