import SwiftUI
import Vision
import Photos
import CoreML

struct FaceDetectionGalleryView: View {
    @ObservedObject public var data = DataSource()
    @State var loaded = false
    @State var showRect = false
    @State var filtered = false
    @State var filtering = false
    let cutoff = 15
    var done = false
   
    var body: some View {
        VStack {
            if data.selectedPhotos.isEmpty {
                ProgressView("Detecting faces...")
                    .onAppear {
                        print("requesting access...")
                        requestPhotoLibraryAccess()
                    }
            } else {
                if filtering {
                    ProgressView("Filtering...")
                        .progressViewStyle(.automatic)
                        .padding()
                } else {
                    VStack {
                        HStack {
                            Spacer()
                            Button("Filter") {
                                filtering = true
                                filterByPerson({
                                 	filtering = false
                                })
                                filtered = true
                            }
                            Spacer()
                            Button("Bbox") {
                                showRect.toggle()
                                print(showRect)
                            }
                            Spacer()
                            Button("Clear") {
                                clearFilter()
                                filtered = false
                            }
                            Spacer()
                        }
                        .padding()
                        
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 4) {
                                ForEach(data.selectedPhotos, id: \.self) { imgFile in
                                    if !filtered || imgFile.selected {
                                        ImageWithBoundingBoxesView(imgFile: imgFile, showRect: $showRect)
                                            .frame(width: 100, height: 100)
                                            .onTapGesture {
                                                imgFile.isTapped.toggle()
                                                if imgFile.isTapped {
                                                    print("ON \(imgFile.name)")
                                                }
                                            }
                                            .padding(.bottom, 30)
                                            .environmentObject(data)
                                    }
                                }
                            }
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
                                   // print("prediction on \(img.name)")
                                   //print(distance)
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
    
    private func clearFilter() {
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
