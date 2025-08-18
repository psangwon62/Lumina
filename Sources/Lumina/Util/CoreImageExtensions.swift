import CoreImage

extension CIImage {
    func resized(to size: CGSize) -> CIImage {
        let scaleX = size.width / extent.width
        let scaleY = size.height / extent.height
        return transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
    }
}
