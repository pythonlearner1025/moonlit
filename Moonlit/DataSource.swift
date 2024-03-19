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
    let url: URL
    let name: String
    let bbox: [CGRect]
    @Published var isTapped: Bool = false
    var isHighQuality = false
    @Published var selected: Bool = false
    @Published var dist : Double? = nil
    
    
    init(asset: PHAsset, url: URL, name: String, bbox: [CGRect]) {
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
    
    
    func loadAll(completion: @escaping () -> Void) {
           let fetchOptions = PHFetchOptions()
           fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
           fetchOptions.fetchLimit = 1000
           let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
           let totalCount = fetchResult.count
            print(totalCount)
           let batchSize = 20
           var currentIndex = 0
           
           func processBatch() {
               let endIndex = min(currentIndex + batchSize, totalCount)
               let dispatchGroup = DispatchGroup()
               while currentIndex < endIndex {
                   let asset = fetchResult.object(at: currentIndex)
                   currentIndex += 1
                   print("\(currentIndex)")
                   dispatchGroup.enter()
                   asset.getURL { url in
                       if let url = url {
                           self.detectFace(url: url) { url, rect in
                               guard let url = url else {
                                   dispatchGroup.leave()
                                   return
                               }
                               let imageFile = ImageFile(asset: asset, url: url, name: asset.value(forKey: "filename") as? String ?? "", bbox: rect)
                               DispatchQueue.main.async {
                                   if self.selected[imageFile.name] == nil {
                                       self.selectedPhotos.append(imageFile)
                                       self.selected[imageFile.name] = self.selectedPhotos.count - 1
                                   }
                                   dispatchGroup.leave()
                               }
                           }
                       } else {
                           print("could not get asset URL")
                       }
                   }
               }
               dispatchGroup.wait()
               if currentIndex < totalCount {
                   print("total count: \(totalCount)")
                   print("Batch group \(currentIndex)")
                   processBatch()
               } else {
                   completion()
               }
           }
           
           DispatchQueue.global().async {
               processBatch()
           }
       }
   /* preferable but not working
    func loadAll(completion: @escaping () -> Void) {
           print("Entering loadAll")
           //let fetchResult = PHAsset.fetchAssets(in: .smartAlbum, options: fetchOptions)

           let totalCount = 350//photoCollection.photoAssets.count
           let batchSize = 25
           var currentIndex = 0
           print(totalCount)
           print(isPhotosLoaded)
           func processBatch() {
               let endIndex = min(currentIndex + batchSize, totalCount)
               let dispatchGroup = DispatchGroup()
               while currentIndex < endIndex {
                   //let asset = fetchResult.object(at: currentIndex)
                   guard let asset = photoCollection.photoAssets[currentIndex].phAsset else {
                       print("asset is nil")
                       currentIndex += 1
                       dispatchGroup.leave()
                       continue
                   }
                   print("success \(currentIndex)")
                   currentIndex += 1
                   dispatchGroup.enter()
                   asset.getURL { url in
                       if let url = url {
                           self.detectFace(url: url) { url, rect in
                               if let url = url  {
                                   let imageFile = ImageFile(asset: asset, url: url, name: asset.value(forKey: "filename") as? String ?? "", bbox: rect)
                                   DispatchQueue.main.async {
                                       if self.selected[imageFile.name] == nil {
                                           self.selectedPhotos.append(imageFile)
                                           self.selected[imageFile.name] = self.selectedPhotos.count - 1
                                       }
                                       dispatchGroup.leave()
                                   }
                               } else {
                                   //dispatchGroup.leave()
                               }
                           }
                       } else {
                           print("can't get asset URL")
                       }
                   }
               }
               dispatchGroup.wait(timeout: DispatchTime(uptimeNanoseconds: 10000))
               if currentIndex < totalCount {
                   print("total count: \(totalCount)")
                   print("Batch group \(currentIndex)")
                   processBatch()

               } else {
                   print("exiting")
                   print("currentidx \(currentIndex), totalcount \(totalCount)")
                   completion()
               }
           }

           DispatchQueue.global().async {
               print("entering process bach")
               processBatch()
           }
       }
    */
    
    private func detectFace(url: URL, completion: @escaping (URL?, [CGRect]) -> Void) {
        DispatchQueue.global().async{
         let faceDetectionRequest = VNDetectFaceRectanglesRequest { request, error in
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
    var selectedPhotosMemorySize: Double {
        var bytes = 0
        for img in selectedPhotos {
            bytes += MemoryLayout<[CGRect]>.size(ofValue: img.bbox)
            bytes += MemoryLayout<PHAsset>.size(ofValue: img.asset)

        }
        return Double(bytes*selectedPhotos.count) / (1024 * 1024)
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
}
