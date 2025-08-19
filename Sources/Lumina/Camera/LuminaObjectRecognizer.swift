import CoreML
import UIKit
import Vision

public struct LuminaPrediction {
    /// The name of the object, as predicted by Lumina
    public var name: String
    /// The numeric value of the confidence of the prediction, out of 1.0
    public var confidence: Float
    /// The unique identifier associated with this prediction, as determined by the Vision framework
    public var UUID: UUID
}

/// An object that represents a collection of predictions that Lumina detects, along with their associated types
public struct LuminaRecognitionResult {
  /// The collection of predictions in a given result, for classification or object detection models.
  public var predictions: [LuminaPrediction]?
  /// The String type of MLModel that made the predictions
  public var type: String
  /// The bounding box of the "person" class, if detected in a segmentation map. Coordinates are relative to the model's input size (e.g., 448x448).
  public var personBoundingBox: PersonBox?
}

final class LuminaObjectRecognizer: NSObject {
    private var modelPairs: [LuminaModel]
    private let segmentationAnalyzer: SegmentationAnalyzerInterface?

    init(modelPairs: [LuminaModel], segmentationAnalyzer: SegmentationAnalyzerInterface? = nil) {
        LuminaLogger.notice(message: "initializing object recognizer", metadata: ["Model Count": "\(modelPairs.count)"])
        self.modelPairs = modelPairs
        self.segmentationAnalyzer = segmentationAnalyzer
        super.init()
    }

    public func resizeImage(_ image: UIImage, targetSize: CGSize) -> CIImage? {
        guard let cgImage = image.cgImage
        else { return nil }

        let ciImage = CIImage(cgImage: cgImage)

        return ciImage.resized(to: targetSize)
    }

    func recognize(from image: UIImage, completion: @escaping ([LuminaRecognitionResult]?) -> Void) {
        guard let resizedImage = resizeImage(image, targetSize: .init(width: 448, height: 448))
        else { return }

        let context = CIContext()

        guard let coreImage = context.createCGImage(resizedImage, from: resizedImage.extent) else {
            completion(nil)
            return
        }

        var recognitionResults = [LuminaRecognitionResult]()
        let recognitionGroup = DispatchGroup()
        for modelPair in modelPairs {
            recognitionGroup.enter()
            guard let model = modelPair.model, let modelType = modelPair.type else {
                recognitionGroup.leave()
                continue
            }
            guard let visionModel = try? VNCoreMLModel(for: model) else {
                recognitionGroup.leave()
                continue
            }
            let request = VNCoreMLRequest(model: visionModel) { request, error in
                if error != nil || request.results == nil {
                    recognitionResults.append(LuminaRecognitionResult(predictions: nil, type: modelType, personBoundingBox: nil))
                    recognitionGroup.leave()
                } else if let results = request.results {
                    self.mapResults(results, modelType: modelType) { mappedPredictions, boundingBox in
                        recognitionResults.append(LuminaRecognitionResult(predictions: mappedPredictions, type: modelType, personBoundingBox: boundingBox))
                        recognitionGroup.leave()
                    }
                }
            }
            let handler = VNImageRequestHandler(cgImage: coreImage)
            do {
                try handler.perform([request])
            } catch {
                recognitionGroup.leave()
            }
        }
        recognitionGroup.notify(queue: DispatchQueue.main) {
            completion(recognitionResults)
        }
    }

    private func mapResults(
        _ objects: [Any],
        modelType _: String,
        completion: @escaping ([LuminaPrediction]?, PersonBox?) -> Void
    ) {
        var predictions = [LuminaPrediction]()
        var personBoundingBox: PersonBox?

        let mappingGroup = DispatchGroup()

        for observation in objects {
            if let classification = observation as? VNClassificationObservation {
                predictions.append(LuminaPrediction(name: classification.identifier, confidence: classification.confidence, UUID: classification.uuid))
            } else if let recognizedObject = observation as? VNRecognizedObjectObservation, let label = recognizedObject.labels.first {
                predictions.append(LuminaPrediction(name: label.identifier, confidence: label.confidence, UUID: recognizedObject.uuid))
            } else if let featureValue = observation as? VNCoreMLFeatureValueObservation {
                if let multiArray = featureValue.featureValue.multiArrayValue {
                    mappingGroup.enter()
                    Task {
                        personBoundingBox = await self.segmentationAnalyzer?.findLargestPersonBox(from: multiArray)
                        mappingGroup.leave()
                    }
                }
            }
        }

        mappingGroup.notify(queue: .main) {
            let sortedPredictions = predictions.isEmpty ? nil : predictions.sorted { $0.confidence > $1.confidence }
            completion(sortedPredictions, personBoundingBox)
        }
    }
}


