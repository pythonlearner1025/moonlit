//
//  Data.swift
//  Moonlit
//
//  Created by minjune Song on 3/23/24.
//

import Foundation
import UIKit
import CoreData


class LocalData: ObservableObject {
    static let shared = LocalData()
    // Create a persistent container as a lazy variable to defer instantiation until its first use.
    lazy var persistentContainer: NSPersistentContainer = {
        // Pass the data model filename to the container's initializer.
        let container = NSPersistentContainer(name: "LocalImage")
        
        // Load any persistent stores, which creates a store if none exists.
        container.loadPersistentStores { _, error in
            if let error {
                // Handle the error appropriately. However, it's useful to use
                // `fatalError(_:file:line:)` during development.
                fatalError("Failed to load persistent stores: \(error.localizedDescription)")
            }
        }
        
        return container
    }()
    
    private init() { }
    
    // MARK: - Image Saving
    
    func saveImage(imageData: Data, savePath: String) {
        let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let fileURL = documentDirectory?.appendingPathComponent(savePath)
        
        do {
            try imageData.write(to: fileURL!)
            
            let context = persistentContainer.viewContext
            let imagePath = ImagePath(context: context)
            imagePath.savePath = savePath
            imagePath.actualPath = fileURL?.absoluteString
            
            try context.save()
            
            incrementSavedImagesCount()
        } catch {
            print("Error saving image: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Saved Images Count
    
    func incrementSavedImagesCount() {
        let context = persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<ImageCount> = ImageCount.fetchRequest()
        
        do {
            let results = try context.fetch(fetchRequest)
            if let imageCount = results.first {
                imageCount.count += 1
            } else {
                let newImageCount = ImageCount(context: context)
                newImageCount.count = 1
            }
            
            try context.save()
        } catch {
            print("Error incrementing saved images count: \(error.localizedDescription)")
        }
    }
    
    func decrementSavedImagesCount() {
        let context = persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<ImageCount> = ImageCount.fetchRequest()
        
        do {
            let results = try context.fetch(fetchRequest)
            if let imageCount = results.first, imageCount.count > 0 {
                imageCount.count -= 1
                try context.save()
            }
        } catch {
            print("Error decrementing saved images count: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Image Fetching
    
    func fetchImage(savePath: String, completion: @escaping (UIImage?) -> Void) {
        let context = persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<ImagePath> = ImagePath.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "savePath == %@", savePath)
        
        do {
            let results = try context.fetch(fetchRequest)
            if let imagePath = results.first,
               let actualPath = imagePath.actualPath,
               let imageURL = URL(string: actualPath),
               let imageData = try? Data(contentsOf: imageURL) {
                let image = UIImage(data: imageData)
                completion(image)
            } else {
                completion(nil)
            }
        } catch {
            print("Error fetching image: \(error.localizedDescription)")
            completion(nil)
        }
    }
}
