// SPDX-License-Identifier: MPL-2.0

import SwiftUI
import UIKit

@MainActor
final class FitKikuAppDelegate: NSObject, UIApplicationDelegate {
    let model: AppModel

    override init() {
        let isUnitTest = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        #if DEBUG
        if let scenario = DemoScenario.from(environment: ProcessInfo.processInfo.environment) {
            model = AppModel.syntheticDemo(scenario)
        } else {
            model = AppModel(installHealthObserversAtLaunch: !isUnitTest)
        }
        #else
        model = AppModel(installHealthObserversAtLaunch: !isUnitTest)
        #endif
        super.init()
    }

}

@main
struct FitKikuApp: App {
    @UIApplicationDelegateAdaptor(FitKikuAppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView(model: appDelegate.model)
                .task {
                    guard scenePhase == .active,
                          !appDelegate.model.isSyntheticDemo,
                          ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
                    else { return }
                    await appDelegate.model.restore()
                }
                .onOpenURL { url in
                    Task { await appDelegate.model.openPairLink(url) }
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    guard let url = activity.webpageURL else { return }
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
