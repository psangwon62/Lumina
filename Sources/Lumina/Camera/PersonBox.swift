import Foundation

public struct PersonBox: Equatable {
    public let centerX: Double
    public let centerY: Double
    public let width: Double
    public let height: Double

    public init(centerX: Double, centerY: Double, width: Double, height: Double) {
        self.centerX = centerX
        self.centerY = centerY
        self.width = width
        self.height = height
    }
}
