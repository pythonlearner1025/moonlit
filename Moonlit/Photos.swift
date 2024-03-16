//
//  Photos.swift
//  Moonlit
//
//  Created by minjune Song on 3/13/24.
//

import Foundation
import Photos

class PhotoProcessor {
    let assets = PHAsset()
    func requestPhotosAccess(completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.requestAuthorization { status in
            completion(status == .authorized)
        }
    }
    
    func fetchPeople(completion: @escaping ([String]) -> Void) {
        // Fetch people using PHAsset.fetchAssets(with:options:)
        // Store local identifiers and call completion with the array of identifiers
        let options = PHFetchOptions()
        options.fetchLimit = 1
        let peopleResult = PHAsset.fetchAssets(with: .image, options: options)
        let images = PHAsset.fetchAssets(with: .image, options: nil)
       
        var localIds : [String] = []
        images.enumerateObjects { img, _, _ in
            /*
            if let id = img.localIdentifier {
                localIds.append(id)
            }
             */
        }
        completion(localIds)
    }
    
    func fetchPhotosForPerson(withIdentifier identifier: String, completion: @escaping ([PHAsset]) -> Void) {
           let fetchOptions = PHFetchOptions()
           fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
           fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
           
           let assets = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: fetchOptions)
           
           var photos: [PHAsset] = []
           assets.enumerateObjects { asset, _, _ in
               photos.append(asset)
           }
           
           completion(photos)
       }
    
    func processImageData(for asset: PHAsset, completion: @escaping (Data?) -> Void) {
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = true
        requestOptions.deliveryMode = .highQualityFormat
        
        PHImageManager.default().requestImageData(for: asset, options: requestOptions) { data, _, _, _ in
            // TODO: Process the image data according to your app's requirements
            completion(data)
        }
    }
}
