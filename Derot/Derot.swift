import SwiftUI
import Combine

@main struct Derot: App {
    @StateObject private var store = CharacterStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
