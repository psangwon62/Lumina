//
//  ViewControllerFocusHandlerExtension.swift
//  Lumina
//
//  Created by David Okun on 11/20/17.
//  Copyright © 2017 David Okun. All rights reserved.
//

import UIKit
import CoreGraphics

extension LuminaViewController {
  func focusCamera(at point: CGPoint) {
    // 1. Use the preview layer to get the correct device point for the camera.
    let devicePoint = self.previewLayer.captureDevicePointConverted(fromLayerPoint: point)
    
    // 2. Show the focus view at the tapped screen point.
    //    The showFocusView function is responsible for handling the UI.
    showFocusView(at: point)
    
    // 3. Tell the camera to focus at the specified point.
    camera?.handleFocus(at: devicePoint)
    
    // 4. If focus lock is NOT enabled, plan to reset to continuous focus after a delay.
    if !self.isFocusLockingEnabled {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.camera?.resetCameraToContinuousExposureAndFocus()
        }
    }
  }

  private func showFocusView(at point: CGPoint) {
    // Bring the dedicated overlay view to the front to ensure it's on top of other UI elements.
    self.view.bringSubviewToFront(self.focusOverlayView)
    self.focusView.center = point

    // Cancel any ongoing animations.
    self.focusView.layer.removeAllAnimations()

    // Set the animation's starting state: transparent and scaled up.
    self.focusView.alpha = 0.0
    self.focusView.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)

    // Animate to the final state: opaque and normal size.
    UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut, animations: {
        self.focusView.alpha = 1.0
        self.focusView.transform = .identity
    }, completion: { [weak self] _ in
        guard let self else { return }
        if self.isFocusLockingEnabled {
            // Focus is locked: wait 0.5s, then fade to partial opacity.
            UIView.animate(withDuration: 0.3, delay: 0.5, options: .curveEaseOut, animations: {
                self.focusView.alpha = 0.5
            })
        } else {
            // Focus is not locked: wait 0.5s, then fade out completely.
            UIView.animate(withDuration: 1.0, delay: 0.5, options: .curveEaseOut, animations: {
                self.focusView.alpha = 0.0
            })
        }
    })
  }
}
