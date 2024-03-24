//
//  RequestManager.swift
//  Moonlit
//
//  Created by minjune Song on 3/21/24.
//

import Foundation
import UIKit
import Photos
import Supabase

// LATER
/*
  recovery when request fails
  request persistence when user force quits app
 */

class RequestManager {
    let client = SupabaseClient(supabaseURL: URL(string: "https://xyzcompany.supabase.co")!, supabaseKey: "public-anon-key")
    let baseURL = "http://127.0.0.1:3000"

    
    func generateImages(_ selectedPhotos: [ImageFile], _ id : UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        // Check the in-app purchase status on the device
        checkInAppPurchaseStatus { [weak self] hasPurchased in
            guard let self = self else { return }
            if hasPurchased {
                // User has purchased, proceed with image upload
                self.uploadPhotos(selectedPhotos, id) { result in
                    switch result {
                    case .success(let paths):
                        self.pollImages(id)
                        self.sendTrainRequest(paths, id) { _ in
                            print("train req sent")
                        }
                        break
                    case .failure(let err):
                        // do recovery action
                        break
                    }
                }
            } else {
                // Check if the user exists and has purchased in Supabase
                self.checkPurchaseStatusInSupabase() { [weak self] hasPurchasedInSupabase in
                    guard let self = self else { return }
                    if hasPurchasedInSupabase {
                        // TODO kill this when it reaches generation target, don't want reads idling users
                        self.uploadPhotos(selectedPhotos, id) { result in
                            switch result {
                            case .success:
                                self.pollImages(id)
                            case .failure(let err):
                                completion(.failure(err))
                            }
                        }
                    } else {
                        // User has not purchased, handle accordingly (e.g., show purchase screen)
                        completion(.failure(PurchaseError.notPurchased))
                    }
                }
            }
        }
    }
    
    private func pollImages(_ id : UUID) {
        supabase.realtime
          .channel("photo_updates")
          .on("postgres_changes", filter:
                ChannelFilter(event: "*", schema: "public", table: "photos", filter: "uuid=eq.\(id)")
          ) { message in
              print("Change received!", message.payload)
              let payload = message.payload
              let path : String = payload["path"] as! String
              print("trying to donw img from path \(path)...")
              self.downloadImage(path) { success in
                  if success {
                      print("img from path \(path) successfully")
                  } else {
                      print("nope")
                  }
              }
          }
          .subscribe()
    }
    
    func downloadImage(_ storagePath: String, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global().async {
            Task {
                let data = try await supabase.storage
                    .from("Photos")
                    .download(path: storagePath)
                self.saveImageToLibrary(imageData: data) { _ in
                    completion(true)
                }
            }
        }
    }
    
    func uploadPhotos(_ selectedPhotos: [ImageFile], _ id: UUID, completion: @escaping (Result<[String], Error>) -> Void) {
        let dispatchGroup = DispatchGroup()
        var photoPaths : [String] = []
        
        for photo in selectedPhotos where photo.selected {
            dispatchGroup.enter()
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            let sz = CGSize(width: photo.asset.pixelWidth, height: photo.asset.pixelHeight)
            print("getting photo \(photo.name)")
            PHImageManager().requestImage(for: photo.asset, targetSize: sz, contentMode: .aspectFit, options: options) { image, info in
                if let image = image, let data = image.pngData() {
                    let filename = NSString(string: photo.name)
                    let type = "png"
                    let path =  "private/\(id)/train/original/\(filename.deletingPathExtension).\(type)"
                    print("uploading \(photo.name) to path: \(path)")
                    
                    // todo access control: https://supabase.com/docs/guides/storage/security/access-control
                    // upload original
                    DispatchQueue.global().async {
                        Task {
                             try await supabase.storage
                                .from("Photos")
                                .upload(
                                    path: path,
                                    file: data,
                                    options: FileOptions(
                                        cacheControl: "3600",
                                        contentType: "image/\(type)",
                                        upsert: false
                                    )
                                )
                            print("upload \(photo.name) success")
                            photoPaths.append(path)
                            dispatchGroup.leave()
                        }
                    }
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            // All photos uploaded successfully
            print("all upload success")
            completion(.success((photoPaths)))
            
        }
    }
    

    enum PurchaseError: Error {
        case notPurchased
        // Add any other relevant error cases
    }
    
    func sendTrainRequest(_ trainPaths: [String], _ id : UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        // Submit the train request with the necessary parameters
        let type = "String" // Replace with the appropriate type
        let parameters: [String: Any] = [
            "train_images_paths": trainPaths,
            "type": type,
            "user_id": id
        ]
        
        // Make a request to submit the train request
        let url = URL(string: "\(baseURL)/train")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: [])
        } catch {
            completion(.failure(error))
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                completion(.failure(error))
                return
            }
            
            // Check if the response is successful (status code 200)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let error = NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                completion(.failure(error))
                return
            }
            
            // Training request submitted successfully
            completion(.success(()))
            
            // Start uploading the selected photos asynchronously
        }
        
        task.resume()
    }
}

import Photos

extension RequestManager {

    func saveImageToLibrary(imageData: Data, completion: @escaping (Result<String, Error>) -> Void) {
        PHPhotoLibrary.requestAuthorization { status in
            switch status {
            case .authorized:
                self.saveImageWithFullAccess(imageData: imageData, completion: completion)
            case .limited:
                self.saveImageWithLimitedAccess(imageData: imageData, completion: completion)
            case .denied, .restricted:
                completion(.failure(PhotoLibraryError.accessDenied))
            case .notDetermined:
                completion(.failure(PhotoLibraryError.accessNotDetermined))
            @unknown default:
                completion(.failure(PhotoLibraryError.unknown))
            }
        }
    }

    func saveImageWithFullAccess(imageData: Data, completion: @escaping (Result<String, Error>) -> Void) {
        guard let image = UIImage(data: imageData) else {
            completion(.failure(PhotoLibraryError.invalidImageData))
            return
        }
        
        PHPhotoLibrary.shared().performChanges {
            let creationRequest = PHAssetCreationRequest.forAsset()
            creationRequest.addResource(with: .photo, data: imageData, options: nil)
        } completionHandler: { success, error in
            if let error = error {
                completion(.failure(error))
            } else if success {
                completion(.success("Image saved successfully"))
            } else {
                completion(.failure(PhotoLibraryError.unknown))
            }
        }
    }

    func saveImageWithLimitedAccess(imageData: Data, completion: @escaping (Result<String, Error>) -> Void) {
        guard let image = UIImage(data: imageData) else {
            completion(.failure(PhotoLibraryError.invalidImageData))
            return
        }
        
        PHPhotoLibrary.shared().performChanges {
            let creationRequest = PHAssetCreationRequest.forAsset()
            creationRequest.addResource(with: .photo, data: imageData, options: nil)
        } completionHandler: { success, error in
            if let error = error {
                if error.localizedDescription.contains("User denied access") {
                    completion(.failure(PhotoLibraryError.accessDenied))
                } else {
                    completion(.failure(error))
                }
            } else if success {
                completion(.success("Image saved successfully"))
            } else {
                completion(.failure(PhotoLibraryError.unknown))
            }
        }
    }

    enum PhotoLibraryError: Error {
        case accessDenied
        case accessNotDetermined
        case invalidImageData
        case unknown
    }
}

