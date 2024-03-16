import SwiftUI
import Vision
import Photos

struct FaceDetectionGalleryView: View {
    @State private var selectedPhotos = [ImageFile]()
    private var dataModel = DataSource()
    var done = false
    
    var body: some View {
        VStack {
            if selectedPhotos.isEmpty {
                ProgressView("Detecting faces...")
                    .onAppear {
                        requestPhotoLibraryAccess()
                    }
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 4) {
                        ForEach(selectedPhotos, id: \.self) { photo in
                            if let bboxThumbnail = photo.thumbnailWithBoundingBoxes() {
                             Image(uiImage: bboxThumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 100, height: 100)
                                .clipped()   
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
                dataModel.loadData(completion: {
                }, addFile: { imgFile in
                    // Check if the image is already in the list
                    if let existingIndex = selectedPhotos.firstIndex(where: { $0.asset == imgFile.asset}) {
                          selectedPhotos[existingIndex] = imgFile
                      } else {
                          selectedPhotos.append(imgFile)
                      }
                })
            } else {
            }
        }
    }
    
}

extension UIImage {
    func drawBoundingBoxes(boundingBoxes: [CGRect], originalImg: UIImage) -> UIImage? {
        //TODO adjust bounding box here
        
        // Begin a graphics context of sufficient size
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        
        // Draw original image into the context
        draw(at: CGPoint.zero)
        
        // Get the context for CoreGraphics
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        // Set the stroke color and line width
        context.setStrokeColor(UIColor.red.cgColor)
        context.setLineWidth(2.0)
        
        // Add rectangles for each bounding box
        for box in boundingBoxes {
            var box = adjustBoundingBox(box, forImageSize: originalImg.size, orientation: originalImg.imageOrientation)
            context.addRect(box)
        }
        // Perform drawing operation
        context.strokePath()
        
        // Capture the new image
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        
        // End the graphics context
        UIGraphicsEndImageContext()
        
        return newImage
    }
    
 
}

func adjustBoundingBox(_ boundingBox: CGRect, forImageSize imageSize: CGSize, orientation: UIImage.Orientation) -> CGRect {
    switch orientation {
    case .up, .upMirrored:
        // No adjustment needed
        return CGRect(x: boundingBox.minX * imageSize.width,
                      y: (1 - boundingBox.maxY) * imageSize.height, // Adjust Y-axis
                      width: boundingBox.width * imageSize.width,
                      height: boundingBox.height * imageSize.height)
    case .down, .downMirrored:
        // Rotate 180 degrees
        return CGRect(x: (1 - boundingBox.maxX) * imageSize.width,
                      y: boundingBox.minY * imageSize.height, // Adjust Y-axis
                      width: boundingBox.width * imageSize.width,
                      height: boundingBox.height * imageSize.height)
    case .left, .leftMirrored:
        // Rotate 90 degrees CCW
        return CGRect(x: boundingBox.minY * imageSize.width,
                      y: boundingBox.minX * imageSize.height, // Adjust Y-axis
                      width: boundingBox.height * imageSize.width,
                      height: boundingBox.width * imageSize.height)
    case .right, .rightMirrored:
        // Rotate 90 degrees CW
        return CGRect(x: (1 - boundingBox.maxY) * imageSize.width,
                      y: (1 - boundingBox.maxX) * imageSize.height, // Adjust Y-axis
                      width: boundingBox.height * imageSize.width,
                      height: boundingBox.width * imageSize.height)
    @unknown default:
        // Fallback for future orientations
        return boundingBox
    }
    }
