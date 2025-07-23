//
//  ContentView.swift
//  LuminaSample
//
//  Created by [Your Name] on 2025/07/23.
//

import CoreML
import Logging
import Lumina
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var photoStore: PhotoStore
    @State private var showCamera = false

    // Camera Settings
    @State private var position: CameraPosition = .back
    @State private var recordsVideo = false
    @State private var streamFrames = true
    @State private var trackMetadata = true
    @State private var captureLivePhotos = false
    @State private var captureDepthData = false
    @State private var streamDepthData = false
    @State private var textPrompt = ""
    @State private var resolution: CameraResolution = .high1920x1080
    @State private var frameRate: Int = 30
    @State private var useCoreMLModels = false
    @State private var isVideoStabilizationEnabled = false
    @State private var isFocusLockingEnabled = false
    @State private var loggingLevel: Logger.Level = .critical
    @State private var maxZoomScale: Float = 15.0

    // Camera UI State
    @State private var zoomFactor: Float = 1.0
    @State private var commandedZoomFactor: Float? = nil
    @State private var resetZoomTrigger = false
    @State private var captureTrigger = false
    @State private var flashState: FlashState = .off

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Camera Settings")) {
                    Toggle("Use Front Camera", isOn: Binding(
                        get: { self.position == .front },
                        set: { self.position = $0 ? .front : .back }
                    ))
                    Toggle("Record Video", isOn: self.$recordsVideo)
                    Toggle("Stream Frames", isOn: self.$streamFrames)
                    Toggle("Track Metadata", isOn: self.$trackMetadata)
                    Toggle("Capture Live Photos", isOn: self.$captureLivePhotos)
                    Toggle("Capture Depth Data", isOn: self.$captureDepthData)
                    Toggle("Stream Depth Data", isOn: self.$streamDepthData)
                    Toggle("Use CoreML Models", isOn: self.$useCoreMLModels)
                    Toggle("Enable Video Stabilization (OIS)", isOn: self.$isVideoStabilizationEnabled)
                    Toggle("Enable Focus Locking", isOn: self.$isFocusLockingEnabled)
                }

                Section(header: Text("Camera Configuration")) {
                    Picker("Resolution", selection: self.$resolution) {
                        ForEach(CameraResolution.allCases, id: \.self) { res in
                            Text(res.rawValue).tag(res)
                        }
                    }
                    Stepper("Frame Rate: \(self.frameRate)", value: self.$frameRate, in: 1...60)
                    HStack {
                        Text("Max Zoom")
                        Slider(value: self.$maxZoomScale, in: 1...15, step: 0.5)
                        Text(String(format: "%.1fx", self.maxZoomScale))
                    }
                }

                Section {
                    Button("Open Camera") {
                        self.showCamera = true
                    }
                }
            }
            .navigationTitle("Lumina SwiftUI")
            .fullScreenCover(isPresented: self.$showCamera) {
                CameraView(
                    zoomFactor: self.$zoomFactor,
                    commandedZoomFactor: self.$commandedZoomFactor,
                    resetZoomTrigger: self.$resetZoomTrigger,
                    captureTrigger: self.$captureTrigger,
                    flashState: self.$flashState,
                    position: self.$position,
                    recordsVideo: self.$recordsVideo,
                    streamFrames: self.$streamFrames,
                    trackMetadata: self.$trackMetadata,
                    captureLivePhotos: self.$captureLivePhotos,
                    captureDepthData: self.$captureDepthData,
                    streamDepthData: self.$streamDepthData,
                    resolution: self.$resolution,
                    frameRate: self.$frameRate,
                    useCoreMLModels: self.$useCoreMLModels,
                    isVideoStabilizationEnabled: self.$isVideoStabilizationEnabled,
                    isFocusLockingEnabled: self.$isFocusLockingEnabled,
                    maxZoomScale: self.$maxZoomScale
                )
                .environmentObject(self.photoStore)
                .onAppear {
                    self.zoomFactor = 1.0
                }
            }
        }
    }
}

struct CameraView: View {
    @EnvironmentObject var photoStore: PhotoStore
    @Environment(\.presentationMode) var presentationMode

    @Binding var zoomFactor: Float
    @Binding var commandedZoomFactor: Float?
    @Binding var resetZoomTrigger: Bool
    @Binding var captureTrigger: Bool
    @Binding var flashState: FlashState

    // Pass-through bindings for settings
    @Binding var position: CameraPosition
    @Binding var recordsVideo: Bool
    @Binding var streamFrames: Bool
    @Binding var trackMetadata: Bool
    @Binding var captureLivePhotos: Bool
    @Binding var captureDepthData: Bool
    @Binding var streamDepthData: Bool
    @Binding var resolution: CameraResolution
    @Binding var frameRate: Int
    @Binding var useCoreMLModels: Bool
    @Binding var isVideoStabilizationEnabled: Bool
    @Binding var isFocusLockingEnabled: Bool
    @Binding var maxZoomScale: Float

    var body: some View {
        ZStack {
            LuminaCameraView(
                isPresented: .constant(true),
                position: self.$position,
                flashState: self.$flashState,
                recordsVideo: self.$recordsVideo,
                streamFrames: self.$streamFrames,
                trackMetadata: self.$trackMetadata,
                captureLivePhotos: self.$captureLivePhotos,
                captureDepthData: self.$captureDepthData,
                streamDepthData: self.$streamDepthData,
                resolution: self.$resolution,
                frameRate: self.$frameRate,
                useCoreMLModels: self.$useCoreMLModels,
                isVideoStabilizationEnabled: self.$isVideoStabilizationEnabled,
                isFocusLockingEnabled: self.$isFocusLockingEnabled,
                maxZoomScale: self.$maxZoomScale,
                onZoomFactorChanged: { newFactor in
                    self.zoomFactor = newFactor
                },
                commandedZoomFactor: self.$commandedZoomFactor,
                resetZoomTrigger: self.$resetZoomTrigger,
                captureTrigger: self.$captureTrigger
            )
            .ignoresSafeArea()

            // Custom UI Overlay
            VStack {
                HStack {
                    Button(action: { self.presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                    }

                    Spacer()

                    Button(action: {
                        switch self.flashState {
                        case .off: self.flashState = .on
                        case .on: self.flashState = .auto
                        case .auto: self.flashState = .off
                        }
                    }) {
                        Image(systemName: self.flashState == .on ? "bolt.fill" : (self.flashState == .off ? "bolt.slash.fill" : "bolt.badge.a.fill"))
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 15)

                Spacer()

                Text(String(format: "%.1fx", self.zoomFactor))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(10)
                    .onTapGesture {
                        self.zoomFactor = 1.0
                        self.resetZoomTrigger = true
                    }

                HStack(alignment: .center) {
                    // Thumbnail
                    ZStack {
                        RoundedRectangle(cornerRadius: 8).stroke(Color.white, lineWidth: 2)
                        if let latestImage = photoStore.latestPhoto {
                            Image(uiImage: latestImage).resizable().scaledToFill().clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            Color.black.clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .frame(width: 60, height: 60)

                    Spacer()

                    // Shutter Button
                    Button(action: { self.captureTrigger = true }) {
                        ZStack {
                            Circle().strokeBorder(Color.white, lineWidth: 4).frame(width: 70, height: 70)
                            Circle().fill(Color.white).frame(width: 60, height: 60)
                        }
                    }

                    Spacer()

                    // Camera Switch Button
                    Button(action: {
                        self.position = (self.position == .back) ? .front : .back
                        // Reset zoom to 1x when switching cameras
                        self.zoomFactor = 1.0
                        self.resetZoomTrigger = true
                    }) {
                        Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                            .font(.largeTitle)
                            .foregroundColor(.white)
                    }
                    .frame(width: 60, height: 60)
                }
                .padding(.bottom, 30)
                .padding(.horizontal, 20)
            }
        }
    }
}

// UIImage and URL could be identifiable
extension UIImage: Identifiable { public var id: String { UUID().uuidString } }
extension URL: Identifiable { public var id: String { self.absoluteString } }
