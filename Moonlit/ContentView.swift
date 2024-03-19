import SwiftUI
import Vision
import Photos
import CoreML

struct GalleryView: View {
    @ObservedObject public var data = DataSource()
    @State var loaded = false
    @State var showRect = false
    @State var filtered = false
    @State var filtering = false
    let cutoff = 15
    var done = false
    
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
            if data.selectedPhotos.isEmpty {
                ProgressView("Detecting faces...")
                    .onAppear {
                        print("requesting access...")
                    //    requestPhotoLibraryAccess()
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
                                        // add onTapped
                                    }
                                }
                            }
                            .padding([.vertical], Self.itemSpacing)

                        }
                        .navigationTitle("Gallery")
                        .navigationBarTitleDisplayMode(.inline)
                    HStack{
                        Button("Generate") {
                            //tainRequest()
                        }
                    }
                    }
                }
            }
        }
        .task {
            await data.loadPhotos({
            })
           
        }
        .onChange(of: data.isPhotosLoaded, {
             data.loadAll(completion: {
               loaded = true
            })
        })
    
    }
    
    private func imageItemView(image: ImageFile) -> some View {
        ImageItemView(imgFile: image, cache: data.cache, imageSize: imageSize)
            .frame(width: Self.itemSize.width, height: Self.itemSize.height)
            .cornerRadius(10)
            .clipped()
            .overlay(alignment: .bottomLeading) {
              
            }
            .onAppear {
                Task {
                    await data.cache.startCaching(for: [image.asset], targetSize: imageSize)
                }
            }
            .onDisappear {
                Task {
                    await data.cache.stopCaching(for: [image.asset], targetSize: imageSize)
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
                filterByPerson2({
                     filtering = false
                })
                filtered = true
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
        /*
    private func requestPhotoLibraryAccess() {
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                data.loadAll(completion: {
                   loaded = true
                })
            } else {
            }
        }
    }
         */
}
