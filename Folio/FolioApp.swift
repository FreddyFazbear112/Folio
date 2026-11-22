import SwiftUI
import FirebaseCore

@main
struct FolioApp: App {
    @StateObject private var library = LibraryStore()
    @StateObject private var auth = AuthManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(library)
                .environmentObject(auth)
                .preferredColorScheme(.light)
        }
    }
}
