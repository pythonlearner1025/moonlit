//
//  DataSource.swift
//  Moonlit
//
//  Created by minjune Song on 3/14/24.
//

import SwiftUI
import Vision
import Photos
import UIKit
import CoreGraphics

struct DistanceImagePair {
    let distance: Float
    let imageFile: ImageFile
}

public class ImageFile: ObservableObject, Hashable {
    let asset: PHAsset
    let url: URL?
    let name: String
    let bbox: [CGRect]
    @Published var isTapped: Bool = false
    var isHighQuality = false
    @Published var selected: Bool = false
    @Published var dist : Double? = nil
    
    
    init(asset: PHAsset, url: URL?, name: String, bbox: [CGRect]) {
        self.asset = asset
        self.url = url
        self.name = name
        self.bbox = bbox
    }
    
    public static func == (lhs: ImageFile, rhs: ImageFile) -> Bool {
        return lhs.name == rhs.name
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}

class DataSource: ObservableObject {
    @Published var selectedPhotos = [ImageFile]()
    @Published var selected = [String:Int]()
    let cache = CachedImageManager()
    let photoCollection = PhotoCollection(smartAlbum: .smartAlbumUserLibrary)
    @Published var isPhotosLoaded = false
    
    // concurrency docs https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/#Defining-and-Calling-Asynchronous-Functions
    func loadAll(completion: @escaping () -> Void) {
        Task {
            // around 5ms each
            var total = self.photoCollection.photoAssets.phAssets.count
            let limit = 100
            let BS = 10
            var i = 0
            let startTime = Date()
            while i < total {
                if selectedPhotos.count > limit {
                    break
                }
                let assets = Array(self.photoCollection.photoAssets[i..<min(i + BS, total)].compactMap { $0.phAsset })
                let imageFiles = await assets.parallelMap { asset -> ImageFile? in
                    guard asset.mediaType == .image else {
                        return ImageFile(asset: asset, url: nil, name: "", bbox: [])
                    }

                   // print("\(i) : \(asset.value(forKey: "filename") as? String ?? "")")

                    let options = PHImageRequestOptions()
                    options.isNetworkAccessAllowed = true
                    options.deliveryMode = .fastFormat
                    options.isSynchronous = true

                    let imageData = await self.getImageData(for: asset, options: options)
                    if let imageData = imageData {
                         let (asset, image, cgImage) = imageData
                        let rects = await self.getFace(cgImage: cgImage)
                        let imageFile = ImageFile(asset: asset, url: nil, name: asset.value(forKey: "filename") as? String ?? "", bbox: rects ?? [])
                        return imageFile
                    }
                    return nil
                }

                for imageFile in imageFiles {
                    guard let imageFile = imageFile else {continue}
                    if !imageFile.bbox.isEmpty {
                    //    print("Got rects for \(imageFile.name)")
                        if selected[imageFile.name] == nil {
                  //          print("Adding \(imageFile.name)")
                            await MainActor.run {
                                selectedPhotos.append(imageFile)
                                selected[imageFile.name] = selectedPhotos.count - 1
                            }
                        }
                    } else {
                    //    print("No face for \(imageFile.name)")
                    }
                }

                i += BS
            }
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            print("loaded \(selectedPhotos.count) images in \(duration) seconds")
            completion()
        }
    }

    private func getImageData(for asset: PHAsset, options: PHImageRequestOptions) async -> (PHAsset, UIImage, CGImage)? {
        return await withCheckedContinuation { continuation in
            let size = CGSize(width: asset.pixelWidth, height: asset.pixelHeight)
            PHImageManager.default().requestImage(for: asset, targetSize: size, contentMode: .aspectFit, options: options) { (image, info) in
                if let image = image, let cgImage = image.cgImage {
                    continuation.resume(returning: (asset, image, cgImage))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func getFace(cgImage: CGImage) async -> ([CGRect]?) {
        return await withCheckedContinuation { continuation in
            face(cgImage: cgImage) { rects in
                continuation.resume(returning: rects)
            }
        }
    }

    private func face(cgImage: CGImage, completion: @escaping ([CGRect]?) -> Void) {
        let request = VNDetectFaceRectanglesRequest { request, error in
            guard let results = request.results as? [VNFaceObservation], !results.isEmpty else {
                completion(nil)
                return
            }
            
            if results.count > 2 {
                completion(nil)
                return
            }
            
            let boxes = results.map { observation -> CGRect in
                let boundingBox = observation.boundingBox
                return boundingBox
            }
            
            completion(boxes)
        }
        request.revision = VNDetectFaceRectanglesRequestRevision3
        let handler = VNImageRequestHandler(ciImage: CIImage(cgImage: cgImage), options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("request failed")
            completion(nil)
        }
    }
    
    private func detectFace(url: URL, completion: @escaping (URL?, [CGRect]) -> Void) {
        DispatchQueue.global().async{
        let startTime = Date()

         let faceDetectionRequest = VNDetectFaceRectanglesRequest { request, error in
             let endTime = Date()
             let elapsedTime = endTime.timeIntervalSince(startTime)
             //print(elapsedTime)
            guard let results = request.results as? [VNFaceObservation], !results.isEmpty else {
                completion(nil, [])
                return
            }
            
            if results.count > 2 {
                completion(nil, [])
                return
            }
            
            let boxes = results.map { observation -> CGRect in
                let boundingBox = observation.boundingBox
                return boundingBox
            }
            
            completion(url, boxes)
        }
        
        faceDetectionRequest.revision = VNDetectFaceRectanglesRequestRevision3
        self.sendRequest(in: url, with: faceDetectionRequest)   
        }
    }
    
    
    private func sendRequest(in url: URL, with request: VNImageBasedRequest) {
        let handler = VNImageRequestHandler(url: url, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("request failed")
        }
    }
    
    func loadPhotos(_ complete : @escaping () -> Void) async {
        guard !isPhotosLoaded else { return }
        
        let authorized = await PhotoLibrary.checkAuthorization()
        guard authorized else {
            print("Photo library access was not authorized.")
            return
        }
        
        Task {
            do {
                try await self.photoCollection.load()
                complete()
            } catch let error {
                print("Failed to load photo collection: \(error.localizedDescription)")
            }
            DispatchQueue.main.async{
                self.isPhotosLoaded = true
            }
        }
    }
}

extension PHAsset {
    func getURL(completionHandler : @escaping ((_ responseURL : URL?) -> Void)){
            if self.mediaType == .image {
                let options: PHContentEditingInputRequestOptions = PHContentEditingInputRequestOptions()
                options.isNetworkAccessAllowed = true
                options.canHandleAdjustmentData = {(adjustmeta: PHAdjustmentData) -> Bool in
                    return true
                }
                self.requestContentEditingInput(with: options, completionHandler: {(contentEditingInput: PHContentEditingInput?, info: [AnyHashable : Any]) -> Void in
                    if let input = contentEditingInput {
                        completionHandler(contentEditingInput!.fullSizeImageURL as URL?)
                    }
                })
            }
        }
}

extension DataSource {
    /*
    var selectedPhotosMemorySize: Double {
        var bytes = 0
        for img in selectedPhotos {
            bytes += MemoryLayout<[CGRect]>.size(ofValue: img.bbox)
            bytes += MemoryLayout<PHAsset>.size(ofValue: img.asset)

        }
        return Double(bytes*selectedPhotos.count) / (1024 * 1024)
    }*/
    
    private func assessQuality(url: URL, completion: @escaping (URL?) -> Void) {
        let faceQualityRequest = VNDetectFaceCaptureQualityRequest {request, error in
            guard let results = request.results as? [VNFaceObservation], !results.isEmpty else {
                completion(nil)
                return
            }
            let faceQuals = results.compactMap{$0.faceCaptureQuality}
            if let highest = faceQuals.max(), highest < 0.95 {
                completion(nil)
            }
            completion(url)
        }
        faceQualityRequest.revision = VNDetectFaceCaptureQualityRequestRevision3
        sendRequest(in: url, with: faceQualityRequest)
    }
}
