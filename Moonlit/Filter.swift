//
//  Filter.swift
//  Moonlit
//
//  Created by minjune Song on 3/18/24.
//

import Foundation
import Vision
import Photos
import UIKit

extension GalleryView {
    func removeDupes(_ dists : [DistanceImagePair]) -> [DistanceImagePair] {
        var groupedDists: [String: [DistanceImagePair]] = [:]
        for dist in dists {
            let name = dist.imageFile.name
            if groupedDists[name] == nil {
                groupedDists[name] = []
            }
            groupedDists[name]?.append(dist)
        }
        var lowestDists: [DistanceImagePair] = []
        for (_, group) in groupedDists {
            if let lowestDist = group.min(by: { $0.distance < $1.distance }) {
                lowestDists.append(lowestDist)
            }
        }
        return lowestDists
    }
    
    func clearFilter() {
        for img in data.selectedPhotos {
            img.selected = false
        }
    }
   
    // why this don't work sometimes?
    func unSelect() {
        for img in data.selectedPhotos {
            if img.isTapped {
                img.selected = false
            }
            img.isTapped = false
        }
    }
    
    private func extractFacePixels(_ image: CGImage, _ boundingBox: CGRect) -> CGImage? {
        guard let cgImage = image.cropping(to: boundingBox) else {
            return nil
        }
        return cgImage
    }
    
    
    func filterByPerson(_ completion: @escaping (Bool) -> Void) {
        var tapped = data.selectedPhotos.filter({ $0.isTapped })
        if tapped.isEmpty {
            completion(false)
            return
        }
        var request1CompletionTimes: [TimeInterval] = []
        var request2CompletionTimes: [TimeInterval] = []
        DispatchQueue.global().async {
            var totalStart = Date()
            do {
                guard let facenet = try? FaceNet() else { return }
                guard let facenet_critic = try? facenet_critic() else { return }
                
                // Do this just once:
                let dataType = MLMultiArrayDataType.float32
                var faceEmbed = try MLMultiArray(shape: [1, 512], dataType: dataType)
                var mult = try MLMultiArray(shape: [1, 512], dataType: dataType)
                
                // Set all values to zero
                for i in 0..<faceEmbed.count {
                    faceEmbed[i] = NSNumber(floatLiteral: 0.0)
                    mult[i] = NSNumber(floatLiteral: Double(1.0 / Double(tapped.count)))
                }
                
                // Specify additional options:
                var dists: [DistanceImagePair] = []
                for img in tapped {
                    for bbox in img.bbox {
                        var startTime = Date()
                        let size = CGSize(width: img.asset.pixelWidth, height: img.asset.pixelHeight)
                        var reqID: PHImageRequestID?
                        reqID = data.cache.requestImage(for: img.asset, targetSize: size) { result in
                            if let result = result {
                                let rawImg = result.image
                                let bbox = adjustBoundingBox(bbox, forImageSize: rawImg.size, orientation: rawImg.imageOrientation)
                                // img retrieval time
                                guard let face = extractFacePixels(rawImg.cgImage!, bbox) else { return }
                                let orient = CGImagePropertyOrientation(rawImg.imageOrientation)
                                if let pixelBuffer = face.pixelBuffer(width: 112, height: 112, orientation: orient) {
                                    if let prediction = try? facenet.prediction(input: pixelBuffer)  {
                                        var embed = prediction.var_927
                                        faceEmbed = mat_add(faceEmbed, mat_mul(embed, mult))
                                    }
                                    //print("requesting prediction on \(img.name)")
                                    let pair = DistanceImagePair(distance: Float(0), imageFile: img)
                                    dists.append(pair)
                                    // timing
                                    let endTime = Date()
                                    let completionTime = endTime.timeIntervalSince(startTime)
                                    startTime = endTime
                                    request1CompletionTimes.append(completionTime)
                                }
                                
                            }
                        }
                        if let reqID = reqID {
                            data.cache.cancelImageRequest(for: reqID)
                        }
                    }
                }
                
                // make a second request
                for img in data.selectedPhotos {
                    if img.isTapped {
                        print(img.name)
                        continue
                    }
                    for bbox in img.bbox {
                        var startTime = Date()
                        let size = CGSize(width: img.asset.pixelWidth, height: img.asset.pixelHeight)
                        var reqID: PHImageRequestID?
                        reqID = data.cache.requestImage(for: img.asset, targetSize: size) { result in
                            if let result = result {
                                let rawImg = result.image
                                let bbox = adjustBoundingBox(bbox, forImageSize: rawImg.size, orientation: rawImg.imageOrientation)
                                guard let face = extractFacePixels(rawImg.cgImage!, bbox) else { return }
                                let orient =  CGImagePropertyOrientation(rawImg.imageOrientation)

                                if let pixelBuffer = face.pixelBuffer(width: 112, height: 112, orientation: orient) {
                                    if let prediction = try? facenet_critic.prediction(x: pixelBuffer, y: faceEmbed) {
                                        let dist = Float(prediction.var_933[0])
                                        let pair = DistanceImagePair(distance: dist, imageFile: img)
                                        if !dists.contains(where: { $0.imageFile.name == img.name }) {
                                            dists.append(pair)
                                            DispatchQueue.main.async {
                                                img.dist = Double(dist)
                                            }
                                        }
                                        let endTime = Date()
                                        let completionTime = endTime.timeIntervalSince(startTime)
                                        request2CompletionTimes.append(completionTime)

                                    }
                                }
                            }
                        }
                        
                        if let reqID = reqID {
                            data.cache.cancelImageRequest(for: reqID)
                        }
                    }
                }
                var embeds = removeDupes(dists)
                embeds.sort(by: { $0.distance < $1.distance })
                let sorted = embeds.map { $0.imageFile }
                let notCompared = data.selectedPhotos.filter { selectedPhoto in
                    !sorted.contains(where: { $0.name == selectedPhoto.name })
                }
                
                DispatchQueue.main.async {
                    data.selectedPhotos = sorted
                    data.selectedPhotos.append(contentsOf: notCompared)
                    data.selected = [String: Int]()
                    for idx in 0..<data.selectedPhotos.count {
                        let img = data.selectedPhotos[idx]
                        if idx < cutoff && !notCompared.contains(where: { $0.name == img.name }) {
                            img.selected = true
                        }
                        data.selected[img.name] = idx
                        if img.isTapped {
                            img.isTapped = false
                        }
                    }
                    // Print average and median wait times
                    let avgRequest1Time = request1CompletionTimes.reduce(0, +) / Double(request1CompletionTimes.count)
                    let avgRequest2Time = request2CompletionTimes.reduce(0, +) / Double(request2CompletionTimes.count)
                    let medianRequest1Time = request1CompletionTimes.sorted()[request1CompletionTimes.count / 2]
                    let medianRequest2Time = request2CompletionTimes.sorted()[request2CompletionTimes.count / 2]
                    print("Request 1 count: \(request1CompletionTimes.count)")
                    print("Request 2 count: \(request2CompletionTimes.count)")
                    print("Average Request 1 Time: \(avgRequest1Time) seconds")
                    print("Average Request 2 Time: \(avgRequest2Time) seconds")
                    print("Median Request 1 Time: \(medianRequest1Time) seconds")
                    print("Median Request 2 Time: \(medianRequest2Time) seconds")
                    let expectedTime = medianRequest1Time * 3 + medianRequest2Time * Double(request2CompletionTimes.count)
                    print("expected time: \(expectedTime)")
                    completion(true)
                }
                var totalEnd = Date()
                var duration = totalEnd.timeIntervalSince(totalStart)
                print("total req time: \(duration)")
            } catch {
                DispatchQueue.main.async {
                    completion(true)
                }
            }
        }
    }
}

