import SwiftUI
import Vision
import Photos
import CoreML

struct FaceDetectionGalleryView: View {
    @ObservedObject public var data = DataSource()
    @State var loaded = false
    @State var showRect = false
    var done = false
    var body: some View {
        VStack {
            if !loaded {
                ProgressView("Detecting faces...")
                    .onAppear {
                        print("requesting access...")
                        requestPhotoLibraryAccess()
                    }
            } else {
                VStack{
                    Button("Filter by person") {
                       // filterByPerson()
                    }
                    Button("Show Bbox") {
                        showRect.toggle()
                        print(showRect)
                    }
                    .padding()
                    ScrollView {
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 2) {
                            ForEach(0..<data.selectedPhotos.count, id: \.self) { index in
                                let imgFile = data.selectedPhotos[index]
                                ImageWithBoundingBoxesView(imgFile: imgFile, showRect: $showRect)
                                    .frame(width: 100, height: 100)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 0)
                                            .stroke(imgFile.isTapped ? .red : .clear, lineWidth: imgFile.isTapped ? 4 : 0)
                                    )
                                    .onTapGesture {
                                        data.selectedPhotos[index].isTapped.toggle()
                                }
                                    .environmentObject(data)
                           
                            }
                        }
                        .onAppear {
                        }
                    }
                }
            }
        }
    }
        
    private func requestPhotoLibraryAccess() {
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                data.loadAll(completion: {
                   loaded = true
                })
            } else {
            }
        }
    }
    
    // TODO load higher qual image in background thread while person is selecting
    /*
    private func filterByPerson() {
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
            request!.imageCropAndScaleOption = .centerCrop
            for img in tapped {
                for bbox in img.bbox {
                    let bbox = adjustBoundingBox(bbox, forImageSize: img.thumbnail.size, orientation: img.thumbnail.imageOrientation)

                    if let rawimg = img.rawImg {
                        guard let face = extractFacePixels(rawimg, bbox) else {continue}
                        //print("requesting prediction on \(img.name)")
                        let handler = VNImageRequestHandler(cgImage: face)
                        try? handler.perform([request!])
                    }
                }
            }
            var dists: [DistanceImagePair] = []
            var duplicates : [DistanceImagePair] = []
            var request2: VNCoreMLRequest?
            // make a second request
            for img in data.selectedPhotos {
                if img.isTapped { 
                    print(img.name)
                    continue
                }
                for bbox in img.bbox {
                    let bbox = adjustBoundingBox(bbox, forImageSize: img.thumbnail.size, orientation: img.thumbnail.imageOrientation)

                    //var dx = CGFloat(min(bbox.width, bbox.height) * 0.2)
                   // var bbox = bbox.insetBy(dx: dx, dy: dx)
                    if let rawimg = img.rawImg {
                        guard let face = extractFacePixels(rawimg, bbox) else { continue }
                        if let visionModel = try? VNCoreMLModel(for: facenet.model) {
                            request2 = VNCoreMLRequest(model: visionModel) { request, error in
                                if let observations = request.results as? [VNCoreMLFeatureValueObservation] {
                                    // calculate dist
                                    let embed = observations[0].featureValue.multiArrayValue!
                                    let diff = mat_sub(faceEmbed, embed)
                                    let squaredDiff = mat_mul(diff,diff)
                                    let distance = mat_sum(squaredDiff)
                                    let pair = DistanceImagePair(distance: distance, imageFile: img)
                                    if dists.contains(where: {$0.imageFile.name == img.name}) {
                                        duplicates.append(pair)
                                    } else {
                                        dists.append(pair)
                                    }
                                   // print("prediction on \(img.name)")
                                   print(distance)
                                }
                                
                                if error != nil {
                                    print("printing error:")
                                }
                            }
                        }
                        request2!.imageCropAndScaleOption = .centerCrop
                        let handler = VNImageRequestHandler(cgImage: face)
                        try? handler.perform([request2!])
                    }
                }
            }
            
            dists.sort(by: { $0.distance < $1.distance })
            data.selectedPhotos = dists.map { $0.imageFile }
            print(duplicates.map{$0.imageFile.name})
            for idx in 0..<data.selectedPhotos.count{
                if data.selectedPhotos[idx].isTapped {
                    data.selectedPhotos[idx].isTapped = false
                }
            }
            
        } catch {
            // Handle any errors
        }
    }
     */
    
    private func extractFacePixels(_ image: CGImage, _ boundingBox: CGRect) -> CGImage? {
        guard let cgImage = image.cropping(to: boundingBox) else {
            return nil
        }
        return cgImage
    }
    
    private func getHighQualityImage(for asset: PHAsset, completion: @escaping (UIImage?) -> Void) {
        let options = PHImageRequestOptions()
        //TODO temporary
        //completion(nil)
        
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        let assetSize = CGSize(width: asset.pixelWidth, height: asset.pixelHeight)
        PHImageManager.default().requestImage(for: asset, targetSize: assetSize, contentMode: .aspectFit, options: options) { image, _ in
            if let image = image {
                completion(image)
            } else {
                completion(nil)
            }
        }
    }
    
    private func loadHighQualityImages() {
        DispatchQueue.global(qos: .background).async {
            for (index, photo) in data.selectedPhotos.enumerated() {
                if !photo.isHighQuality {
                    /*
                    getHighQualityImage(for: photo.asset) { highQualityImage in
                        DispatchQueue.main.async {
                            if let highQualityImage = highQualityImage {
                                if let adjustIdx = data.selected[photo.name] {
                                 //data.selectedPhotos[adjustIdx].thumbnail = highQualityImage
                                //data.selectedPhotos[adjustIdx].rawImg = highQualityImage.cgImage
                                data.selectedPhotos[adjustIdx].isHighQuality = true
                                }
                            }
                        }
                    }*/
                }
            }
        }
    }
}
