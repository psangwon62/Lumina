import CoreML
import Lumina
import SwiftUI

struct LuminaCameraView: UIViewControllerRepresentable {
    @EnvironmentObject var photoStore: PhotoStore
    @Binding var isPresented: Bool

    // Camera settings from ContentView
    @Binding var position: CameraPosition
    @Binding var flashState: FlashState
    @Binding var recordsVideo: Bool
    @Binding var streamFrames: Bool
    @Binding var trackMetadata: Bool
    @Binding var captureLivePhotos: Bool
    @Binding var captureDepthData: Bool
    @Binding var streamDepthData: Bool
    @Binding var resolution: CameraResolution
    @Binding var frameRate: Int
    @Binding var useCoreMLModels: Bool
    @Binding var isVideoStabilizationEnabled: Bool
    @Binding var isFocusLockingEnabled: Bool
    @Binding var maxZoomScale: Float

    // Zoom handling
    var onZoomFactorChanged: (Float) -> Void
    @Binding var commandedZoomFactor: Float?
    @Binding var resetZoomTrigger: Bool

    // Capture handling
    @Binding var captureTrigger: Bool

    // Session status
    @Binding var sessionStatus: LuminaSessionStatus

    func makeUIViewController(context: Context) -> LuminaViewController {
        let luminaVC = LuminaViewController()
        luminaVC.delegate = context.coordinator

        // Apply settings from SwiftUI
        luminaVC.position = position
        luminaVC.flashState = flashState
        luminaVC.recordsVideo = recordsVideo
        luminaVC.streamFrames = streamFrames
        luminaVC.trackMetadata = trackMetadata
        luminaVC.captureLivePhotos = captureLivePhotos
        luminaVC.captureDepthData = captureDepthData
        luminaVC.streamDepthData = streamDepthData
        luminaVC.resolution = resolution
        luminaVC.frameRate = frameRate
        luminaVC.maxZoomScale = maxZoomScale
        luminaVC.isVideoStabilizationEnabled = isVideoStabilizationEnabled
        luminaVC.isFocusLockingEnabled = isFocusLockingEnabled
        luminaVC.focusImage = UIImage(resource: .focus)

        // Hide all built-in UIKit buttons
        luminaVC.setCancelButton(visible: false)
        luminaVC.setShutterButton(visible: false)
        luminaVC.setSwitchButton(visible: false)
        luminaVC.setFlashButton(visible: false)

        luminaVC.onZoomDidChange = { newZoomFactor in
            onZoomFactorChanged(newZoomFactor)
        }

        if useCoreMLModels {
            do {
                if #available(iOS 17.0, *) {
                    let detrModel = try LuminaModel(model: DETRResnet50().model, type: "DETRResnet50")
                    luminaVC.streamingModels = [detrModel]
                } else {
                    // Fallback on earlier versions
                }
            } catch {
                print("Error loading CoreML models: \(error)")
            }
        }

        return luminaVC
    }

    func updateUIViewController(_ uiViewController: LuminaViewController, context _: Context) {
        // Sync state changes from SwiftUI to the ViewController
        if uiViewController.position != position {
            uiViewController.position = position
        }
        if uiViewController.flashState != flashState {
            uiViewController.flashState = flashState
        }

        if let newZoom = commandedZoomFactor {
            uiViewController.setZoom(factor: newZoom)
            DispatchQueue.main.async {
                self.commandedZoomFactor = nil // Reset the command
            }
        }

        if resetZoomTrigger {
            uiViewController.resetZoom()
            DispatchQueue.main.async {
                self.resetZoomTrigger = false // Reset the command
            }
        }

        if captureTrigger {
            uiViewController.captureStillImage()
            DispatchQueue.main.async {
                self.captureTrigger = false
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self, photoStore: photoStore)
    }

    class Coordinator: NSObject, LuminaDelegate {
        var parent: LuminaCameraView
        var photoStore: PhotoStore

        init(_ parent: LuminaCameraView, photoStore: PhotoStore) {
            self.parent = parent
            self.photoStore = photoStore
        }

        func didUpdate(sessionStatus: LuminaSessionStatus, from _: LuminaViewController) {
            parent.sessionStatus = sessionStatus
        }

        func dismissed(controller _: LuminaViewController) {
            // This is now handled by the SwiftUI overlay's dismiss button
        }

        func captured(stillImage: UIImage, livePhotoAt _: URL?, depthData _: Any?, from _: LuminaViewController) {
            photoStore.addPhoto(stillImage)
        }

        func captured(videoAt _: URL, from _: LuminaViewController) {
            // Handle video if needed
        }

        func streamed(videoFrame _: UIImage, with predictions: [LuminaRecognitionResult]?, from controller: LuminaViewController) {
            guard let results = predictions, let firstResult = results.first else {
                return
            }

            if let landscapeBox = firstResult.personBoundingBox {
                let modelWidth = 448.0
                let modelHeight = 448.0

                let portraitBox = CGRect(
                    x: modelHeight - landscapeBox.centerX - landscapeBox.height,
                    y: landscapeBox.centerY,
                    width: landscapeBox.height,
                    height: landscapeBox.width
                )

                var normalizedRect = CGRect(
                    x: portraitBox.origin.x / modelHeight,
                    y: portraitBox.origin.y / modelWidth,
                    width: portraitBox.width / modelHeight,
                    height: portraitBox.height / modelWidth
                )

                normalizedRect.origin.x = 1.0 - normalizedRect.origin.x - normalizedRect.width
                normalizedRect.origin.y = 1.0 - normalizedRect.origin.y - normalizedRect.height

                let viewSpaceBox = controller.convertToViewCoordinates(fromNormalizedRect: normalizedRect)

                let screenBounds = controller.view.bounds
                let visibleBox = viewSpaceBox.intersection(screenBounds)

                if !visibleBox.isNull && !visibleBox.isEmpty {
                    let topLeft = visibleBox.origin
                    let topRight = CGPoint(x: visibleBox.maxX, y: visibleBox.minY)
                    let bottomLeft = CGPoint(x: visibleBox.minX, y: visibleBox.maxY)
                    let bottomRight = CGPoint(x: visibleBox.maxX, y: visibleBox.maxY)

                    print("""
                        --- Person Detected (Visible Part) ---
                        Camera Position: \(controller.position.rawValue)
                        Visible Bounding Box: \(visibleBox)
                        Top-Left: \(topLeft)
                        Top-Right: \(topRight)
                        Bottom-Left: \(bottomLeft)
                        Bottom-Right: \(bottomRight)
                        --------------------------------------
                        """)
                }
            }
        }
    }
}
