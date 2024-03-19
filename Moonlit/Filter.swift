//
//  Filter.swift
//  Moonlit
//
//  Created by minjune Song on 3/18/24.
//

import Foundation
import Vision

extension GalleryView {
    /*
    private func filterByPerson(_ completion: @escaping () -> Void) {
        DispatchQueue.global().async{
            do {
                guard let facenet = try? FaceNet() else {return}
                var request: VNCoreMLRequest?
                var tapped = data.selectedPhotos.filter({ $0.isTapped })

                // Do this just once:
                let dataType = MLMultiArrayDataType.float32
                var faceEmbed = try MLMultiArray(shape: [1,512], dataType: dataType)
                var mult = try MLMultiArray(shape: [1, 512], dataType: dataType)
                // Set all values to zero
                for i in 0..<faceEmbed.count {
                    faceEmbed[i] = NSNumber(floatLiteral: 0.0)
                    mult[i] = NSNumber(floatLiteral: Double(1.0/Double(tapped.count)))
                }
                
                // avg req
                if let visionModel = try? VNCoreMLModel(for: facenet.model) {
                  request = VNCoreMLRequest(model: visionModel) { request, error in
                    if let observations = request.results as? [VNCoreMLFeatureValueObservation ] {
                      // do stuff
                         var embed = observations[0].featureValue.multiArrayValue!
                         faceEmbed = mat_add(faceEmbed, mat_mul(embed, mult))
                    }
                      if error != nil {
                          print("printing error:")
                          print(error)
                      }
                  }
                }
                // Specify additional options:
                var dists: [DistanceImagePair] = []
                request!.imageCropAndScaleOption = .centerCrop
                for img in tapped {
                    for bbox in img.bbox {
                        guard let rawImg : UIImage = img.rawImg else {continue}
                        let bbox = adjustBoundingBox(bbox, forImageSize: rawImg.size, orientation: rawImg.imageOrientation)

                        guard let face = extractFacePixels(rawImg.cgImage!, bbox) else {continue}
                        //print("requesting prediction on \(img.name)")
                        let handler = VNImageRequestHandler(cgImage: face)
                        try? handler.perform([request!])
                        img.dist = 0
                        let pair = DistanceImagePair(distance: Float(0), imageFile: img)
                        dists.append(pair)
                    }
                }
                //
                var duplicates : [DistanceImagePair] = []
                var request2: VNCoreMLRequest?
                // make a second request
                for img in data.selectedPhotos {
                    if img.isTapped {
                        print(img.name)
                        continue
                    }
                    for bbox in img.bbox {
                        guard let rawImg : UIImage = img.rawImg else {continue}
                        let bbox = adjustBoundingBox(bbox, forImageSize: rawImg.size, orientation: rawImg.imageOrientation)
                        guard let face = extractFacePixels(rawImg.cgImage!, bbox) else { continue }
                        if let visionModel = try? VNCoreMLModel(for: facenet.model) {
                            request2 = VNCoreMLRequest(model: visionModel) { request, error in
                                if let observations = request.results as? [VNCoreMLFeatureValueObservation] {
                                    // calculate dist
                                    let embed = observations[0].featureValue.multiArrayValue!
                                    let diff = mat_sub(faceEmbed, embed)
                                    let squaredDiff = mat_mul(diff,diff)
                                    let distance = mat_sum(squaredDiff)
                                    img.dist = Double(distance)
                                    let pair = DistanceImagePair(distance: distance, imageFile: img)
                                    if dists.contains(where: {$0.imageFile.name == img.name}) {
                                        duplicates.append(pair)
                                    } else {
                                        dists.append(pair)
                                    }
                                }
                                
                                if error != nil {
                                    print("printing error:")
                                }
                            }
                            request2!.imageCropAndScaleOption = .centerCrop
                            let handler = VNImageRequestHandler(cgImage: face)
                            try? handler.perform([request2!])
                        }
                    }
                }
                //print(duplicates.map{$0.imageFile.name})
                dists.sort(by: { $0.distance < $1.distance })
                let sorted = dists.map { $0.imageFile }
                let filteredPhotos = data.selectedPhotos.filter { selectedPhoto in
                    !sorted.contains(where: { $0.name == selectedPhoto.name })
                }
                
                DispatchQueue.main.async {
                    data.selectedPhotos = sorted
                    data.selectedPhotos.append(contentsOf: filteredPhotos)
                    data.selected = [String:Int]()
                    for idx in 0..<data.selectedPhotos.count {
                        let img = data.selectedPhotos[idx]
                        if idx < cutoff && !filteredPhotos.contains(where: {$0.name == img.name}) {
                            img.selected = true
                        }
                        data.selected[img.name] = idx
                        if img.isTapped {
                            img.isTapped = false
                        }
                    }
                   completion()
               }
            } catch {
                // Handle any errors
                DispatchQueue.main.async {
                   completion()
               }
            }
        }
    }
    */
    // use cachemanager to call img first
   func filterByPerson2(_ completion: @escaping () -> Void) {
        DispatchQueue.global().async{
            do {
                guard let facenet = try? FaceNet() else {return}
                var request: VNCoreMLRequest?
                var tapped = data.selectedPhotos.filter({ $0.isTapped })

                // Do this just once:
                let dataType = MLMultiArrayDataType.float32
                var faceEmbed = try MLMultiArray(shape: [1,512], dataType: dataType)
                var mult = try MLMultiArray(shape: [1, 512], dataType: dataType)
                // Set all values to zero
                for i in 0..<faceEmbed.count {
                    faceEmbed[i] = NSNumber(floatLiteral: 0.0)
                    mult[i] = NSNumber(floatLiteral: Double(1.0/Double(tapped.count)))
                }
                
                // avg req
                if let visionModel = try? VNCoreMLModel(for: facenet.model) {
                  request = VNCoreMLRequest(model: visionModel) { request, error in
                    if let observations = request.results as? [VNCoreMLFeatureValueObservation ] {
                      // do stuff
                         var embed = observations[0].featureValue.multiArrayValue!
                         faceEmbed = mat_add(faceEmbed, mat_mul(embed, mult))
                    }
                      if error != nil {
                          print("printing error:")
                          print(error)
                      }
                  }
                }
                // Specify additional options:
                var dists: [DistanceImagePair] = []
                request!.imageCropAndScaleOption = .centerCrop
                for img in tapped {
                    for bbox in img.bbox {
                        let size = CGSize(width: img.asset.pixelWidth, height: img.asset.pixelHeight)
                        data.cache.requestImage(for: img.asset, targetSize: size) {result in
                            if let result = result {
                                let rawImg = result.image
                                let bbox = adjustBoundingBox(bbox, forImageSize: rawImg.size, orientation: rawImg.imageOrientation)

                                guard let face = extractFacePixels(rawImg.cgImage!, bbox) else {return}
                                //print("requesting prediction on \(img.name)")
                                let handler = VNImageRequestHandler(cgImage: face)
                                try? handler.perform([request!])
                                img.dist = 0
                                let pair = DistanceImagePair(distance: Float(0), imageFile: img)
                                dists.append(pair)
                            }
                        }
                        
                    }
                }
                //
                var duplicates : [DistanceImagePair] = []
                var request2: VNCoreMLRequest?
                // make a second request
                for img in data.selectedPhotos {
                    if img.isTapped {
                        print(img.name)
                        continue
                    }
                    for bbox in img.bbox {
                        let size = CGSize(width: img.asset.pixelWidth, height: img.asset.pixelHeight)
                        data.cache.requestImage(for: img.asset, targetSize: size) {result in
                            if let result = result {
                                let rawImg = result.image
                                let bbox = adjustBoundingBox(bbox, forImageSize: rawImg.size, orientation: rawImg.imageOrientation)
                                guard let face = extractFacePixels(rawImg.cgImage!, bbox) else { return }
                                if let visionModel = try? VNCoreMLModel(for: facenet.model) {
                                    request2 = VNCoreMLRequest(model: visionModel) { request, error in
                                        if let observations = request.results as? [VNCoreMLFeatureValueObservation] {
                                            // calculate dist
                                            let embed = observations[0].featureValue.multiArrayValue!
                                            let diff = mat_sub(faceEmbed, embed)
                                            let squaredDiff = mat_mul(diff,diff)
                                            let distance = mat_sum(squaredDiff)
                                            img.dist = Double(distance)
                                            let pair = DistanceImagePair(distance: distance, imageFile: img)
                                            if dists.contains(where: {$0.imageFile.name == img.name}) {
                                                duplicates.append(pair)
                                            } else {
                                                dists.append(pair)
                                            }
                                        }
                                        
                                        if error != nil {
                                            print("printing error:")
                                        }
                                    }
                                    request2!.imageCropAndScaleOption = .centerCrop
                                    let handler = VNImageRequestHandler(cgImage: face)
                                    try? handler.perform([request2!])
                                }
                            }
                        }
                    }
                }
                
                //print(duplicates.map{$0.imageFile.name})
                dists.sort(by: { $0.distance < $1.distance })
                let sorted = dists.map { $0.imageFile }
                let filteredPhotos = data.selectedPhotos.filter { selectedPhoto in
                    !sorted.contains(where: { $0.name == selectedPhoto.name })
                }
                
                DispatchQueue.main.async {
                    data.selectedPhotos = sorted
                    data.selectedPhotos.append(contentsOf: filteredPhotos)
                    data.selected = [String:Int]()
                    for idx in 0..<data.selectedPhotos.count {
                        let img = data.selectedPhotos[idx]
                        if idx < cutoff && !filteredPhotos.contains(where: {$0.name == img.name}) {
                            img.selected = true
                        }
                        data.selected[img.name] = idx
                        if img.isTapped {
                            img.isTapped = false
                        }
                    }
                   completion()
               }
            } catch {
                DispatchQueue.main.async {
                   completion()
               }
            }
        }
    }
    
    func clearFilter() {
        for img in data.selectedPhotos {
            img.selected = false
        }
    }
    
    private func extractFacePixels(_ image: CGImage, _ boundingBox: CGRect) -> CGImage? {
        guard let cgImage = image.cropping(to: boundingBox) else {
            return nil
        }
        return cgImage
    }
}
