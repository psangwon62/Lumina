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
    private static let ciContext = CIContext()

    func normalizedVideoFrame(forCamera: CameraPosition) -> UIImage? {
        return autoreleasepool {
            LuminaLogger.notice(message: "normalizing video frame from CMSampleBuffer")

            guard let imageBuffer = CMSampleBufferGetImageBuffer(self) else {
                return nil
            }

            let coreImage = CIImage(cvPixelBuffer: imageBuffer)

            guard let sample: CGImage = CMSampleBuffer.ciContext.createCGImage(coreImage, from: coreImage.extent) else {
                return nil
            }

            let result = UIImage(
                cgImage: sample,
                scale: 1.0,
                orientation: getImageOrientation(forCamera: forCamera)
            )
            return result
        }
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
