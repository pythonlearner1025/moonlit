//
//  ImageView.swift
//  Moonlit
//
//  Created by minjune Song on 3/17/24.
//

import Foundation
import SwiftUI
import Vision
import Photos

struct ImageItemView: View {
    @ObservedObject var imgFile: ImageFile
    //@Binding var showRect: Bool
    var cache : CachedImageManager?
    var imageSize : CGSize
    
    @State private var image : Image? = nil
    @State private var imageReqID : PHImageRequestID?
    private static let itemSize = CGSize(width: 90, height: 90)
    
    var body: some View {
        VStack {
            if let image = image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: Self.itemSize.width, height: Self.itemSize.height)
                    .cornerRadius(10)
                    .overlay{
                        if imgFile.isTapped {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(imgFile.isTapped ? .blue : .clear, lineWidth: imgFile.isTapped ? 4 : 0)
                        }
                    }
                
            } else {
                ProgressView()
            }
            Text("\(imgFile.name) | \(imgFile.dist != nil ? imgFile.dist! : -1)").font(.custom("tiny", size: CGFloat(8)))
        }
        .task {
            guard image == nil, let cache = cache else { return }
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.isNetworkAccessAllowed = true
            await cache.requestImage(for: imgFile.asset, targetSize: imageSize, options: options) { result in
                Task {
                    if let result = result {
                        let sX = CGFloat(3)
                        let sY = CGFloat(3)
                        // TODO should be processing faces in all bboxes, not just 1st.
                        let box = adjustBoundingBox(imgFile.bbox[0], forImageSize: result.image.size, orientation: result.image.imageOrientation, scaleFactorX: sX, scaleFactorY: sY)
                        let face = extractFacePixels(result.image.cgImage!, box)
                        let img = UIImage(cgImage: face!)
                        self.image = Image(uiImage: img)
                        //eself.image = Image(uiImage: result.image)
                    }
                }
            }
        }
    }
    
    private func extractFacePixels(_ image: CGImage, _ boundingBox: CGRect) -> CGImage? {
        guard let cgImage = image.cropping(to: boundingBox) else {
            return nil
        }
        return cgImage
    }
}

func adjustBoundingBox(_ boundingBox: CGRect, forImageSize imageSize: CGSize, orientation: UIImage.Orientation, scaleFactorX : CGFloat = 1.2, scaleFactorY : CGFloat = 1.9) -> CGRect {
    var adjustedBox: CGRect
    switch orientation {
    case .up, .upMirrored:
        // No adjustment needed
        adjustedBox = CGRect(x: boundingBox.minX * imageSize.width,
                             y: (1 - boundingBox.maxY) * imageSize.height, // Adjust Y-axis
                             width: boundingBox.width * imageSize.width,
                             height: boundingBox.height * imageSize.height)
    case .down, .downMirrored:
        // Rotate 180 degrees
        adjustedBox = CGRect(x: (1 - boundingBox.maxX) * imageSize.width,
                             y: boundingBox.minY * imageSize.height, // Adjust Y-axis
                             width: boundingBox.width * imageSize.width,
                             height: boundingBox.height * imageSize.height)
    case .left, .leftMirrored:
        // Rotate 90 degrees CCW
        adjustedBox = CGRect(x: boundingBox.minY * imageSize.width,
                             y: boundingBox.minX * imageSize.height, // Adjust Y-axis
                             width: boundingBox.height * imageSize.width,
                             height: boundingBox.width * imageSize.height)
    case .right, .rightMirrored:
        // Rotate 90 degrees CW
        adjustedBox = CGRect(x: (1 - boundingBox.maxY) * imageSize.width,
                             y: (1 - boundingBox.maxX) * imageSize.height, // Adjust Y-axis
                             width: boundingBox.height * imageSize.width,
                             height: boundingBox.width * imageSize.height)
    @unknown default:
        // Fallback for future orientations
        adjustedBox = boundingBox
    }
    
    // Scale the adjusted bounding box by 1.2x
    let scaledBox = CGRect(x: adjustedBox.minX - (adjustedBox.width * (scaleFactorX - 1) / 2),
                           y: adjustedBox.minY - (adjustedBox.height * (scaleFactorY - 1) / 2),
                           width: adjustedBox.width * scaleFactorX,
                           height: adjustedBox.height * scaleFactorY)
    
    // Ensure the scaled bounding box stays within the image bounds
    let clampedBox = scaledBox.intersection(CGRect(origin: .zero, size: imageSize))
    
    return clampedBox
}

