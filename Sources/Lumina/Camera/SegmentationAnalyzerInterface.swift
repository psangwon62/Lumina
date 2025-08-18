import CoreML

public protocol SegmentationAnalyzerInterface {
    func findLargestPersonBox(from arr: MLMultiArray) async -> PersonBox?
}
