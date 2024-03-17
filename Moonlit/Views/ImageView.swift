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

struct ImageWithBoundingBoxesView: View {
    @EnvironmentObject var dataSource : DataSource
    @ObservedObject var imgFile: ImageFile
    @Binding var showRect: Bool
    @State var image : UIImage? = nil
    
    var body: some View {
        ZStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(
                        width: 100,
                        height: 100
                    )
                    .clipped()
            } else {
                Rectangle().foregroundColor(.gray).aspectRatio(1, contentMode: .fit)
                ProgressView()
            }
            
        }
        .task {
            await loadImageAsset()
        }
        // up from the memory
        .onDisappear {
            image = nil
        }
        
    }
    
    func loadImageAsset(
        targetSize: CGSize = PHImageManagerMaximumSize
    ) async {
        guard let uiImage = try? await dataSource.fetchImage(
            asset: imgFile.asset, targetSize: targetSize
        ) else {
            image = nil
            return
        }
        image = uiImage
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

/*
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
 } else if showRect {
 Rectangle()
 .stroke(Color.green, lineWidth: 2)
 .frame(width: geometry.size.width * normalizedBox.width, height: geometry.size.height * normalizedBox.height)
 .position(x: geometry.size.width * normalizedBox.midX, y: geometry.size.height * normalizedBox.midY)
 }
 }
 */
