cask "agents-status-bar" do
  version "0.5.1"
  sha256 "968d7845bef67db6d185822ffe588c7cede5c4049f61d076fc308f72e2ee5032"

  url "https://github.com/90ms/agents-status-bar/releases/download/v#{version}/AgentsStatusBar-#{version}.zip"
  name "Agents Status Bar"
  desc "Menu bar usage monitor for AI coding agents"
  homepage "https://github.com/90ms/agents-status-bar"

  depends_on arch: :arm64
  depends_on macos: :sonoma

  app "Agents Status Bar.app"

  zap trash: [
    "~/Library/Application Support/AgentsStatusBar",
    "~/Library/Preferences/dev.agentsstatusbar.app.plist",
  ]

  caveats <<~EOS
    If macOS blocks the first launch of an ad-hoc signed release, approve
    Agents Status Bar in System Settings > Privacy & Security.
  EOS
end
