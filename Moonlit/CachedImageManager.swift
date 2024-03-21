//
//  CachedImageManager.swift
//  Moonlit
//
//  Created by minjune Song on 3/18/24.
//

import UIKit
import Photos
import SwiftUI
import os.log

actor CachedImageManager {
    
    private let imageManager = PHCachingImageManager()
    
    private var imageContentMode = PHImageContentMode.aspectFit
    
    enum CachedImageManagerError: LocalizedError {
        case error(Error)
        case cancelled
        case failed
    }
    
    private var cachedAssetIdentifiers = [String : Bool]()
    
    private lazy var requestOptions: PHImageRequestOptions = {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        return options
    }()
    
    init() {
        imageManager.allowsCachingHighQualityImages = false
    }
    
    var cachedImageCount: Int {
        cachedAssetIdentifiers.keys.count
    }
    
    func startCaching(for phAssets: [PHAsset], targetSize: CGSize, options : PHImageRequestOptions? = nil) {
        phAssets.forEach {
            cachedAssetIdentifiers[$0.localIdentifier] = true
        }
        var thisOptions = requestOptions
        if let options = options {
           thisOptions = options
        }
        imageManager.startCachingImages(for: phAssets, targetSize: targetSize, contentMode: imageContentMode, options: thisOptions)
    }

    func stopCaching(for phAssets: [PHAsset], targetSize: CGSize, options : PHImageRequestOptions? = nil) {
        phAssets.forEach {
            cachedAssetIdentifiers.removeValue(forKey: $0.localIdentifier)
        }
        var thisOptions = requestOptions
        if let options = options {
           thisOptions = options
        }
        imageManager.stopCachingImages(for: phAssets, targetSize: targetSize, contentMode: imageContentMode, options: thisOptions)
    }
    
    func stopCaching() {
        imageManager.stopCachingImagesForAllAssets()
    }
    
    @discardableResult
    func requestImage(for asset: PHAsset?, targetSize: CGSize, options : PHImageRequestOptions? = nil, completion: @escaping ((image: UIImage, isLowerQuality: Bool)?) -> Void) -> PHImageRequestID? {
        guard let phAsset = asset else {
            completion(nil)
            return nil
        }
        var thisOptions = requestOptions
        if let options = options {
            print("switching to high qual")
           thisOptions = options
        }
        let requestID = imageManager.requestImage(for: phAsset, targetSize: targetSize, contentMode: imageContentMode, options: thisOptions) { image, info in
            if let error = info?[PHImageErrorKey] as? Error {
                logger.error("CachedImageManager requestImage error: \(error.localizedDescription)")
                completion(nil)
            } else if let cancelled = (info?[PHImageCancelledKey] as? NSNumber)?.boolValue, cancelled {
                logger.debug("CachedImageManager request canceled")
                completion(nil)
            } else if let image = image {
                let isLowerQualityImage = (info?[PHImageResultIsDegradedKey] as? NSNumber)?.boolValue ?? false
                let result = (image: image, isLowerQuality: isLowerQualityImage)
                completion(result)
            } else {
                completion(nil)
            }
        }
        return requestID
    }
    
    func cancelImageRequest(for requestID: PHImageRequestID) {
        imageManager.cancelImageRequest(requestID)
    }
}

fileprivate let logger = Logger(subsystem: "com.apple.swiftplaygroundscontent.capturingphotos", category: "CachedImageManager")

