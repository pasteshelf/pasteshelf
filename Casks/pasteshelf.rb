cask "pasteshelf" do
  version "__VERSION__"
  sha256 "__SHA256__"

  url "https://github.com/pasteshelf/PasteShelf/releases/download/v#{version}/PasteShelf-#{version}.dmg"
  name "PasteShelf"
  desc "Privacy-first clipboard manager for macOS"
  homepage "https://github.com/pasteshelf/PasteShelf"

  depends_on macos: ">= :sonoma"

  app "PasteShelf.app"

  zap trash: [
    "~/Library/Application Support/PasteShelf",
    "~/Library/Caches/com.pasteshelf.PasteShelf",
    "~/Library/Preferences/com.pasteshelf.PasteShelf.plist",
  ]
end
