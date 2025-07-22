//
//  LuminaSampleApp.swift
//  LuminaSample
//
//  Created by [Your Name] on 2025/07/23.
//

import SwiftUI

@main
struct LuminaSampleApp: App {
    @StateObject private var photoStore = PhotoStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(photoStore)
        }
    }
}
