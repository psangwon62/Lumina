//
//  ContentView.swift
//  LuminaSample
//
//  Created by [Your Name] on 2025/07/23.
//

import SwiftUI
import Lumina
import CoreML
import Logging

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
    @State private var loggingLevel: Logger.Level = .critical
    @State private var maxZoomScale: Float = 15.0
    
    // Camera UI State
    @State private var zoomFactor: Float = 1.0
    @State private var commandedZoomFactor: Float? = nil
    @State private var captureTrigger = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Camera Settings")) {
                    Toggle("Use Front Camera", isOn: Binding(
                        get: { self.position == .front },
                        set: { self.position = $0 ? .front : .back }
                    ))
                    Toggle("Record Video", isOn: $recordsVideo)
                    Toggle("Stream Frames", isOn: $streamFrames)
                    Toggle("Track Metadata", isOn: $trackMetadata)
                    Toggle("Capture Live Photos", isOn: $captureLivePhotos)
                    Toggle("Capture Depth Data", isOn: $captureDepthData)
                    Toggle("Stream Depth Data", isOn: $streamDepthData)
                    Toggle("Use CoreML Models", isOn: $useCoreMLModels)
                    Toggle("Enable Video Stabilization (OIS)", isOn: $isVideoStabilizationEnabled)
                }

                Section(header: Text("Camera Configuration")) {
                    Picker("Resolution", selection: $resolution) {
                        ForEach(CameraResolution.allCases, id: \.self) { res in
                            Text(res.rawValue).tag(res)
                        }
                    }
                    Stepper("Frame Rate: \(frameRate)", value: $frameRate, in: 1...60)
                    HStack {
                        Text("Max Zoom")
                        Slider(value: $maxZoomScale, in: 1...15, step: 0.5)
                        Text(String(format: "%.1fx", maxZoomScale))
                    }
                }
                
                Section {
                    Button("Open Camera") {
                        self.showCamera = true
                    }
                }
            }
            .navigationTitle("Lumina SwiftUI")
            .fullScreenCover(isPresented: $showCamera) {
                CameraView(
                    zoomFactor: $zoomFactor,
                    commandedZoomFactor: $commandedZoomFactor,
                    captureTrigger: $captureTrigger,
                    position: $position,
                    recordsVideo: $recordsVideo,
                    streamFrames: $streamFrames,
                    trackMetadata: $trackMetadata,
                    captureLivePhotos: $captureLivePhotos,
                    captureDepthData: $captureDepthData,
                    streamDepthData: $streamDepthData,
                    resolution: $resolution,
                    frameRate: $frameRate,
                    useCoreMLModels: $useCoreMLModels,
                    isVideoStabilizationEnabled: $isVideoStabilizationEnabled,
                    maxZoomScale: $maxZoomScale
                )
                .environmentObject(photoStore)
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
    @Binding var captureTrigger: Bool
    
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
    @Binding var maxZoomScale: Float

    var body: some View {
        ZStack {
            LuminaCameraView(
                isPresented: .constant(true),
                position: $position,
                recordsVideo: $recordsVideo,
                streamFrames: $streamFrames,
                trackMetadata: $trackMetadata,
                captureLivePhotos: $captureLivePhotos,
                captureDepthData: $captureDepthData,
                streamDepthData: $streamDepthData,
                resolution: $resolution,
                frameRate: $frameRate,
                useCoreMLModels: $useCoreMLModels,
                isVideoStabilizationEnabled: $isVideoStabilizationEnabled,
                maxZoomScale: $maxZoomScale,
                onZoomFactorChanged: { newFactor in
                    self.zoomFactor = newFactor
                },
                commandedZoomFactor: $commandedZoomFactor,
                captureTrigger: $captureTrigger
            )
            .ignoresSafeArea()

            // Custom UI Overlay
            VStack {
                HStack {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding()
                    }
                    Spacer()
                    Text(String(format: "%.1fx", zoomFactor))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(10)
                        .onTapGesture {
                            self.commandedZoomFactor = 1.0
                        }
                    Spacer()
                    Rectangle().fill(Color.clear).frame(width: 44, height: 44)
                }
                .padding(.horizontal)
                
                Spacer()
                
                HStack(alignment: .center) {
                    Spacer()
                    Button(action: { self.captureTrigger = true }) {
                        ZStack {
                            Circle().strokeBorder(Color.white, lineWidth: 4).frame(width: 70, height: 70)
                            Circle().fill(Color.white).frame(width: 60, height: 60)
                        }
                    }
                    ZStack {
                        RoundedRectangle(cornerRadius: 8).stroke(Color.white, lineWidth: 2)
                        if let latestImage = photoStore.latestPhoto {
                            Image(uiImage: latestImage).resizable().scaledToFill().clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            Color.black.clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .frame(width: 60, height: 60)
                    .padding(.leading, 20)
                }
                .padding(.bottom, 30)
                .padding(.horizontal, 40)
            }
        }
    }
}

// UIImage and URL could be identifiable
extension UIImage: Identifiable { public var id: String { UUID().uuidString } }
extension URL: Identifiable { public var id: String { self.absoluteString } }
