//
//  ContentView.swift
//  LuminaSwiftUISample
//
//  Created by [Your Name] on 2025/07/23.
//

import SwiftUI
import Lumina

struct ContentView: View {
    @State private var showLumina = false
    @State private var capturedImage: UIImage?
    @State private var capturedVideoURL: URL?

    var body: some View {
        VStack {
            if let image = capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let videoURL = capturedVideoURL {
                // For simplicity, just showing a text view.
                // A real app would use AVPlayerViewController to play the video.
                Text("Captured video at: \(videoURL.path)")
            } else {
                Spacer()
                Text("Lumina SwiftUI Sample")
                    .font(.title)
                Spacer()
            }

            Button("Open Camera") {
                self.showLumina = true
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .sheet(isPresented: $showLumina) {
            LuminaView(capturedImage: $capturedImage, capturedVideoURL: $capturedVideoURL)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
