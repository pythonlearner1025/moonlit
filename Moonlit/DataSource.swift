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
    
    func loadAll(completion: @escaping() -> Void) {
        
        var total = photoCollection.photoAssets.phAssets.count
        //let BS = 30
        let serialQueue = DispatchQueue(label: "serialQueue")
        var i = 0
      //  let group = DispatchGroup()
        while i < total {
            if i > 0  {
       //         group.wait()
            }
        //    group.enter()
            i+=1
            guard let asset = photoCollection.photoAssets[i].phAsset else {
                i+=1
         //       group.leave()
                continue
            }
            if asset.mediaType != .image {
               i+=1
          //     group.leave()
               continue
            }
            print("\(i) : \(asset.value(forKey: "filename") as? String ?? "")")
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .opportunistic
            autoreleasepool{
             PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: options) { (image, info) in
                  if let image = image, let cgImage = image.cgImage {
                      serialQueue.async{
                          self.face(cgImage: cgImage) { rects in
                              if let rects = rects {
                                  print("got rects")
                                  let imageFile = ImageFile(asset: asset, url: nil, name: asset.value(forKey: "filename") as? String ?? "", bbox: rects)
                                      DispatchQueue.main.async {
                                          if self.selected[imageFile.name] == nil {
                                              print("adding")
                                              self.selectedPhotos.append(imageFile)
                                              self.selected[imageFile.name] = self.selectedPhotos.count - 1
                                          }
                                      }
                   //                   group.leave()
                              } else {
                                  print("no face")
                       //           group.leave()
                              }
                             
                          }
                      }
                  } else {
                    print("invalid image or cgImage")
               //       group.leave()
                  }
              }   
            }
        }
    //    group.wait()
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
    /*
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
                               if let url = url {
                                let rects = [CGRect(x:CGFloat(0), y:CGFloat(0), width: CGFloat(0), height: CGFloat(0) )]
                               let imageFile = ImageFile(asset: asset, url: url, name: asset.value(forKey: "filename") as? String ?? "", bbox: rects)
                                   DispatchQueue.main.async {
                                       if self.selected[imageFile.name] == nil {
                                           self.selectedPhotos.append(imageFile)
                                           self.selected[imageFile.name] = self.selectedPhotos.count - 1
                                       }
                                   }
                               }
                               dispatchGroup.leave()
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
    */
    
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
