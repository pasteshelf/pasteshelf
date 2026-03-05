#if !APP_STORE
import Combine
import Sparkle

final class SparkleUpdaterController: ObservableObject {
    private let updater: SPUUpdater

    init() {
        let controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        self.updater = controller.updater
        controller.startUpdater()
    }

    var canCheckForUpdates: Bool {
        updater.canCheckForUpdates
    }

    func checkForUpdates() {
        updater.checkForUpdates()
    }
}
#endif
