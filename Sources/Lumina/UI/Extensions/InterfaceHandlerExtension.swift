//
//  InterfaceHandlerExtension.swift
//  Lumina
//
//  Created by David Okun on 11/20/17.
//  Copyright © 2017 David Okun. All rights reserved.
//

import UIKit
import AVFoundation

extension LuminaViewController {
  @objc func handlePinchGestureRecognizer(recognizer: UIPinchGestureRecognizer) {
    guard let device = self.camera?.videoInput?.device else { return }

    if recognizer.state == .began {
        // Ensure beginZoomScale is the UI-facing scale at the start of the gesture.
        // This is now correctly set by the gestureRecognizerShouldBegin delegate method
        // and maintained by this handler.
    }

    // Calculate the new UI-facing zoom scale based on the gesture.
    let newUIScale = beginZoomScale * Float(recognizer.scale)

    // Determine the effective maximum UI scale by considering BOTH the user-defined
    // `maxZoomScale` AND the hardware's physical limit converted to UI scale.
    let hardwareMax = Float(device.maxAvailableVideoZoomFactor)
    let effectiveMaxUIScale = min(self.maxZoomScale, hardwareMax / self.wideAngleZoomFactor)

    // Determine the effective minimum UI scale based on the hardware's physical limit.
    let hardwareMin = Float(device.minAvailableVideoZoomFactor)
    let effectiveMinUIScale = hardwareMin / self.wideAngleZoomFactor

    // Clamp the new UI scale between the effective minimum and maximum.
    let clampedUIScale = max(effectiveMinUIScale, min(newUIScale, effectiveMaxUIScale))

    // Apply the zoom to the hardware via our centralized function.
    setZoom(factor: clampedUIScale, animated: false)

    // Directly update our state and the UI text label. This is now the source of truth.
    self.currentZoomScale = clampedUIScale
    self.onZoomDidChange?(clampedUIScale)

    if recognizer.state == .ended || recognizer.state == .cancelled {
        // Update the beginZoomScale for the *next* gesture.
        beginZoomScale = clampedUIScale
    }
  }

  @objc func handleTapGestureRecognizer(recognizer: UITapGestureRecognizer) {
    delegate?.tapped(at: recognizer.location(in: view), from: self)
    if position == .back {
      focusCamera(at: recognizer.location(in: view))
    }
  }

  func createUI() {
    LuminaLogger.notice(message: "Creating UI")
    self.view.layer.addSublayer(self.previewLayer)
    self.view.addSubview(self.cancelButton)
    self.view.addSubview(self.shutterButton)
    self.view.addSubview(self.switchButton)
    self.view.addSubview(self.flashButton)
    self.view.addSubview(self.textPromptView)
    self.view.addGestureRecognizer(self.zoomRecognizer)
    self.view.addGestureRecognizer(self.focusRecognizer)
    enableUI(valid: false)
  }

  func enableUI(valid: Bool) {
    DispatchQueue.main.async {
      self.shutterButton.isEnabled = valid
      self.switchButton.isEnabled = valid
      self.flashButton.isEnabled = valid
    }
  }

  func updateUI(orientation: UIInterfaceOrientation) {
    LuminaLogger.notice(message: "updating UI for orientation: \(orientation.rawValue)")
    guard let connection = self.previewLayer.connection, connection.isVideoOrientationSupported else {
      return
    }
    self.previewLayer.frame = self.view.bounds
    connection.videoOrientation = necessaryVideoOrientation(for: orientation)
    self.camera?.updateOutputVideoOrientation(connection.videoOrientation)
  }

  func updateButtonFrames() {
    let frame = self.view.safeAreaLayoutGuide.layoutFrame
    self.switchButton.center = CGPoint(x: frame.maxX - 30, y: frame.minY + 25)
    self.cancelButton.center = CGPoint(x: frame.minX + 55, y: frame.maxY - 45)
    self.flashButton.center = CGPoint(x: frame.minX + 25, y: frame.minY + 25)
    self.shutterButton.center = CGPoint(x: frame.midX, y: frame.maxY - 45)

    let textWidth = frame.maxX - 110
    self.textPromptView.frame.size = CGSize(width: textWidth - 10, height: 80)
    self.textPromptView.layoutSubviews()
    self.textPromptView.center = CGPoint(x: frame.midX, y: frame.minY + 45)
  }

  // swiftlint:disable cyclomatic_complexity
  func handleCameraSetupResult(_ result: CameraSetupResult) {
    LuminaLogger.notice(message: "camera set up result: \(result.rawValue)")
    DispatchQueue.main.async {
      switch result {
        case .videoSuccess:
          if let camera = self.camera {
            self.enableUI(valid: true)
            self.updateUI(orientation: LuminaViewController.orientation)
            camera.start()
          }
        case .audioSuccess:
          break
        case .requiresUpdate:
          self.camera?.updateVideo({ result in
            self.handleCameraSetupResult(result)
          })
        case .videoPermissionDenied:
          self.textPrompt = "Camera permissions for Lumina have been previously denied - please access your privacy settings to change this."
        case .videoPermissionRestricted:
          self.textPrompt = "Camera permissions for Lumina have been restricted - please access your privacy settings to change this."
        case .videoRequiresAuthorization:
          self.camera?.requestVideoPermissions()
        case .audioPermissionRestricted:
          self.textPrompt = "Audio permissions for Lumina have been restricted - please access your privacy settings to change this."
          DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.textPrompt = ""
          }
        case .audioRequiresAuthorization:
          self.camera?.requestAudioPermissions()
        case .audioPermissionDenied:
          self.textPrompt = "Audio permissions for Lumina have been previously denied - please access your privacy settings to change this."
          DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.textPrompt = ""
          }
        case .invalidVideoDataOutput,
            .invalidVideoInput,
            .invalidPhotoOutput,
            .invalidVideoMetadataOutput,
            .invalidVideoFileOutput,
            .invalidAudioInput,
            .invalidDepthDataOutput:
          self.textPrompt = "\(result.rawValue) - please try again"
        case .unknownError:
          self.textPrompt = "Unknown error occurred while loading Lumina - please try again"
      }
    }
  }

  private func necessaryVideoOrientation(for statusBarOrientation: UIInterfaceOrientation) -> AVCaptureVideoOrientation {
    switch statusBarOrientation {
      case .portrait:
        return AVCaptureVideoOrientation.portrait
      case .landscapeLeft:
        return AVCaptureVideoOrientation.landscapeLeft
      case .landscapeRight:
        return AVCaptureVideoOrientation.landscapeRight
      case .portraitUpsideDown:
        return AVCaptureVideoOrientation.portraitUpsideDown
      default:
        return AVCaptureVideoOrientation.portrait
    }
  }
}
