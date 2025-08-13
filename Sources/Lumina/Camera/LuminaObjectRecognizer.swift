//
//  LuminaObjectRecognition.swift
//  Lumina
//
//  Created by David Okun on 9/25/17.
//  Copyright © 2017 David Okun. All rights reserved.
//

import UIKit
import CoreML
import Vision

/// An object that represents a prediction about an object that Lumina detects
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
  public var personBoundingBox: CGRect?
}

final class LuminaObjectRecognizer: NSObject {
  private var modelPairs: [LuminaModel]
  private var segmentationLabels = [String: [String]]()
  private var personLabelIndex = [String: Int]()

  init(modelPairs: [LuminaModel]) {
    LuminaLogger.notice(message: "initializing object recognizer", metadata: ["Model Count": "\(modelPairs.count)"])
    self.modelPairs = modelPairs
    super.init()
    
    for pair in modelPairs {
        if let model = pair.model, let type = pair.type {
            let labels = model.segmentationLabels
            if !labels.isEmpty {
                self.segmentationLabels[type] = labels
                // Find and cache the index for the "person" label
                if let personIndex = labels.firstIndex(where: { $0.lowercased() == "person" }) {
                    self.personLabelIndex[type] = personIndex
                    LuminaLogger.notice(message: "Found 'person' label for model", metadata: ["Model": .string(type), "Index": .string(String(personIndex))])
                }
            }
        }
    }
  }

  func recognize(from image: UIImage, completion: @escaping ([LuminaRecognitionResult]?) -> Void) {
    guard let coreImage = image.cgImage else {
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
          let (mappedPredictions, boundingBox) = self.mapResults(results, modelType: modelType)
          recognitionResults.append(LuminaRecognitionResult(predictions: mappedPredictions, type: modelType, personBoundingBox: boundingBox))
          recognitionGroup.leave()
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

  private func mapResults(_ objects: [Any], modelType: String) -> ([LuminaPrediction]?, CGRect?) {
      var predictions = [LuminaPrediction]()
      var personBoundingBox: CGRect?

      for observation in objects {
          if let classification = observation as? VNClassificationObservation {
              predictions.append(LuminaPrediction(name: classification.identifier, confidence: classification.confidence, UUID: classification.uuid))
          }
          else if let recognizedObject = observation as? VNRecognizedObjectObservation, let label = recognizedObject.labels.first {
              predictions.append(LuminaPrediction(name: label.identifier, confidence: label.confidence, UUID: recognizedObject.uuid))
          }
          else if #available(iOS 15.0, *), let featureValue = observation as? VNCoreMLFeatureValueObservation {
              if let multiArray = featureValue.featureValue.multiArrayValue {
                  let shapedArray = MLShapedArray<Int32>(multiArray)
                  personBoundingBox = calculatePersonBoundingBox(from: shapedArray, modelType: modelType)
              }
          }
      }
      
      let sortedPredictions = predictions.isEmpty ? nil : predictions.sorted { $0.confidence > $1.confidence }
      return (sortedPredictions, personBoundingBox)
  }

  @available(iOS 15.0, *)
  private func calculatePersonBoundingBox(from multiArray: MLShapedArray<Int32>, modelType: String) -> CGRect? {
      guard let personIndex = self.personLabelIndex[modelType], multiArray.shape.count >= 2 else {
          return nil
      }

      let height = multiArray.shape[0]
      let width = multiArray.shape[1]
      
      var minX = width
      var minY = height
      var maxX = -1
      var maxY = -1

      for y in 0..<height {
          for x in 0..<width {
              let labelIndex = Int(multiArray[scalarAt: y, x])
              if labelIndex == personIndex {
                  minX = min(minX, x)
                  minY = min(minY, y)
                  maxX = max(maxX, x)
                  maxY = max(maxY, y)
              }
          }
      }

      // If no person pixels were found, maxX will still be -1
      guard maxX != -1 else {
          return nil
      }
      
      return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
  }
}