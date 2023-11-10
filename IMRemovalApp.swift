// (c) 2023 and onwards The vChewing Project (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

import SwiftUI

@main
struct IMRemovalApp: App {
  var body: some Scene {
    WindowGroup {
      ContentView().onDisappear {
        NSApplication.shared.terminate(self)
      }
    }.commands {
      CommandGroup(replacing: CommandGroupPlacement.newItem) {}
    }
  }
}
