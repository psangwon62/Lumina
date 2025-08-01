//
//  ViewControllerButtonFunctions.swift
//  Lumina
//
//  Created by David Okun on 11/20/17.
//  Copyright © 2017 David Okun. All rights reserved.
//

import UIKit

extension LuminaViewController {
  @objc func cancelButtonTapped() {
    LuminaLogger.notice(message: "cancel button tapped")
    delegate?.dismissed(controller: self)
  }

  @objc func shutterButtonTapped() {
    LuminaLogger.notice(message: "shutter button tapped")
    shutterButton.takePhoto()
    previewLayer.opacity = 0
    UIView.animate(withDuration: 0.25) {
      self.previewLayer.opacity = 1
    }
    guard let camera = self.camera else {
      return
    }
    camera.captureStillImage()
  }

  @objc func shutterButtonLongPressed(_ sender: UILongPressGestureRecognizer) {
    LuminaLogger.notice(message: "shutter button long pressed")
    guard let camera = self.camera else {
      return
    }
    switch sender.state {
      case .began:
        if recordsVideo && !camera.recordingVideo {
          LuminaLogger.notice(message: "Attempting to start recording video")
          shutterButton.startRecordingVideo()
          camera.startVideoRecording()
        }
      case .ended:
        if recordsVideo && camera.recordingVideo {
          LuminaLogger.notice(message: "Attempting to stop recording video")
          shutterButton.stopRecordingVideo()
          camera.stopVideoRecording()
        } else {
          LuminaLogger.error(message: "Cannot record video")
          feedbackGenerator.errorFeedback()
        }
      default:
        break
    }
  }

  @objc func switchButtonTapped() {
    LuminaLogger.notice(message: "camera switch button tapped")
    switch self.position {
      case .back:
        self.position = .front
      default:
        self.position = .back
    }
  }

  @objc func flashButtonTapped() {
    LuminaLogger.notice(message: "flash button tapped")
    guard let camera = self.camera, self.position == .back else {
      LuminaLogger.notice(message: "camera not found, or on front camera, so flash is unavailable")
      self.camera?.flashState = .off
      self.flashButton.updateFlashIcon(to: SystemButtonType.FlashState.off)
      return
    }
    switch camera.flashState {
      case .off:
        LuminaLogger.notice(message: "flash mode changed to on")
        camera.flashState = .on
        self.flashButton.updateFlashIcon(to: SystemButtonType.FlashState.on)
      case .on:
        LuminaLogger.notice(message: "flash mode changed to auto")
        camera.flashState = .auto
        self.flashButton.updateFlashIcon(to: SystemButtonType.FlashState.auto)
      case .auto:
        LuminaLogger.notice(message: "flash mode changed to off")
        camera.flashState = .off
        self.flashButton.updateFlashIcon(to: SystemButtonType.FlashState.off)
    }
  }
}
