//
//  LuminaView.swift
//  LuminaSwiftUISample
//
//  Created by [Your Name] on 2025/07/23.
//

import SwiftUI
import Lumina

struct LuminaView: UIViewControllerRepresentable {
    @Binding var capturedImage: UIImage?
    @Binding var capturedVideoURL: URL?

    func makeUIViewController(context: Context) -> LuminaViewController {
        let luminaVC = LuminaViewController()
        luminaVC.delegate = context.coordinator
        return luminaVC
    }

    func updateUIViewController(_ uiViewController: LuminaViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, LuminaDelegate {
        var parent: LuminaView

        init(_ parent: LuminaView) {
            self.parent = parent
        }

        func dismissed(controller: LuminaViewController) {
            controller.dismiss(animated: true)
        }

        func captured(stillImage: UIImage, livePhotoAt: URL?, depthData: Any?, from controller: LuminaViewController) {
            parent.capturedImage = stillImage
            controller.dismiss(animated: true)
        }

        func captured(videoAt: URL, from controller: LuminaViewController) {
            parent.capturedVideoURL = videoAt
            controller.dismiss(animated: true)
        }
    }
}
