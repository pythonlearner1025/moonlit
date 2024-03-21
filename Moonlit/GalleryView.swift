import SwiftUI
import Vision
import Photos
import PhotosUI
import CoreML

struct GalleryView: View {
    @ObservedObject public var data = DataSource()
    @State var loaded = false
    @State var showRect = false
    @State var filtered = false
    @State var filtering = false
    let pickMode: PickMode
    let cutoff = 15
    var done = false
    
    @State private var manualPicked = [PhotosPickerItem]()
    @State private var manualImages =  [UIImage]()
    @Binding var displayPicker : Bool

    @Environment(\.displayScale) private var displayScale
    
    private static let itemSpacing = 12.0
    private static let itemCornerRadius = 15.0
    private static let itemSize = CGSize(width: 90, height: 90)
    
    
    private var imageSize: CGSize {
        return CGSize(width: Self.itemSize.width * min(displayScale, 2), height: Self.itemSize.height * min(displayScale, 2))
    }
    
    private let columns = [
        GridItem(.adaptive(minimum: itemSize.width, maximum: itemSize.height), spacing: itemSpacing)
    ]
    
    var body: some View {
            VStack {
                if pickMode == .manual {
                        VStack{
                            if manualImages.isEmpty {
                                ProgressView()
                            } else {
                                ScrollView {
                                    LazyVGrid(columns: columns, spacing: Self.itemSpacing) {
                                        ForEach(manualImages, id: \.self) { image in
                                            Image(uiImage: image)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: Self.itemSize.width, height: Self.itemSize.height)
                                                .cornerRadius(10)
                                                .clipped()
                                        }
                                    }
                                    .padding([.vertical], Self.itemSpacing)
                                }
                                .navigationTitle("Gallery")
                                .navigationBarTitleDisplayMode(.inline)
                                HStack {
                                    Button("Generate") {
                                        // Perform generation with selectedImages
                                    }
                                }
                            }
                        }
                        .sheet(isPresented: $displayPicker) {
                            PhotoPickerController(selectedImages: $manualImages)
                        }
                        .onChange(of: displayPicker) {
                            print("CHANGED \(displayPicker)")
                        }
                } else {
                    if data.selectedPhotos.isEmpty {
                        ProgressView("\(pickMode)...")
                            .onAppear {
                                print("Requesting access...")
                                requestPhotoLibraryAccess()
                            }
                    } else {
                        if filtering {
                            ProgressView("Filtering...")
                                .progressViewStyle(.automatic)
                                .padding()
                        } else {
                            VStack {
                                buttonsView()
                                ScrollView {
                                    LazyVGrid(columns: columns, spacing: Self.itemSpacing) {
                                        ForEach(data.selectedPhotos, id: \.self) { imgFile in
                                            if !filtered || imgFile.selected {
                                                imageItemView(image: imgFile)
                                            }
                                        }
                                    }
                                    .padding([.vertical], Self.itemSpacing)
                                }
                                .navigationTitle("Gallery")
                                .navigationBarTitleDisplayMode(.inline)
                                HStack {
                                    Button("Generate") {
                                        // Perform generation with data.selectedPhotos
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .onChange(of: data.isPhotosLoaded) { _ in
                if pickMode == .auto {
                    data.loadAll(completion: {})
                }
            }
           
        }
        
        private func requestPhotoLibraryAccess() {
            if pickMode == .auto {
                Task{
                    await data.loadPhotos {
                        // Photos loaded
                    }
                }
                
            }
        }
    
    private func imageItemView(image: ImageFile) -> some View {
       // let size = CGSize(width: 100, height: 100)
        ImageItemView(imgFile: image, cache: data.cache, imageSize: imageSize)
            .onAppear {
                let options = PHImageRequestOptions()
                options.deliveryMode = .opportunistic
                options.isNetworkAccessAllowed = true
                Task {
                    await data.cache.startCaching(for: [image.asset], targetSize: imageSize, options: options)
                }
            }
            .onDisappear {
                let options = PHImageRequestOptions()
                options.deliveryMode = .opportunistic
                options.isNetworkAccessAllowed = true
                Task {
                    await data.cache.stopCaching(for: [image.asset], targetSize: imageSize, options: options)
                }
            }
            .onTapGesture {
                image.isTapped.toggle()
            }
    }
    
    private func buttonsView() -> some View {
        HStack {
            Spacer()
            Button("Filter") {
                filtering = true
                filterByPerson({ result in
                    if result {
                        filtered = true
                    } else {
                        filtered = false
                    }
                    filtering = false
                })
            }
            Spacer()
            Button("Remove") {
                //showRect.toggle()
                unSelect()
            }
            Spacer()
            Button("Clear") {
                clearFilter()
                filtered = false
            }
            Spacer()
        }
        .padding()
    }
    
}
