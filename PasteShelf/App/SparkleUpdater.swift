#if !APP_STORE
    import Combine
    import Sparkle

    final class SparkleUpdaterController: ObservableObject {
        // MARK: Lifecycle

        init() {
            let controller = SPUStandardUpdaterController(
                startingUpdater: false,
                updaterDelegate: nil,
                userDriverDelegate: nil
            )
            self.updater = controller.updater
            controller.startUpdater()
        }

        // MARK: Internal

        var canCheckForUpdates: Bool {
            self.updater.canCheckForUpdates
        }

        func checkForUpdates() {
            self.updater.checkForUpdates()
        }

        // MARK: Private

        private let updater: SPUUpdater
    }
#endif
