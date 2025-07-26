import SwiftUI
import Combine

class PhotoStore: ObservableObject {
    @Published var photos: [UIImage] = []
    
    var latestPhoto: UIImage? {
        photos.first
    }
    
    func addPhoto(_ image: UIImage) {
        photos.insert(image, at: 0)
    }
}
