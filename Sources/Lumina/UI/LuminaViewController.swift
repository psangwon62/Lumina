//
//  CameraViewController.swift
//  CameraFramework
//
//  Created by David Okun on 8/29/17.
//  Copyright © 2017 David Okun. All rights reserved.
//

import UIKit
import AVFoundation
import CoreML
import Logging

/// The main class that developers should interact with and instantiate when using Lumina
open class LuminaViewController: UIViewController {
  internal var logger = Logger(label: "com.okun.Lumina")
  var camera: LuminaCamera?
  public var torchState: TorchState {
    get {
      return camera?.torchState ?? .off
    }
    set(newValue) {
      camera?.torchState = newValue
    }
  }
  
  public var flashState: FlashState {
      get {
          return camera?.flashState ?? .off
      }
      set(newValue) {
          camera?.flashState = newValue
      }
  }

  private var _previewLayer: AVCaptureVideoPreviewLayer?
  var previewLayer: AVCaptureVideoPreviewLayer {
    if let currentLayer = _previewLayer {
      return currentLayer
    }
    guard let camera = self.camera, let layer = camera.getPreviewLayer() else {
      return AVCaptureVideoPreviewLayer()
    }
    layer.frame = self.view.bounds
    _previewLayer = layer
    return layer
  }

  private var _zoomRecognizer: UIPinchGestureRecognizer?
  var zoomRecognizer: UIPinchGestureRecognizer {
    if let currentRecognizer = _zoomRecognizer {
      return currentRecognizer
    }
    let recognizer = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchGestureRecognizer(recognizer:)))
    recognizer.delegate = self
    _zoomRecognizer = recognizer
    return recognizer
  }

  private var _focusRecognizer: UITapGestureRecognizer?
  var focusRecognizer: UITapGestureRecognizer {
    if let currentRecognizer = _focusRecognizer {
      return currentRecognizer
    }
    let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleTapGestureRecognizer(recognizer:)))
    recognizer.delegate = self
    _focusRecognizer = recognizer
    return recognizer
  }

  private var _feedbackGenerator: LuminaHapticFeedbackGenerator?
  var feedbackGenerator: LuminaHapticFeedbackGenerator {
    if let currentGenerator = _feedbackGenerator {
      return currentGenerator
    }
    let generator = LuminaHapticFeedbackGenerator()
    _feedbackGenerator = generator
    return generator
  }

  private var _cancelButton: LuminaButton?
  var cancelButton: LuminaButton {
    if let currentButton = _cancelButton {
      return currentButton
    }
    let button = LuminaButton(with: SystemButtonType.cancel)
    button.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
    _cancelButton = button
    return button
  }

  private var _shutterButton: LuminaButton?
  var shutterButton: LuminaButton {
    if let currentButton = _shutterButton {
      return currentButton
    }
    let button = LuminaButton(with: SystemButtonType.shutter)
    button.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(shutterButtonTapped)))
    button.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(shutterButtonLongPressed)))
    _shutterButton = button
    return button
  }

  private var _switchButton: LuminaButton?
  var switchButton: LuminaButton {
    if let currentButton = _switchButton {
      return currentButton
    }
    let button = LuminaButton(with: SystemButtonType.cameraSwitch)
    button.addTarget(self, action: #selector(switchButtonTapped), for: .touchUpInside)
    _switchButton = button
    return button
  }

  private var _flashButton: LuminaButton?
  var flashButton: LuminaButton {
    if let currentButton = _flashButton {
      return currentButton
    }
    let button = LuminaButton(with: SystemButtonType.flash)
    button.addTarget(self, action: #selector(flashButtonTapped), for: .touchUpInside)
    _flashButton = button
    return button
  }

  private var _textPromptView: LuminaTextPromptView?
  var textPromptView: LuminaTextPromptView {
    if let existingView = _textPromptView {
      return existingView
    }
    let promptView = LuminaTextPromptView()
    _textPromptView = promptView
    return promptView
  }

  var focusOverlayView: UIView!
  var focusView: UIImageView!
  var isUpdating = false

  /// Set this to lock the focus on a tapped point, instead of resetting to continuous auto-focus.
  ///
  /// - Note: Defaults to false.
  open var isFocusLockingEnabled: Bool = false

  /// The image to be used for the focus view. If nil, a default system image will be used.
  open var focusImage: UIImage?

  /// The delegate for streaming output from Lumina
  weak open var delegate: LuminaDelegate?

  /// The position of the camera
  ///
  /// - Note: Responds live to being set at any time, and will update automatically
  open var position: CameraPosition = .back {
    didSet {
      LuminaLogger.notice(message: "Switching camera position to \(position.rawValue)")
      guard let camera = self.camera else {
        return
      }
      camera.position = position
    }
  }

  /// Set this to choose whether or not Lumina will be able to record video by holding down the capture button
  ///
  /// - Note: Responds live to being set at any time, and will update automatically
  ///
  /// - Warning: This setting takes precedence over video data streaming - if this is turned on, frames cannot be streamed, nor can CoreML be used via Lumina's recognizer mechanism.
  open var recordsVideo = false {
    didSet {
      LuminaLogger.notice(message: "Setting video recording mode to \(recordsVideo)")
      self.camera?.recordsVideo = recordsVideo
      if recordsVideo {
        LuminaLogger.warning(message: "frames cannot be streamed, nor can CoreML be used via Lumina's recognizer mechanism")
      }
    }
  }

  /// Set this to choose whether or not Lumina will stream video frames through the delegate
  ///
  /// - Note: Responds live to being set at any time, and will update automatically
  ///
  /// - Warning: Will not do anything if delegate is not implemented
  open var streamFrames = false {
    didSet {
      LuminaLogger.notice(message: "Setting frame streaming mode to \(streamFrames)")
      self.camera?.streamFrames = streamFrames
    }
  }

  /// Set this to choose whether or not Lumina will stream machine readable metadata through the delegate
  ///
  /// - Note: Responds live to being set at any time, and will update automatically
  ///
  /// - Warning: Will not do anything if delegate is not implemented
  open var trackMetadata = false {
    didSet {
      LuminaLogger.notice(message: "Setting metadata tracking mode to \(trackMetadata)")
      self.camera?.trackMetadata = trackMetadata
    }
  }

  /// Lumina comes ready with a view for a text prompt to give instructions to the user, and this is where you can set the text of that prompt
  ///
  /// - Note: Responds live to being set at any time, and will update automatically
  ///
  /// - Warning: If left empty, or unset, no view will be present, but view will be created if changed
  open var textPrompt = "" {
    didSet {
      LuminaLogger.notice(message: "Updating text prompt view to: \(textPrompt)")
      self.textPromptView.updateText(to: textPrompt)
    }
  }

  /// Set this to choose a resolution for the camera at any time - defaults to highest resolution possible for camera
  ///
  /// - Note: Responds live to being set at any time, and will update automatically
  open var resolution: CameraResolution = .highest {
    didSet {
      LuminaLogger.notice(message: "Updating camera resolution to \(resolution.rawValue)")
      self.camera?.resolution = resolution
    }
  }

  /// Set this to choose a frame rate for the camera at any time - defaults to 30 if query is not available
  ///
  /// - Note: Responds live to being set at any time, and will update automatically
  open var frameRate: Int = 30 {
    didSet {
      LuminaLogger.notice(message: "Attempting to update camera frame rate to \(frameRate) FPS")
      self.camera?.frameRate = frameRate
    }
  }

  /// Setting visibility of the buttons (default: all buttons are visible)
  public func setCancelButton(visible: Bool) {
    cancelButton.isHidden = !visible
  }

  public func setShutterButton(visible: Bool) {
    shutterButton.isHidden = !visible
  }

  public func setSwitchButton(visible: Bool) {
    switchButton.isHidden = !visible
  }

  public func setFlashButton(visible: Bool) {
    flashButton.isHidden = !visible
  }

  public func captureStillImage() {
    guard let camera = self.camera else {
        return
    }
    camera.captureStillImage()
  }

  public func pauseCamera() {
    self.camera?.stop()
  }

  public func setZoom(factor: Float, animated: Bool = true) {
    let hardwareFactor = factor * wideAngleZoomFactor
    guard let device = self.camera?.videoInput?.device else { return }
    do {
        try device.lockForConfiguration()
        if animated {
            // A rate of 1.0 is slow, 30.0 is very fast.
            device.ramp(toVideoZoomFactor: CGFloat(hardwareFactor), withRate: 10.0)
        } else {
            device.videoZoomFactor = CGFloat(hardwareFactor)
        }
        device.unlockForConfiguration()
    } catch {
        LuminaLogger.error(message: "Could not lock device for configuration: \(error)")
        device.unlockForConfiguration()
    }
  }

  public func resetZoom() {
    self.currentZoomScale = 1.0
    self.beginZoomScale = 1.0
    setZoom(factor: 1.0, animated: true)
  }

  public func startCamera() {
    self.camera?.start()
  }

  /// A collection of model types that will be used when streaming images for object recognition
  /// - Warning: If this is set, streamFrames is over-ridden to true
  open var streamingModels: [LuminaModel]? {
    didSet {
      self.camera?.streamingModels = streamingModels
      self.streamFrames = true
    }
  }

  /// The maximum amount of zoom that Lumina can use
  ///
  /// - Note: Default value will rely on whatever the active device can handle, if this is not explicitly set
  open var maxZoomScale: Float = MAXFLOAT {
    didSet {
      LuminaLogger.notice(message: "Max zoom scale set to \(maxZoomScale)x")
      self.camera?.maxZoomScale = maxZoomScale
    }
  }

  /// Set this to decide whether live photos will be captured whenever a still image is captured.
  ///
  /// - Note: Overrides cameraResolution to .photo
  ///
  /// - Warning: If video recording is enabled, live photos will not work.
  open var captureLivePhotos: Bool = false {
    didSet {
      LuminaLogger.notice(message: "Attempting to set live photo capture mode to \(captureLivePhotos)")
      self.camera?.captureLivePhotos = captureLivePhotos
    }
  }

  /// Set this to return AVDepthData with a still captured image
  ///
  /// - Note: Only works with .photo, .medium1280x720, and .vga640x480 resolutions
  open var captureDepthData: Bool = false {
    didSet {
      LuminaLogger.notice(message: "Attempting to set depth data capture mode to \(captureDepthData)")
      self.camera?.captureDepthData = captureDepthData
    }
  }

  /// Set this to return AVDepthData with streamed video frames
  ///
  /// - Note: Only works on iOS 11.0 or higher
  /// - Note: Only works with .photo, .medium1280x720, and .vga640x480 resolutions
  open var streamDepthData: Bool = false {
    didSet {
      LuminaLogger.notice(message: "Attempting to set depth data streaming mode to \(streamDepthData)")
      self.camera?.streamDepthData = streamDepthData
    }
  }

  /// Set this to enable video stabilization.
  ///
  /// - Note: This enables OIS (Optical Image Stabilization) if the device supports it.
  open var isVideoStabilizationEnabled: Bool = false {
    didSet {
      LuminaLogger.notice(message: "Setting video stabilization to \(isVideoStabilizationEnabled)")
      self.camera?.isVideoStabilizationEnabled = isVideoStabilizationEnabled
    }
  }

  /// Set this to apply a level of logging to Lumina, to track activity within the framework
  public static var loggingLevel: Logger.Level = .critical {
    didSet {
      LuminaLogger.level = loggingLevel
    }
  }

  /// The current zoom scale of the camera
  public var currentZoomScale: Float = 1.0
  
  var wideAngleZoomFactor: Float = 1.0
  public var onZoomDidChange: ((Float) -> Void)?
  var zoomObservation: NSKeyValueObservation?

  var beginZoomScale: Float = 1.0

  /// run this in order to create Lumina
  public init() {
    super.init(nibName: nil, bundle: nil)
    let camera = LuminaCamera()
    camera.delegate = self
    self.camera = camera
    if let version = LuminaViewController.getVersion() {
      LuminaLogger.info(message: "Loading Lumina v\(version)")
    }
  }
  
  deinit {
      zoomObservation?.invalidate()
      NotificationCenter.default.removeObserver(self)
  }

  @objc func cameraDeviceDidChange(_ notification: Notification) {
      // Hide the focus view when the camera changes
      self.focusView.alpha = 0.0

      guard let device = notification.object as? AVCaptureDevice else { return }
      
      // 1. Determine the hardware factor for the wide-angle lens (the "base" for our UI zoom)
      if device.position == .back && device.isVirtualDevice {
          if let factor = device.virtualDeviceSwitchOverVideoZoomFactors.first {
              self.wideAngleZoomFactor = Float(factor.doubleValue)
          } else {
              self.wideAngleZoomFactor = 1.0
          }
      } else {
          self.wideAngleZoomFactor = 1.0
      }
      
      // 2. Reset all UI-facing zoom states to 1.0x
      self.currentZoomScale = 1.0
      self.beginZoomScale = 1.0
      
      // 3. Update the UI label to show 1.0x
      self.onZoomDidChange?(1.0)
      
      // 4. Apply the reset 1.0x UI zoom to the hardware
      self.setZoom(factor: 1.0, animated: false)
  }

  @objc func subjectAreaDidChange(_ notification: Notification) {
      // Hide the focus view when the subject area changes
      self.focusView.alpha = 0.0
      
      // When the subject area changes, we should reset to continuous auto focus if focus lock is enabled.
      if self.isFocusLockingEnabled {
          LuminaLogger.notice(message: "Subject area changed, resetting to continuous auto focus.")
          self.camera?.resetCameraToContinuousExposureAndFocus()
      }
  }

  /// run this in order to create Lumina with a storyboard
  public required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    let camera = LuminaCamera()
    camera.delegate = self
    self.camera = camera
    if let version = LuminaViewController.getVersion() {
      LuminaLogger.info(message: "Loading Lumina v\(version)")
    }
  }

  /// override with caution
  open override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    LuminaLogger.error(message: "Camera framework is overloading on memory")
  }

  open override func viewDidLoad() {
      super.viewDidLoad()

      // Setup the overlay view for focus animations.
      focusOverlayView = UIView(frame: self.view.bounds)
      focusOverlayView.backgroundColor = .clear
      focusOverlayView.isUserInteractionEnabled = false
      focusOverlayView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      self.view.addSubview(focusOverlayView)

      // Create the focus view, respecting the custom focusImage if provided.
      let image = self.focusImage ?? UIImage(systemName: "camera.metering.partial")?.withTintColor(.white, renderingMode: .alwaysOriginal)
      focusView = UIImageView(image: image)
      focusView.contentMode = .scaleAspectFit
      focusView.frame = CGRect(x: 0, y: 0, width: 70, height: 70)
      focusView.alpha = 0.0
      
      // Add the focus view to the dedicated overlay view.
      focusOverlayView.addSubview(self.focusView)
  }

  /// override with caution
  open override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    createUI()
    updateUI(orientation: LuminaViewController.orientation)
    NotificationCenter.default.addObserver(self, selector: #selector(cameraDeviceDidChange), name: .luminaCameraDeviceChanged, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(subjectAreaDidChange), name: NSNotification.Name.AVCaptureDeviceSubjectAreaDidChange, object: nil)
    self.camera?.updateVideo { result in
      self.handleCameraSetupResult(result)
    }
    if self.recordsVideo {
      self.camera?.updateAudio { result in
        self.handleCameraSetupResult(result)
      }
    }
  }

  static var orientation: UIInterfaceOrientation {
    UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.windowScene?.interfaceOrientation  ?? .portrait
  }

  /// override with caution
  open override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    feedbackGenerator.prepare()
  }

  open override var shouldAutorotate: Bool {
    guard let camera = self.camera else {
      return true
    }
    return !camera.recordingVideo
  }

  /// override with caution
  open override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(true)
    self.camera?.stop()
  }

  /// override with caution
  open override func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()
    if self.camera?.recordingVideo == true {
      return
    }
    updateUI(orientation: LuminaViewController.orientation)
    updateButtonFrames()
  }

  /// override with caution
  open override var prefersStatusBarHidden: Bool {
    return true
  }

  /// returns a string of the version of Lumina currently in use, follows semantic versioning.
  open class func getVersion() -> String? {
    let bundle = Bundle(for: LuminaViewController.self)
    guard let infoDictionary = bundle.infoDictionary else {
      return nil
    }
    guard let versionString = infoDictionary["CFBundleShortVersionString"] as? String else {
      return nil
    }
    return versionString
  }
}
