//
//  LuminaSwiftUIView.swift
//  LuminaSample
//
//  Created by [Your Name] on 2025/07/23.
//

import SwiftUI
import Lumina
import AVFoundation

// 1. LuminaViewController를 SwiftUI에서 사용하기 위한 Wrapper
struct LuminaViewRepresentable: UIViewControllerRepresentable {
    @Binding var capturedImage: UIImage?
    @Binding var isPresented: Bool
    
    func makeUIViewController(context: Context) -> LuminaViewController {
        let luminaVC = LuminaViewController()
        luminaVC.delegate = context.coordinator
        // 기본 버튼들은 숨기고 SwiftUI 버튼을 사용
        luminaVC.setCancelButton(visible: false)
        luminaVC.setShutterButton(visible: false)
        luminaVC.setSwitchButton(visible: false)
        luminaVC.setFlashButton(visible: false)
        return luminaVC
    }
    
    func updateUIViewController(_ uiViewController: LuminaViewController, context: Context) {
        // SwiftUI에서 상태가 변경될 때 VC를 업데이트 할 수 있습니다.
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // 2. LuminaDelegate를 처리하기 위한 Coordinator
    class Coordinator: NSObject, LuminaDelegate {
        var parent: LuminaViewRepresentable
        
        init(_ parent: LuminaViewRepresentable) {
            self.parent = parent
        }
        
        func dismissed(controller: LuminaViewController) {
            parent.isPresented = false
        }
        
        func captured(stillImage: UIImage, livePhotoAt: URL?, depthData: Any?, from controller: LuminaViewController) {
            parent.capturedImage = stillImage
            parent.isPresented = false
        }
        
        func captured(videoAt: URL, from controller: LuminaViewController) {
            // 비디오 처리 로직 (필요 시 추가)
            parent.isPresented = false
        }
    }
}

// 3. 메인 SwiftUI 뷰
struct LuminaSwiftUIView: View {
    @State private var capturedImage: UIImage?
    @State private var isCameraPresented = true
    
    var body: some View {
        ZStack {
            if isCameraPresented {
                LuminaViewRepresentable(capturedImage: $capturedImage, isPresented: $isCameraPresented)
                    .ignoresSafeArea()
            } else {
                VStack {
                    if let image = capturedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                        Button("Take another photo") {
                            self.capturedImage = nil
                            self.isCameraPresented = true
                        }
                        .padding()
                    } else {
                        Text("No image captured.")
                        Button("Open Camera") {
                            self.isCameraPresented = true
                        }
                        .padding()
                    }
                }
            }
        }
    }
}
