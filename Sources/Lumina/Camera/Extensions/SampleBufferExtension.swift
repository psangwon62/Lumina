//
//  SampleBufferExtension.swift
//  Lumina
//
//  Created by David Okun on 11/20/17.
//  Copyright © 2017 David Okun. All rights reserved.
//

import AVFoundation
import UIKit

extension CMSampleBuffer {
    func normalizedVideoFrame(forCamera: CameraPosition) -> UIImage? {
        LuminaLogger.notice(message: "normalizing video frame from CMSampleBbuffer")
        guard let imageBuffer = CMSampleBufferGetImageBuffer(self) else {
            return nil
        }
        let coreImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()
        guard let sample: CGImage = context.createCGImage(coreImage, from: coreImage.extent) else {
            return nil
        }
        return UIImage(cgImage: sample, scale: 1.0, orientation: getImageOrientation(forCamera: forCamera))
    }

    private func getImageOrientation(forCamera: CameraPosition) -> UIImage.Orientation {
        switch LuminaViewController.orientation {
            case .landscapeLeft:
                return forCamera == .back ? .down : .upMirrored
            case .landscapeRight:
                return forCamera == .back ? .up : .downMirrored
            case .portraitUpsideDown:
                return forCamera == .back ? .left : .rightMirrored
            case .portrait:
                return forCamera == .back ? .right : .leftMirrored
            case .unknown:
                return forCamera == .back ? .right : .leftMirrored
            @unknown default:
                return forCamera == .back ? .right : .leftMirrored
        }
    }
}
