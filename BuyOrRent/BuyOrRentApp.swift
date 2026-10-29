import SwiftUI

@main
struct BuyOrRentApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        #if os(macOS)
        .defaultSize(width: 1100, height: 780)
        #endif
    }
}
