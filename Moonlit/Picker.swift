//
//  Picker.swift
//  Moonlit
//
//  Created by minjune Song on 3/21/24.
//

import UIKit
import PhotosUI
import Foundation
import SwiftUI

struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var selectedAssets: [PHAsset]
    @Binding var selectedImages: [UIImage]
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.selectionLimit = 30
        configuration.filter = .any(of: [.images])
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
    }
    
    func makeCoordinator() -> PickerCoordinator {
        PickerCoordinator(self)
    }
    
    class PickerCoordinator: PHPickerViewControllerDelegate {
        private let parent: PhotoPicker
        private var selectedLocalIdentifiers: [String] = []
        
        init(_ parent: PhotoPicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            selectedLocalIdentifiers = results.map { $0.assetIdentifier ?? "" }.filter { !$0.isEmpty }
            
            DispatchQueue.global().async {
                let dispatchGroup = DispatchGroup()
                var tempImages: [UIImage] = []
                
                for localIdentifier in self.selectedLocalIdentifiers {
                    dispatchGroup.enter()
                    
                    let asset = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil).firstObject
                    if let asset = asset {
                        let options = PHImageRequestOptions()
                        options.isSynchronous = true
                        
                        PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 224, height: 224), contentMode: .aspectFit, options: options) { image, _ in
                            if let image = image {
                                tempImages.append(image)
                            }
                            dispatchGroup.leave()
                        }
                    } else {
                        dispatchGroup.leave()
                    }
                }
                
                dispatchGroup.notify(queue: .main) {
                            self.parent.selectedImages = tempImages
                }
            }
            
            picker.dismiss(animated: true)
        }
    }
}
