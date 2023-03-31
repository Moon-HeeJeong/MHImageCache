import Foundation
import UIKit

public enum ImageType {
    case png
    case jpg

    var extentionName: String{
        switch self {
        case .png:
            return "png"
        case .jpg:
            return "jpg"
        }
    }
}

public enum ImageFrom{
    
    case folder(folderPath: String, imgName: String)
    case url(imgUrl: String)

    public var path: String{
        switch self{
        case .folder(let folderPath, let imgName):
            return folderPath + imgName
        case .url(let imgUrl):
            return imgUrl
        }
    }

    public var name: String{
        switch self{
        case .folder(_, let imgName):
            return imgName
        case .url(let imgUrl):
            return imgUrl
        }
    }
}


public typealias ImageLoadCompleted = (_ image: UIImage?, _ isCompleted: Bool, _ error: Error?)->()

open class MHImageCache: NSObject{

    static let work = MHImageCache()

    private var imageCache: NSCache = NSCache<AnyObject, AnyObject>() //(key String, UIImage)
    private var loadedOperations: NSCache = NSCache<AnyObject, AnyObject>()

    public var imageLoadQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "ImageLoadQueue"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    //하나의 이미지를 가져와 Image를 Callback으로 전달
    //(캐시에 저장된 이미지, 새로 로드하는 이미지 둘 다)
    public func loadImage(imageFrom: ImageFrom, type: ImageType = .png, completionCallback: @escaping ImageLoadCompleted){
        
        guard !self.isExistingOperation(key: imageFrom.name) else{
            return
        }

        let op = ImageOperation(imageFrom: imageFrom, ic: self, completionCallback: completionCallback)
        self.saveOperation(op, key: imageFrom.name)
        self.imageLoadQueue.addOperation(op)
    }
    
    //여러 이미지를 로드하여 캐시에 저장
    public func setImageCache(imageFrom: [ImageFrom], type: ImageType = .png, allCompletionCallback: @escaping (_ isAllLoded: Bool)->()){
        
        var isLoadedCount: Int = 0
        
        for i in 0..<imageFrom.count{
            guard !self.isExistingOperation(key: imageFrom[i].name) else{
                return
            }
            
            let op = ImageOperation(imageFrom: imageFrom[i], ic: self) { image, isCompleted, error  in
                if isCompleted{
                    isLoadedCount += 1
                }
                if isLoadedCount == imageFrom.count{
                    allCompletionCallback(true)
                }
            }
            self.saveOperation(op, key: imageFrom[i].name)
            self.imageLoadQueue.addOperation(op)
        }
    }
    
    //캐시에 있는 이미지인지 확인. 캐시에 있는 이미지면 그 Image를 리턴
    fileprivate func existImageCache(key: String) -> UIImage?{
        if let img = self.imageCache.object(forKey: key as AnyObject){
            return img as? UIImage
        }else{
            return nil
        }
    }

    fileprivate func saveCache(key: String, _ image: UIImage){
        self.imageCache.setObject(image, forKey: key as AnyObject)
    }

    private func removeAllCache(){
        self.imageCache.removeAllObjects()
    }

    private func saveOperation(_ op: ImageOperation, key: String){
        self.loadedOperations.setObject(op, forKey: key as AnyObject)
    }

    fileprivate func removeOperationo(key: String){
        if self.isExistingOperation(key: key){
            self.loadedOperations.removeObject(forKey: key as AnyObject)
        }
    }

    private func isExistingOperation(key: String)->Bool{
        if let _ = self.loadedOperations.object(forKey: key as AnyObject){
            return true
        }
        return false
    }

}

public enum ImageLoadError: Error{
    case pathError
    case loadError
}

fileprivate class ImageOperation: Operation{

    let imageFrom: ImageFrom
    let ic: MHImageCache
    let type: ImageType
    var completionCallback: ImageLoadCompleted?

    init(imageFrom: ImageFrom, ic: MHImageCache, type: ImageType = .png, completionCallback: @escaping ImageLoadCompleted){
        self.imageFrom = imageFrom
        self.ic = ic
        self.type = type
        self.completionCallback = completionCallback
    }

    override func main() {

        guard !self.isCancelled else{
            return
        }

        var error: ImageLoadError?

        let image: UIImage? = {
            if let imageCache = self.ic.existImageCache(key:  self.imageFrom.name){ //저장된 캐시가 있을 떄
                return imageCache
            }else {
                var img: UIImage?
                
                switch self.imageFrom{
                    
                case .folder(_, let imgName): //로컬
                    guard let filePath = Bundle.main.path(forResource: self.imageFrom.path, ofType: self.type.extentionName) else{
                        error = .pathError
                        print("ERROR : \(imgName) load fail")
                        return img
                    }
                    
                    if let image = UIImage(named: filePath){
                        self.ic.saveCache(key: imgName, image)
                        img = image
                    }else{
                        error = .loadError
                        print("ERROR : \(imgName) load fail")
                     }
                    
                case .url(let imgUrlStr): //url
                    let imageUrl = URL(string: imgUrlStr)!
                    let imgData = try? Data(contentsOf: imageUrl)

                    if let image = UIImage(data: imgData!){
                        self.ic.saveCache(key: imgUrlStr, image)
                        img = image
                    }else{
                        error = .loadError
                        print("ERROR : \(imgUrlStr) load fail")
                    }
                }
                return img
            }
        }()
        
        self.ic.removeOperationo(key: self.imageFrom.name)

        DispatchQueue.main.async {
            self.completionCallback?(image, true, error)
        }
    }
}
