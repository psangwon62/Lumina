import SwiftUI
import Lumina
import CoreML

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
                    let detrModel = LuminaModel(model: try DETRResnet50().model, type: "DETRResnet50")
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

    func updateUIViewController(_ uiViewController: LuminaViewController, context: Context) {
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

        func didUpdate(sessionStatus: LuminaSessionStatus, from controller: LuminaViewController) {
            parent.sessionStatus = sessionStatus
        }

        func dismissed(controller: LuminaViewController) {
            // This is now handled by the SwiftUI overlay's dismiss button
        }

        func captured(stillImage: UIImage, livePhotoAt: URL?, depthData: Any?, from controller: LuminaViewController) {
            photoStore.addPhoto(stillImage)
        }

        func captured(videoAt: URL, from controller: LuminaViewController) {
            // Handle video if needed
        }
        
        func streamed(videoFrame: UIImage, with predictions: [LuminaRecognitionResult]?, from controller: LuminaViewController) {
            guard let results = predictions, let firstResult = results.first else {
                return
            }
            
            if let box = firstResult.personBoundingBox {
                // The model's output space (e.g., 448x448)
                let modelSize = CGSize(width: 448, height: 448)
                
                // Normalize the coordinates from model space (448x448) to normalized space (0.0-1.0)
                let normalizedRect = CGRect(
                    x: box.origin.x / modelSize.width,
                    y: box.origin.y / modelSize.height,
                    width: box.width / modelSize.width,
                    height: box.height / modelSize.height
                )
                
                // Use the helper method to convert normalized coordinates to view coordinates
                let viewSpaceBox = controller.convertToViewCoordinates(fromNormalizedRect: normalizedRect)
                
                // Print the coordinates as requested
                let topLeft = viewSpaceBox.origin
                let topRight = CGPoint(x: viewSpaceBox.maxX, y: viewSpaceBox.minY)
                let bottomLeft = CGPoint(x: viewSpaceBox.minX, y: viewSpaceBox.maxY)
                let bottomRight = CGPoint(x: viewSpaceBox.maxX, y: viewSpaceBox.maxY)
                
                print("""
                --- Person Detected ---
                Bounding Box (in View space): \(viewSpaceBox)
                Top-Left: \(topLeft)
                Top-Right: \(topRight)
                Bottom-Left: \(bottomLeft)
                Bottom-Right: \(bottomRight)
                ---------------------
                """)
            }
        }
    }
}
