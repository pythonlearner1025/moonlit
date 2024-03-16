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

public struct ImageFile: Hashable {
    let url: String
    let thumbnail: UIImage
    let name: String
    let asset: PHAsset
    let bbox: [CGRect]
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(asset.localIdentifier)
    }
    
    public static func == (lhs: ImageFile, rhs: ImageFile) -> Bool {
        return lhs.asset.localIdentifier == rhs.asset.localIdentifier
    }
    
    public func thumbnailWithBoundingBoxes() -> UIImage? {
        // Draw bounding boxes on the thumbnail
        return thumbnail.drawBoundingBoxes(boundingBoxes: self.bbox, originalImg: thumbnail)
    }
}


class DataSource {
    private var imageFiles = [ImageFile]()
    private var imageIndexWithFaces = IndexSet()
    
    func loadData(completion: @escaping () -> Void, addFile: @escaping (ImageFile) -> Void) {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 500
        
        let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        
        fetchResult.enumerateObjects { asset, index, _ in
            self.getImageFromAsset(asset) { ciImage in
                guard let ciImage = ciImage else { return }
                self.detectFace(img: ciImage) { img, rect in
                    if let faceImg = img {
                        self.assessQuality(img: faceImg) { qualImg in
                            if let qualImg = qualImg {
                                self.getPhoto(from: asset) { photo, asset in
                                    if let photo = photo {
                                        let imageFile = ImageFile(url: asset.localIdentifier, thumbnail: photo, name: asset.value(forKey: "filename") as? String ?? "", asset: asset, bbox: rect)
                                        self.imageFiles.append(imageFile)
                                        self.imageIndexWithFaces.insert(index)
                                        addFile(imageFile)
                                    } else {
                                        print("could not getPhoto")
                                    }
                                }
                                
                            }
                        }
                    }
                }
            }
            
        }
        completion()
    }
   
    // also return bounding box
    private func detectFace(img: CIImage, completion: @escaping (CIImage?,[CGRect]) -> Void) {
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
            
            completion(img, boxes)
        }
        
        faceDetectionRequest.revision = VNDetectFaceRectanglesRequestRevision3
        sendRequest(in: img, with: faceDetectionRequest)
    }
    
    private func assessQuality(img: CIImage, completion: @escaping (CIImage?) -> Void) {
        let faceQualityRequest = VNDetectFaceCaptureQualityRequest {request, error in
            guard let results = request.results as? [VNFaceObservation], !results.isEmpty else {
                completion(nil)
                return
            }
            
            let faceQuals = results.compactMap{$0.faceCaptureQuality}
            if let highest = faceQuals.max(), highest < 0.95 {
                print("skipping \(highest)")
                completion(nil)
            }                
            print("keeping \(faceQuals)")
            completion(img)
        }
        faceQualityRequest.revision = VNDetectFaceCaptureQualityRequestRevision3
        sendRequest(in: img, with: faceQualityRequest)
    }
    
    private func sendRequest(in ciImage: CIImage, with request: VNImageBasedRequest) {
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("request failed")
        }
    }
    
    private func getPhoto(from asset: PHAsset, completion: @escaping (UIImage?, PHAsset) -> Void) {
        let options = PHImageRequestOptions()
        //options.isSynchronous = true
        PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 500, height: 500), contentMode: .aspectFit, options: options) { photo, _ in
            completion(photo, asset)
        }
    }
    
    
    private func getImageFromAsset(_ asset: PHAsset, completion: @escaping (CIImage?) -> Void) {
        let options = PHImageRequestOptions()
        let assetSz = CGSize(width: asset.pixelWidth, height: asset.pixelHeight)
        PHImageManager.default().requestImage(for: asset, targetSize: assetSz, contentMode: .aspectFit, options: options) { image, info in
            if let image = image {
                let ciImage = CIImage(image: image)
                let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool ?? false
                completion(ciImage)
            } else {
                print("no img")
                completion(nil)
            }
        }
    }
    
    var numberOfImages: Int {
        return imageIndexWithFaces.count
    }
    
    func imageFile(at index: Int) -> ImageFile {
        let imageIndex = imageIndexWithFaces[imageIndexWithFaces.index(imageIndexWithFaces.startIndex, offsetBy: index)]
        return imageFiles[index]
    }
}


