//
//  ImageView.swift
//  Moonlit
//
//  Created by minjune Song on 3/17/24.
//

import Foundation
import SwiftUI
import Vision

struct ImageWithBoundingBoxesView: View {
    let photo: ImageFile
    @Binding var toggleNormalize: Bool
    @Binding var showRect: Bool
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
               
                if !toggleNormalize {
                 Image(uiImage: photo.thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()   
                }
                ForEach(0..<photo.bbox.count, id: \.self) { index in
                    let box = photo.bbox[index]
                    let adjustedBox = adjustBoundingBox(box, forImageSize: photo.thumbnail.size, orientation: photo.thumbnail.imageOrientation)
                    let normalizedBox = CGRect(
                        x: adjustedBox.minX / photo.thumbnail.size.width,
                        y: adjustedBox.minY / photo.thumbnail.size.height,
                        width: adjustedBox.width / photo.thumbnail.size.width,
                        height: adjustedBox.height / photo.thumbnail.size.height
                    )
                    if toggleNormalize {
                        NormalizedFaceView(photo: photo, boundingBox: adjustedBox)
                            .frame(width: 112, height: 112)
                            .position(x: geometry.size.width * normalizedBox.midX, y: geometry.size.height * (normalizedBox.midY - normalizedBox.height / 2 - 60))
                    } else if showRect {
                        Rectangle()
                        .stroke(Color.green, lineWidth: 2)
                        .frame(width: geometry.size.width * normalizedBox.width, height: geometry.size.height * normalizedBox.height)
                        .position(x: geometry.size.width * normalizedBox.midX, y: geometry.size.height * normalizedBox.midY)
                    }
                }
            }
        }
    }
}


func adjustBoundingBox(_ boundingBox: CGRect, forImageSize imageSize: CGSize, orientation: UIImage.Orientation) -> CGRect {
    let scaleFactorX: CGFloat = 1.2
    let scaleFactorY: CGFloat = 1.9


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
struct NormalizedFaceView: View {
    let photo: ImageFile
    let boundingBox: CGRect
    
    var body: some View {
        if let cgImage = photo.rawImg,
           let croppedFace = extractFacePixels(cgImage, boundingBox),
           let normalizedFace = resizeAndCenterCrop(croppedFace) {
            Image(uiImage: normalizedFace)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 112, height: 112)
                .clipped()
        }
    }
    
    private func extractFacePixels(_ image: CGImage, _ boundingBox: CGRect) -> CGImage? {
        guard let cgImage = image.cropping(to: boundingBox) else {
            return nil
        }
        return cgImage
    }
    
    private func resizeAndCenterCrop(_ image: CGImage) -> UIImage? {
        let targetSize = CGSize(width: 112, height: 112)
        
        let imageWidth = image.width
        let imageHeight = image.height
        
        let scaleFactor = max(targetSize.width / CGFloat(imageWidth), targetSize.height / CGFloat(imageHeight))
        
        let resizedSize = CGSize(width: CGFloat(imageWidth) * scaleFactor, height: CGFloat(imageHeight) * scaleFactor)
        
        let xOffset = (resizedSize.width - targetSize.width) / 2.0
        let yOffset = (resizedSize.height - targetSize.height) / 2.0
        
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 0.0)
        
        let context = UIGraphicsGetCurrentContext()
        context?.interpolationQuality = .high
        
        let rect = CGRect(x: -xOffset, y: -yOffset, width: resizedSize.width, height: resizedSize.height)
        context?.draw(image, in: rect)
        
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        print(normalizedImage)
        return normalizedImage
    }
}
