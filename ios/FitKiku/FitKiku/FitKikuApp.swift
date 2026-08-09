import SwiftUI
import UIKit

@MainActor
final class FitKikuAppDelegate: NSObject, UIApplicationDelegate {
    let model: AppModel

    override init() {
        #if DEBUG
        if let scenario = DemoScenario.from(environment: ProcessInfo.processInfo.environment) {
            model = AppModel.syntheticDemo(scenario)
        } else {
            model = AppModel()
        }
        #else
        model = AppModel()
        #endif
        super.init()
    }

    func application(
        _: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        guard !model.isSyntheticDemo,
              ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
        else {
            return true
        }
        Task { await model.restore() }
        return true
    }
}

@main
struct FitKikuApp: App {
    @UIApplicationDelegateAdaptor(FitKikuAppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView(model: appDelegate.model)
                .onOpenURL { url in
                    Task { await appDelegate.model.openPairLink(url) }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active,
                          !appDelegate.model.isSyntheticDemo,
                          ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
                    else { return }
                    Task { await appDelegate.model.restore() }
                }
        }
    }
}
