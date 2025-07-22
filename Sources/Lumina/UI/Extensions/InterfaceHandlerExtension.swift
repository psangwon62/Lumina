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
    guard self.position == .back, let device = self.camera?.videoInput?.device else {
        return
    }

    if recognizer.state == .began {
        // Capture the current hardware zoom scale when the gesture starts
        beginZoomScale = self.currentZoomScale
    }

    let minZoom = Float(device.minAvailableVideoZoomFactor)
    let maxZoom = min(maxZoomScale, Float(device.maxAvailableVideoZoomFactor))
    
    let newZoomFactor = min(maxZoom, max(minZoom, beginZoomScale * Float(recognizer.scale)))

    do {
        try device.lockForConfiguration()
        device.videoZoomFactor = CGFloat(newZoomFactor)
        device.unlockForConfiguration()
    } catch {
        LuminaLogger.error(message: "Could not lock device for configuration: \(error)")
        device.unlockForConfiguration()
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
          if let camera = self.camera, let device = camera.videoInput?.device {
            self.enableUI(valid: true)
            self.updateUI(orientation: LuminaViewController.orientation)
            
            self.wideAngleZoomFactor = device.virtualDeviceSwitchOverVideoZoomFactors.first { $0.floatValue > 1.0 }?.floatValue ?? 1.0

            let initialZoomFactor = self.wideAngleZoomFactor
            
            // Manually set the device's zoom factor AND our internal state to match
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = CGFloat(initialZoomFactor)
                device.unlockForConfiguration()
                self.currentZoomScale = initialZoomFactor // Synchronize internal state
            } catch {
                LuminaLogger.error(message: "Could not lock device for initial zoom configuration: \(error)")
            }
            
            // Set up KVO to observe zoom factor changes. This is the single source of truth.
            self.zoomObservation = device.observe(\.videoZoomFactor, options: .new) { [weak self] _, change in
                guard let self = self, let newHardwareZoomFactor = change.newValue else { return }
                
                // Update the internal state
                self.currentZoomScale = Float(newHardwareZoomFactor)
                
                // Update the UI
                DispatchQueue.main.async {
                    self.onZoomDidChange?(Float(newHardwareZoomFactor) / self.wideAngleZoomFactor)
                }
            }
            
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
