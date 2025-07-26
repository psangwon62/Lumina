import SwiftUI
import AVKit

struct PreviewView: View {
    @Environment(\.presentationMode) var presentationMode
    let image: UIImage?
    let videoURL: URL?

    var body: some View {
        NavigationView {
            VStack {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                } else if let videoURL = videoURL {
                    VideoPlayer(player: AVPlayer(url: videoURL))
                } else {
                    Text("No preview available")
                }
            }
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}
