//
//  IMRemovalApp.swift
//  IMRemoval
//
//  Created by ShikiSuen on 2023/10/24.
//

import SwiftUI

@main
struct IMRemovalApp: App {
  var body: some Scene {
    WindowGroup {
      ContentView()
    }.commands {
      CommandGroup(replacing: CommandGroupPlacement.newItem) {}
    }
  }
}
