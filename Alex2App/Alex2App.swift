import SwiftUI

@main
struct Alex2App: App {
    @StateObject private var model = AlexModel()
    var body: some Scene {
        WindowGroup { MainView().environmentObject(model).preferredColorScheme(.dark) }
    }
}
