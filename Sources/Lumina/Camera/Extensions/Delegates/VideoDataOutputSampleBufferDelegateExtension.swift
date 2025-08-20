//
//  VideoDataOutputSampleBufferDelegate.swift
//  Lumina
//
//  Created by David Okun on 11/20/17.
//  Copyright © 2017 David Okun. All rights reserved.
//

import AVFoundation
import Foundation

extension LuminaCamera: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from _: AVCaptureConnection) {
        guard let image = sampleBuffer.normalizedVideoFrame(forCamera: position) else {
            return
        }
        
        if streamingModels != nil {
            guard let recognizer = recognizer as? LuminaObjectRecognizer else {
                LuminaLogger.error(message: "models loaded, but could not use object recognizer")
                DispatchQueue.main.async {
                    self.delegate?.videoFrameCaptured(camera: self, frame: image)
                }
                return
            }
            
            recognizer.recognize(from: image, completion: { results in
                DispatchQueue.main.async {
                    self.delegate?.videoFrameCaptured(camera: self, frame: image, predictedObjects: results)
                }
            })
        } else {
            DispatchQueue.main.async {
                self.delegate?.videoFrameCaptured(camera: self, frame: image)
            }
        }
    }
}
