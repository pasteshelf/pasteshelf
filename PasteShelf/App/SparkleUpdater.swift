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
            updater = controller.updater
            controller.startUpdater()
        }

        // MARK: Internal

        var canCheckForUpdates: Bool {
            updater.canCheckForUpdates
        }

        func checkForUpdates() {
            updater.checkForUpdates()
        }

        // MARK: Private

        private let updater: SPUUpdater
    }
#endif
