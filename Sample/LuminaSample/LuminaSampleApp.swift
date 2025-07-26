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
