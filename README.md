<p align="center">
	<img src="./Assets/luminaLogo.png">
</p>

<p align="center">
    <a href="https://api.travis-ci.org/dokun1/Lumina.svg?branch=master">
        <img src="https://api.travis-ci.org/dokun1/Lumina.svg?branch=master" alt="Travis CI Status">
    </a>
	<a href="https://choosealicense.com/licenses/mit/">
		<img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT License">
	</a>
	<a href="https://github.com/RichardLitt/standard-readme">
		<img src="https://img.shields.io/badge/standard--readme-OK-green.svg" alt="Standard README Compliant">
	</a>
	<a href="https://img.shields.io/cocoapods/p/Lumina.svg?style=flat">
		<img src="https://img.shields.io/cocoapods/p/Lumina.svg?style=flat" alt="Platforms">
	</a>
</p>

----------------

Would you like to use a fully-functional camera in an iOS application in seconds? Would you like to do CoreML image recognition in just a few more seconds on the same camera? Lumina is here to help.

<p align="center">
	<a href="https://www.youtube.com/watch?v=8eEAvcy708s" target="_blank">
		<img src="https://img.youtube.com/vi/8eEAvcy708s/0.jpg">
	</a>
</p>


Cameras are used frequently in iOS applications, and the addition of `CoreML` and `Vision` to iOS 11 has precipitated a rash of applications that perform live object recognition from images - whether from a still image or via a camera feed.

Writing `AVFoundation` code can be fun, if not sometimes interesting. `Lumina` gives you an opportunity to skip having to write `AVFoundation` code, and gives you the tools you need to do anything you need with a camera you've already built.

<p align="center">
	<img src="./Assets/luminaDemo.gif">
</p>

Lumina can:

- capture still images
- capture videos
- capture live photos
- capture depth data for still images from dual camera systems
- stream video frames to a delegate
- scan any QR or barcode and output its metadata
- detect the presence of a face and its location
- use any CoreML compatible model to stream object predictions from the camera feed

## Table of Contents

- [Requirements](#requirements)
- [Background](#background)
- [Install](#install)
- [Usage](#usage)
- [Maintainers](#maintainers)
- [Contribute](#contribute)
- [License](#license)

## Requirements

- Xcode 12.0+ (by loading Swift 4 Toolchain)
- iOS 13.0
- Swift 5.2

## Background

[David Okun](https://twitter.com/dokun24) has experience working with image processing, and he thought it would be a nice thing to have a camera module that allows you to stream images, capture photos and videos, and have a module that lets you plug in a CoreML model, and it streams the object predictions back to you alongside the video frames.

## Contribute

See [the contribute file](CONTRIBUTING.md)!

PRs accepted.

Small note: If editing the README, please conform to the [standard-readme](https://github.com/RichardLitt/standard-readme) specification.

## Install

Lumina fully supports Swift Package Manager. You can either add the repo url in your Xcode project or in your Package.swift file under dependencies.

## Usage

**NB**: This repository contains a sample application. This application is designed to demonstrate the entire feature set of the library. We recommend trying this application out.

### Initialization

Consider that the main use of `Lumina` is to present a `ViewController`. Here is an example of what to add inside a boilerplate `ViewController`:

```swift
import Lumina

```

We recommend creating a single instance of the camera in your ViewController as early in your lifecycle as possible with:

```swift
let camera = LuminaViewController()
```

Presenting `Lumina` goes like so:

```swift
present(camera, animated: true, completion:nil)
```

**Remember to add a description for `Privacy - Camera Usage Description` and `Privacy - Microphone Usage Description` in your `Info.plist` file, so that system permissions are handled properly.**

### Logging

Lumina allows you to set a level of logging for actions happening within the module. The logger in use is [swift-log](https://github.com/apple/swift-log), made by the [Swift Server Working Group](https://github.com/swift-server) team. The deeper your level of logging, the more you'll see in your console.

**NB**: While Lumina is licensed by the MIT license, [swift-log](https://github.com/apple/swift-log) is licensed by [Apache 2.0](https://github.com/apple/swift-log/blob/master/LICENSE.txt). A copy of the license is also included in the source code.

To set a level of logging, set the static var on `LuminaViewController` like so:

```swift
LuminaViewController.loggingLevel = .notice
```

Levels read like so, from least to most logging:

- CRITICAL
- ERROR
- WARNING
- NOTICE
- INFO
- DEBUG
- TRACE

### Functionality

There are a number of properties you can set before presenting `Lumina`. You can set them before presentation, or during use, like so:

```swift
camera.position = .front // could also be .back
camera.recordsVideo = true // if this is set, streamFrames and streamingModel are invalid
camera.streamFrames = true // could also be false
camera.textPrompt = "This is how to test the text prompt view" // assigning an empty string will make the view fade away
camera.trackMetadata = true // could also be false
camera.resolution = .highest // follows an enum
camera.captureLivePhotos = true // for this to work, .resolution must be set to .photo
camera.captureDepthData = true // for this to work, .resolution must be set to .photo, .medium1280x720, or .vga640x480
camera.streamDepthData = true // for this to work, .resolution must be set to .photo, .medium1280x720, or .vga640x480
camera.frameRate = 60 // can be any number, defaults to 30 if selection cannot be loaded
camera.maxZoomScale = 5.0 // not setting this defaults to the highest zoom scale for any given camera device
```

### Object Recognition

**NB:** This only works for iOS 11.0 and up.

You must have a `CoreML` compatible model(s) to try this. Ensure that you drag the model file(s) into your project file, and add it to your current application target.

The sample in this repository comes with the `MobileNet` and `SqueezeNet` image recognition models, but again, any `CoreML` compatible model will work with this framework. Assign your model(s) to the framework using the convenient class called `LuminaModel` like so:

```swift
camera.streamingModels = [LuminaModel(model: MobileNet().model, type: "MobileNet"), LuminaModel(model: SqueezeNet().model, type: "SqueezeNet")]
```

You are now set up to perform live video object recognition.

### Handling output

To handle any output, such as still images, video frames, or scanned metadata, you will need to make your controller adhere to `LuminaDelegate` and assign it like so:

```swift
camera.delegate = self
```

Because the functionality of the camera can be updated at runtime, all delegate functions are required.

To handle the `Cancel` button being pushed, which is likely used to dismiss the camera in most use cases, implement:

```swift
func dismissed(controller: LuminaViewController) {
    // here you can call controller.dismiss(animated: true, completion:nil)
}
```

To handle a still image being captured with the photo shutter button, implement:

```swift
func captured(stillImage: UIImage, livePhotoAt: URL?, depthData: Any?, from controller: LuminaViewController) {
        controller.dismiss(animated: true) {
    // still images always come back through this function, but live photos and depth data are returned here as well for a given still image
    // depth data must be manually cast to AVDepthData, as AVDepthData is only available in iOS 11.0 or higher.
}
```

To handle a video being captured with the photo shutter button being held down, implement:

```swift
func captured(videoAt: URL, from controller: LuminaViewController) {
    // here you can load the video file from the URL, which is located in NSTemporaryDirectory()
}
```

**NB**: It's import to note that, if you are in video recording mode with Lumina, streaming frames is not possible. In order to enable frame streaming, you must set `.recordsVideo` to false, and `.streamFrames` to true.

To handle a video frame being streamed from the camera, implement:

```swift
func streamed(videoFrame: UIImage, from controller: LuminaViewController) {
    // here you can take the image called videoFrame and handle it however you'd like
}
```

To handle depth data being streamed from the camera on iOS 11.0 or higher, implement:
```swift
func streamed(depthData: Any, from controller: LuminaViewController) {
    // here you can take the depth data and handle it however you'd like
    // NB: you must cast the object to AVDepthData manually. It is returned as Any to maintain backwards compatibility with iOS 10.0
}
```

To handle metadata being detected and streamed from the camera, implement: 

```swift
func detected(metadata: [Any], from controller: LuminaViewController) {
    // here you can take the metadata and handle it however you'd like
    // you must find the right kind of data to downcast from, whether it is of a barcode, qr code, or face detection
}
```

To handle the user tapping the screen (outside of a button), implement:

```swift
func tapped(from controller: LuminaViewController, at: CGPoint) {
    // here you can take the position of the tap and handle it however you'd like
    // default behavior for a tap is to focus on tapped point
}
```

To handle a `CoreML` model and its predictions being streamed with each video frame, implement:
```swift
func streamed(videoFrame: UIImage, with predictions: [LuminaRecognitionResult]?, from controller: LuminaViewController) {
  guard let predicted = predictions else {
    return
  }
  var resultString = String()
  for prediction in predicted {
    guard let values = prediction.predictions else {
      continue
    }
    guard let bestPrediction = values.first else {
      continue
    }
    resultString.append("\(String(describing: prediction.type)): \(bestPrediction.name)" + "\r\n")
  }
  controller.textPrompt = resultString
}
```

Note that this returns a class type representation associated with the detected results. The example above also makes use of the built-in text prompt mechanism for Lumina.

### Changing the user interface

To adapt the user interface to your needs, you can set the visibility of the buttons by calling these methods on `LuminaViewController`:

```swift
camera.setCancelButton(visible: Bool)
camera.setShutterButton(visible: Bool)
camera.setSwitchButton(visible: Bool)
camera.setFlashButton(visible: Bool)
```

Per default, all of the buttons are visible.

### Adding your own controls outside the camera view

For some UI designs, apps may want to embed `LuminaViewController` within a custom View Controler, adding controls adjacent to the camera view rather than putting all the controls inside the camera view. 

Here is a code snippet that demonstrates adding a flash buttons and controlling the camera zoom level via the externally accessible API:
```swift
class MyCustomViewController: UIViewController {
    @IBOutlet weak var flashButton: UIButton!
    @IBOutlet weak var zoomButton: UIButton!
    var luminaVC: LuminaViewController? //set in prepare(for segue:) via the embed segue in the storyboard
    var flashState: FlashState = .off
    var zoomLevel:Float = 2.0
    let flashOnImage = UIImage(named: "Flash_On") //assumes an image with this name is in your Assets Library
    let flashOffImage = UIImage(named: "Flash_Off") //assumes an image with this name is in your Assets Library
    let flashAutoImage = UIImage(named: "Flash_Auto") //assumes an image with this name is in your Assets Library

    override public func viewDidLoad() {
        super.viewDidLoad()

        luminaVC?.delegate = self
        luminaVC?.trackMetadata = true
        luminaVC?.position = .back
        luminaVC?.setFlashButton(visible: false)
        luminaVC?.setCancelButton(visible: false)
        luminaVC?.setSwitchButton(visible: false)
        luminaVC?.setShutterButton(visible: false)
        luminaVC?.camera?.flashState = flashState
        luminaVC?.currentZoomScale = zoomLevel
    }

    override public func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if segue.identifier == "Lumina" { //name this segue in storyboard
            self.luminaVC = segue.destination as? LuminaViewController
        }
    }

    @IBAction func flashTapped(_ sender: Any) {
        switch flashState {
            case .off:
                flashState = .on
                flashButton.setImage(flashOnImage, for: .normal)
            case .on:
                flashState = .auto
                flashButton.setImage(flashAutoImage, for: .normal)
            case .auto:
                flashState = .off
                flashButton.setImage(flashOffImage, for: .normal)
        }
        luminaVC?.camera?.flashState = flashState
    }

    @IBAction func zoomTapped(_ sender: Any) {
        if zoomLevel == 1.0 {
            zoomLevel = 2.0
            zoomButton.setTitle("2x", for: .normal)
        } else {
            zoomLevel = 1.0
            zoomButton.setTitle("1x", for: .normal)
        }
        luminaVC?.currentZoomScale = zoomLevel
    }
```

```

## Maintainers

- David Okun [![Twitter Follow](https://img.shields.io/twitter/follow/dokun24.svg?style=social&label=Follow)](https://twitter.com/dokun24) [![GitHub followers](https://img.shields.io/github/followers/dokun1.svg?style=social&label=Follow)](https://github.com/dokun1) 
- Richard Littauer [![Twitter Follow](https://img.shields.io/twitter/follow/richlitt.svg?style=social&label=Follow)](https://twitter.com/richlitt) [![GitHub followers](https://img.shields.io/github/followers/RichardLitt.svg?style=social&label=Follow)](https://github.com/RichardLitt)
- Daniel Conde [![Twitter Follow](https://img.shields.io/twitter/follow/danielconde7.svg?style=social&label=Follow)](https://twitter.com/danielconde7) [![GitHub followers](https://img.shields.io/github/followers/dconde7.svg?style=social&label=Follow)](https://github.com/dconde7)
- Zach Falgout [![Twitter Follow](https://img.shields.io/twitter/follow/ZFalgout1.svg?style=social&label=Follow)](https://twitter.com/ZFalgout1) [![GitHub followers](https://img.shields.io/github/followers/ZFalgout.svg?style=social&label=Follow)](https://github.com/ZFalgout)  
- Gerriet Backer [![Twitter Follow](https://img.shields.io/twitter/follow/gerriet.svg?style=social&label=Follow)](https://twitter.com/gerriet) [![GitHub followers](https://img.shields.io/github/followers/gerriet.svg?style=social&label=Follow)](https://github.com/gerriet)
- Greg Heo [![Twitter Follow](https://img.shields.io/twitter/follow/gregheo.svg?style=social&label=Follow)](https://twitter.com/gregheo) [![GitHub followers](https://img.shields.io/github/followers/gregheo.svg?style=social&label=Follow)](https://github.com/gregheo)

## License

[MIT](LICENSE) © 2019 David Okun
