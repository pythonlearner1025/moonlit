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

public class ImageFile: ObservableObject {
    let asset: PHAsset
    let url: URL
    let name: String
    let bbox: [CGRect]? = nil
    var isTapped: Bool = false
    var isHighQuality = false
    
    init(asset: PHAsset, url: URL, name: String) {
        self.asset = asset
        self.url = url
        self.name = name
    }
    
}

class DataSource: ObservableObject {
    @Published var selectedPhotos = [ImageFile]()
    @Published var selected = [String:Int]()
    var imageCachingManager = PHCachingImageManager()
    //var fetchResult: PHFetchResult<PHAsset>
    
   // let batchSize = 50
    //var loadedPhotos = [ImageFile]()
    var selectedPhotosMemorySize: Double {
            let imageFileSize = MemoryLayout<ImageFile>.size
            let bytes = selectedPhotos.count * imageFileSize
            return Double(bytes) / (1024 * 1024)
    }

    func loadAll(completion: @escaping () -> Void) {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 1000
        let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        
        fetchResult.enumerateObjects { asset, index, _ in
            self.getAssetURL(asset) { url in
                   if let url = url {
                       self.detectFace(url: url) { url, rect in
                           guard let url = url else {return}
                           self.assessQuality(url: url) { url in
                               guard let url = url else {return}
                               let imageFile = ImageFile(asset: asset, url: url,  name: asset.value(forKey: "filename") as? String ?? "" )
                                   DispatchQueue.main.async {
                                       if self.selected[imageFile.name] == nil {
                                           self.selectedPhotos.append(imageFile)
                                           self.selected[imageFile.name] = self.selectedPhotos.count - 1
                                       }
                               }
                           }
                       }
                   } else {
                       print("could not get asset URL")
                   }
               }
        }
        completion()
    }
   
    // also return bounding box
    private func detectFace(url: URL, completion: @escaping (URL?,[CGRect]) -> Void) {
        let faceDetectionRequest = VNDetectFaceRectanglesRequest { request, error in
            guard let results = request.results as? [VNFaceObservation], !results.isEmpty else {
                completion(nil, [])
                return
            }
            
            if results.count > 2 {
                completion(nil, [])
                return
            }
            
            // Map each VNFaceObservation to a tuple containing the image and the bounding box.
            let boxes = results.map { observation -> CGRect in
                // Convert the normalized bounding box to the image coordinate system.
                let boundingBox = observation.boundingBox
                return boundingBox
            }
            
            completion(url, boxes)
        }
        
        faceDetectionRequest.revision = VNDetectFaceRectanglesRequestRevision3
        sendRequest(in: url, with: faceDetectionRequest)
    }
    
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
    
    private func sendRequest(in url: URL, with request: VNImageBasedRequest) {
        let handler = VNImageRequestHandler(url: url, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("request failed")
        }
    }
    
    func getAssetURL(_ asset: PHAsset, completion: @escaping (URL?) -> Void) {
        let options = PHContentEditingInputRequestOptions()
        options.canHandleAdjustmentData = { _ in true }
        options.isNetworkAccessAllowed = true
        
        asset.requestContentEditingInput(with: options) { (contentEditingInput, info) in
            guard let contentEditingInput = contentEditingInput else {
                completion(nil)
                return
            }
            completion(contentEditingInput.fullSizeImageURL)
        }
    }
    
    public func fetchImage(
        asset: PHAsset,
        targetSize: CGSize = CGSize(width: 100, height: 100),
           contentMode: PHImageContentMode = .default
       ) async throws -> UIImage? {
           let results = PHAsset.fetchAssets(
            withLocalIdentifiers: [asset.localIdentifier],
               options: nil
           )
           guard let asset = results.firstObject else {
               print("asset not found")
               throw PHPhotosError(.invalidResource)
           }
           let options = PHImageRequestOptions()
           options.deliveryMode = .fastFormat
           options.resizeMode = .fast
           options.isNetworkAccessAllowed = true
           options.isSynchronous = false
           return try await withCheckedThrowingContinuation { [weak self] continuation in
               /// Use the imageCachingManager to fetch the image
               self?.imageCachingManager.requestImage(
                   for: asset,
                   targetSize: targetSize,
                   contentMode: contentMode,
                   options: options,
                   resultHandler: { image, info in
                       /// image is of type UIImage
                       if let error = info?[PHImageErrorKey] as? Error {
                           continuation.resume(throwing: error)
                           return
                       }
                       continuation.resume(returning: image)
                   }
               )
           }
       }
}


