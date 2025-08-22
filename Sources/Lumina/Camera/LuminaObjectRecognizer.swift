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
    public var maskImage: CGImage?
    public var originalImageSize: CGSize?
}

final class LuminaObjectRecognizer: NSObject {
    private var modelPairs: [LuminaModel]
    private let segmentationAnalyzer: SegmentationAnalyzerInterface?
    private let ciContext = CIContext()
    private var originalImageSize: CGSize = .init(width: 448, height: 448)

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

    public func resizeCGImage(_ image: CGImage, targetSize: CGSize) -> CGImage? {
        let ciImage = CIImage(cgImage: image)

        let resized = ciImage.resized(to: targetSize)
        return resized.cgImage
    }

    func recognize(from image: UIImage, isGuidePhoto: Bool = false, completion: @escaping ([LuminaRecognitionResult]?) -> Void) {
        var croppedImage: UIImage
        if isGuidePhoto {
            originalImageSize = image.size
            croppedImage = image
        } else {
            croppedImage = image.croppedToAspectRatio(originalImageSize.width, originalImageSize.height) ?? image
        }

        guard let resizedImage = resizeImage(croppedImage, targetSize: .init(width: 448, height: 448))
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
                    self.mapResults(results, modelType: modelType, isGuidePhoto: isGuidePhoto) { mappedPredictions, boundingBox, maskedImage in
                        recognitionResults.append(LuminaRecognitionResult(predictions: mappedPredictions, type: modelType, personBoundingBox: boundingBox, maskImage: maskedImage, originalImageSize: self.originalImageSize))
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
        isGuidePhoto: Bool = false,
        completion: @escaping ([LuminaPrediction]?, PersonBox?, CGImage?) -> Void
    ) {
        var predictions = [LuminaPrediction]()
        var personBoundingBox: PersonBox?
        var maskedImage: CGImage?

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
                        if #available(iOS 15.0, *) {
//                            if isGuidePhoto {
                            guard let mask = try renderMask(resultArray: MLShapedArray(multiArray), downscaleFactor: 2, originalSize: originalImageSize, isGuidePhoto: isGuidePhoto) else { return }
                            maskedImage = mask
//                            }
                        }
                        personBoundingBox = await self.segmentationAnalyzer?.findLargestPersonBox(from: multiArray)
                        mappingGroup.leave()
                    }
                }
            }
        }

        mappingGroup.notify(queue: .main) {
            let sortedPredictions = predictions.isEmpty ? nil : predictions.sorted { $0.confidence > $1.confidence }
            completion(sortedPredictions, personBoundingBox, maskedImage)
        }
    }

    @available(iOS 15.0, *)
    func renderMask(
        resultArray: MLShapedArray<Int32>?,
        downscaleFactor: Int,
        originalSize: CGSize,
        isGuidePhoto: Bool
    ) throws -> CGImage? {
        guard let resultArray else { return nil }

        // --- 1. 448x448 해상도의 원본 마스크 생성 ---
        let width = resultArray.shape[1]
        let height = resultArray.shape[0]
        var bitmap = resultArray.scalars.map { $0 == 1 ? UInt8(255) : UInt8(0) }
        let bytesPerRow = width
        guard let ctx = CGContext(
            data: &bitmap, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: 0
        ), let maskCG = ctx.makeImage() else {
            return nil
        }
        let ciMask = CIImage(cgImage: maskCG)

        // --- 2. Downscale: 원본 마스크를 'downscaleFactor'만큼 축소 ---
        let scale = 1.0 / CGFloat(downscaleFactor)
        let scaledCIMask = ciMask.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        // --- 3. Extract: '축소된' 마스크에서 테두리 추출 ---
        let edge = scaledCIMask.applyingFilter("CIMorphologyGradient", parameters: ["inputRadius": 2.0])
        let contourColor = isGuidePhoto ? CIColor(red: 1, green: 1, blue: 1, alpha: 1) :
        CIColor(red: 1, green: 0, blue: 1, alpha: 1)
        let smallColoredEdge = CIImage(color: contourColor)
            .cropped(to: edge.extent)
            .applyingFilter("CIBlendWithMask", parameters: ["inputMaskImage": edge])

        // --- 4. Transform (Upscale): '추출된 테두리'를 'originalSize'로 확대 ---
        let finalScaleX = originalSize.width / smallColoredEdge.extent.width
        let finalScaleY = originalSize.height / smallColoredEdge.extent.height
        let finalImage = smallColoredEdge.transformed(by: CGAffineTransform(scaleX: finalScaleX, y: finalScaleY))

        // --- 5. Blur: 확대된 테두리 이미지의 '복사본'에 블러 효과 적용 ---
        // 💡 반경 값을 조절해 후광의 크기를 제어할 수 있습니다.
        let blurredImage = finalImage.applyingFilter("CIGaussianBlur", parameters: ["inputRadius": 1.0])

        // --- ✨ 6. Composite: 선명한 이미지를 흐릿한 이미지 위에 겹치기 ---
        let combinedImage = finalImage.composited(over: blurredImage)

        // --- 7. 최종 결과 반환 ---
        return ciContext.createCGImage(combinedImage, from: combinedImage.extent)
    }
}

extension UIImage {
    /// 주어진 비율(가로:세로)에 맞게 중앙 기준으로 크롭한 이미지를 반환합니다.
    /// - Parameters:
    ///   - aspectRatioWidth: 비율의 가로 값 (예: 1)
    ///   - aspectRatioHeight: 비율의 세로 값 (예: 1)
    ///   - scaleToFillWidthFirst: true면 가능한 한 원본의 가로를 유지(=가로에 맞춰 비율 적용)하고 세로를 자릅니다.
    ///                           false면 가능한 한 원본의 세로를 유지하고 가로를 자릅니다.
    ///                           일반적인 중앙 크롭은 true가 직관적입니다.
    /// - Returns: 크롭된 UIImage (크롭 불가 시 nil)
    func croppedToAspectRatio(_ aspectRatioWidth: CGFloat,
                              _ aspectRatioHeight: CGFloat,
                              scaleToFillWidthFirst: Bool = true) -> UIImage?
    {
        guard aspectRatioWidth > 0, aspectRatioHeight > 0,
              let cgImage = cgImage else { return nil }

        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)
        let targetRatio = aspectRatioWidth / aspectRatioHeight
        let currentRatio = imageWidth / imageHeight

        // 중앙 기준 크롭 영역 계산
        let cropRect: CGRect

        if scaleToFillWidthFirst {
            // 가로를 우선 유지 -> 타겟 비율에 맞도록 세로를 잘라냄
            // 예: 1080x1920 에 1:1 -> 가로 1080 유지, 세로 1080으로 크롭 (위/아래 420씩 제거)
            let targetHeight = imageWidth / targetRatio
            let height = min(targetHeight, imageHeight)
            let y = (imageHeight - height) / 2.0
            cropRect = CGRect(x: 0, y: y, width: imageWidth, height: height)
        } else {
            // 세로를 우선 유지 -> 타겟 비율에 맞도록 가로를 잘라냄
            let targetWidth = imageHeight * targetRatio
            let width = min(targetWidth, imageWidth)
            let x = (imageWidth - width) / 2.0
            cropRect = CGRect(x: x, y: 0, width: width, height: imageHeight)
        }
        // CGImage 기준 좌표로 안전 클램프
        let integralRect = cropRect.integral
            .intersection(CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight))
        guard let croppedCG = cgImage.cropping(to: integralRect) else { return nil }

        // 원본 이미지의 orientation과 scale을 유지
        return UIImage(cgImage: croppedCG, scale: scale, orientation: imageOrientation)
    }
}
