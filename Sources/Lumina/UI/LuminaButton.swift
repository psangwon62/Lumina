//
//  LuminaButton.swift
//  Lumina
//
//  Created by David Okun on 9/11/17.
//  Copyright © 2017 David Okun. All rights reserved.
//

import UIKit

enum SystemButtonType {
  enum FlashState {
    //swiftlint:disable identifier_name
    case on
    case off
    case auto
  }

  case flash
  case cameraSwitch
  case photoCapture
  case cancel
  case shutter
}

final class LuminaButton: UIButton {
  private var squareSystemButtonWidth = 40
  private var squareSystemButtonHeight = 40
  private var cancelButtonWidth = 70
  private var cancelButtonHeight = 30
  private var shutterButtonDimension = 70
  private var style: SystemButtonType?
  private var symbolConfig = UIImage.SymbolConfiguration(pointSize: 25)
  private var border: UIView?
  private var _image: UIImage?
  var image: UIImage? {
    get {
      return _image
    }
    set {
      self.setImage(newValue, for: UIControl.State.normal)
      _image = newValue
    }
  }

  private var _text: String?
  var text: String? {
    get {
      return _text
    }
    set {
      self.setTitle(newValue, for: UIControl.State.normal)
      _text = newValue
    }
  }

  required init() {
    super.init(frame: CGRect.zero)
    self.backgroundColor = UIColor.clear
    if let titleLabel = self.titleLabel {
      titleLabel.textColor = UIColor.white
      titleLabel.font = UIFont.systemFont(ofSize: 20)
      titleLabel.textAlignment = .center
    }
  }

  init(with systemStyle: SystemButtonType) {
    super.init(frame: CGRect.zero)
    self.style = systemStyle
    self.backgroundColor = UIColor.clear
    if let titleLabel = self.titleLabel {
      titleLabel.textColor = UIColor.white
      titleLabel.font = UIFont.systemFont(ofSize: 20)
    }
    switch systemStyle {
      case .flash:
        self.image = UIImage(systemName: "bolt.slash.fill", withConfiguration: symbolConfig)?.withTintColor(.white, renderingMode: .alwaysOriginal)
        self.frame = CGRect(origin: CGPoint(x: 10, y: 10), size: CGSize(width: self.squareSystemButtonWidth, height: self.squareSystemButtonHeight))
      case .cameraSwitch:
        self.image = UIImage(systemName: "arrow.triangle.2.circlepath.camera.fill", withConfiguration: symbolConfig)?.withTintColor(.white, renderingMode: .alwaysOriginal)
        self.frame = CGRect(origin: CGPoint(x: UIScreen.main.bounds.maxX - 50, y: 10), size: CGSize(width: self.squareSystemButtonWidth, height: self.squareSystemButtonHeight))
      case .cancel:
        self.image = UIImage(systemName: "xmark.circle.fill", withConfiguration: symbolConfig)?.withTintColor(.white, renderingMode: .alwaysOriginal)
        self.frame = CGRect(origin: CGPoint(x: UIScreen.main.bounds.maxX - 50, y: 10), size: CGSize(width: self.squareSystemButtonWidth, height: self.squareSystemButtonHeight))
      case .shutter:
        self.backgroundColor = UIColor.normalState
        var minY = self.safeAreaLayoutGuide.layoutFrame.maxY
        minY -=  80
        self.frame = CGRect(origin: CGPoint(x: UIScreen.main.bounds.midX - 35, y: minY), size: CGSize(width: self.shutterButtonDimension, height: self.shutterButtonDimension))
        self.layer.cornerRadius = CGFloat(self.shutterButtonDimension / 2)
        self.layer.borderWidth = 3
        self.layer.borderColor = UIColor.borderNormalState
      default:
        break
    }
  }

  func startRecordingVideo() {
    if style == .shutter {
      DispatchQueue.main.async {
        UIView.animate(withDuration: 0.1, animations: {
          self.backgroundColor = UIColor.recordingState
          self.layer.borderColor = UIColor.borderRecordingState
          self.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
        })
      }
    }
  }

  func stopRecordingVideo() {
    if style == .shutter {
      DispatchQueue.main.async {
        UIView.animate(withDuration: 0.1, animations: {
          self.backgroundColor = UIColor.normalState
          self.layer.borderColor = UIColor.borderNormalState
          self.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
        })
      }
    }
  }

  func takePhoto() {
    if style == .shutter {
      DispatchQueue.main.async {
        UIView.animate(withDuration: 0.1, animations: {
          self.backgroundColor = UIColor.takePhotoState
          self.layer.borderColor = UIColor.borderTakePhotoState
        }, completion: { _ in
          UIView.animate(withDuration: 0.1, animations: {
            self.backgroundColor = UIColor.normalState
            self.layer.borderColor = UIColor.borderNormalState
          })
        })
      }
    }
  }

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }
}

extension LuminaButton {
  func updateFlashIcon(to state: SystemButtonType.FlashState) {
    guard let style = self.style, style == .flash else {
      return
    }
    switch state {
      case .on:
        self.image = UIImage(systemName: "bolt.fill", withConfiguration: symbolConfig)?.withTintColor(.white, renderingMode: .alwaysOriginal)
        LuminaLogger.debug(message: "flash icon updated to on")
      case .off:
        self.image = UIImage(systemName: "bolt.slash.fill", withConfiguration: symbolConfig)?.withTintColor(.white, renderingMode: .alwaysOriginal)
        LuminaLogger.debug(message: "flash icon updated to off")
      case .auto:
        self.image = UIImage(systemName: "bolt.badge.a.fill", withConfiguration: symbolConfig)?.withTintColor(.white, renderingMode: .alwaysOriginal)
        LuminaLogger.debug(message: "flash icon updated to auto")
    }
  }
}

fileprivate extension UIColor {
  class var normalState: UIColor {
    return UIColor(white: 1.0, alpha: 0.65)
  }

  class var recordingState: UIColor {
    return UIColor.red.withAlphaComponent(0.65)
  }

  class var takePhotoState: UIColor {
    return UIColor.lightGray.withAlphaComponent(0.65)
  }

  class var borderNormalState: CGColor {
    return UIColor.gray.cgColor
  }

  class var borderRecordingState: CGColor {
    return UIColor.red.cgColor
  }

  class var borderTakePhotoState: CGColor {
    return UIColor.darkGray.cgColor
  }
}
