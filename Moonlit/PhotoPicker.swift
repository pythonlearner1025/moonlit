import UIKit
import PhotosUI
import Foundation
import SwiftUI

struct PhotoPickerController: UIViewControllerRepresentable {
    @Binding var selectedImages: [UIImage]
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.selectionLimit = 30 // Set to 0 for no limit
        configuration.filter = .any(of: [.images]) // Allow both images and videos
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
        private let parent: PhotoPickerController
        
        init(_ parent: PhotoPickerController) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            //parent.selectedImages.removeAll() // Clear the previous selection
            DispatchQueue.global().async{
                let dispatchGroup = DispatchGroup()
                var temp = [UIImage]()
                for result in results {
                    let itemProvider = result.itemProvider
                    if itemProvider.canLoadObject(ofClass: UIImage.self) {
                        dispatchGroup.enter()
                        itemProvider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
                            defer {
                                dispatchGroup.leave()
                            }
                            if let image = image as? UIImage {
                                DispatchQueue.global().async{
                                    let maxDimension: CGFloat = 112
                                    let size = image.size
                                    print("img size: \(size)")
                                    let scale = min(maxDimension / size.width, maxDimension / size.height)
                                    let newWidth = size.width * scale
                                    let newHeight = size.height * scale
                                    let resizedImage = image.resized(to: CGSize(width: newWidth, height: newHeight))
                                    let comp = image.jpegData(compressionQuality: 0.3)
                                    temp.append(UIImage(data: comp!)!)
                                }
                            }
                        }
                    }
                }
                dispatchGroup.notify(queue: .main) {
                    self.parent.selectedImages = temp
                    temp = []
                }
            }
            picker.dismiss(animated: true)
        }
    }
}

