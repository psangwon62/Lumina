//
//  CaptureDeviceHandlerExtension.swift
//  Lumina
//
//  Created by David Okun on 11/20/17.
//  Copyright © 2017 David Okun. All rights reserved.
//

import Foundation
import AVFoundation

extension LuminaCamera {
  func getNewVideoInputDevice() -> AVCaptureDeviceInput? {
    do {
      guard let device = getDevice(with: self.position == .front ? AVCaptureDevice.Position.front : AVCaptureDevice.Position.back) else {
        LuminaLogger.error(message: "could not find valid AVCaptureDevice")
        return nil
      }
      let input = try AVCaptureDeviceInput(device: device)
      return input
    } catch {
      return nil
    }
  }

  func getNewAudioInputDevice() -> AVCaptureDeviceInput? {
    do {
      guard let device = AVCaptureDevice.default(for: AVMediaType.audio) else {
        return nil
      }
      let deviceInput = try AVCaptureDeviceInput(device: device)
      return deviceInput
    } catch {
      return nil
    }
  }

  func purgeAudioDevices() {
    LuminaLogger.notice(message: "purging old audio devices on capture session")
    for oldInput in self.session.inputs where oldInput == self.audioInput {
      self.session.removeInput(oldInput)
    }
  }

  func purgeVideoDevices() {
    LuminaLogger.notice(message: "purging old video devices on capture session")
    for oldInput in self.session.inputs where oldInput == self.videoInput {
      self.session.removeInput(oldInput)
    }
    for oldOutput in self.session.outputs {
      if oldOutput == self.videoDataOutput || oldOutput == self.photoOutput || oldOutput == self.metadataOutput || oldOutput == self.videoFileOutput {
        self.session.removeOutput(oldOutput)
      }
      if let dataOutput = oldOutput as? AVCaptureVideoDataOutput {
        self.session.removeOutput(dataOutput)
      }
      if let depthOutput = oldOutput as? AVCaptureDepthDataOutput {
        self.session.removeOutput(depthOutput)
      }
    }
  }

  func getDevice(with position: AVCaptureDevice.Position) -> AVCaptureDevice? {
    // For the back camera, we want the best virtual camera available.
    if position == .back {
        var bestDevice: AVCaptureDevice?
        if #available(iOS 13.0, *) {
            // Prefer the triple camera, then dual wide, then dual.
            if let device = AVCaptureDevice.default(.builtInTripleCamera, for: .video, position: .back) {
                bestDevice = device
            } else if let device = AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back) {
                bestDevice = device
            } else if let device = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) {
                bestDevice = device
            }
        }

        // If we found a virtual camera, use it.
        if let device = bestDevice {
            LuminaLogger.notice(message: "Using virtual device: \(device.localizedName)")
            self.currentCaptureDevice = device
            return device
        }
    }
    
    // Otherwise, or for the front camera, fall back to the standard wide-angle camera.
    if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) {
        LuminaLogger.notice(message: "Using fallback or front device: \(device.localizedName)")
        self.currentCaptureDevice = device
        return device
    }
    
    return nil
  }

  func configureFrameRate() {
    guard let device = self.currentCaptureDevice else {
      return
    }
    for vFormat in device.formats {
      let dimensions = CMVideoFormatDescriptionGetDimensions(vFormat.formatDescription)
      let ranges = vFormat.videoSupportedFrameRateRanges as [AVFrameRateRange]
      guard let frameRate = ranges.first else {
        continue
      }
      if frameRate.maxFrameRate >= Float64(self.frameRate) &&
          frameRate.minFrameRate <= Float64(self.frameRate) &&
          self.resolution.getDimensions().width == dimensions.width &&
          self.resolution.getDimensions().height == dimensions.height &&
          CMFormatDescriptionGetMediaSubType(vFormat.formatDescription) == 875704422 { // meant for full range 420f
        do {
          try device.lockForConfiguration()
          device.activeFormat = vFormat as AVCaptureDevice.Format
          device.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: Int32(self.frameRate))
          device.activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: Int32(self.frameRate))
          device.unlockForConfiguration()
          break
        } catch {
          continue
        }
      }
    }
  }

  func updateZoom() {
    guard let input = self.videoInput else {
      return
    }
    let device = input.device
    do {
      try device.lockForConfiguration()
      let newZoomScale = min(maxZoomScale, max(Float(device.minAvailableVideoZoomFactor), min(currentZoomScale, Float(device.maxAvailableVideoZoomFactor))))
      device.videoZoomFactor = CGFloat(newZoomScale)
      device.unlockForConfiguration()
    } catch {
      device.unlockForConfiguration()
    }
  }
}
