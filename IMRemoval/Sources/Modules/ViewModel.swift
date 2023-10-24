// (c) 2023 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import SwiftUI

public class ViewModel: ObservableObject {
  public static let shared = ViewModel()

  @Published var rootBundles: [BundleItem] = []
  @Published var userBundles: [BundleItem] = []

  private init() {}

  public var nothingTicked: Bool {
    rootBundles.filter(\.ticked).count + userBundles.filter(\.ticked).count == 0
  }

  public func scan(global: Bool) {
    if global {
      rootBundles.removeAll()
    } else {
      userBundles.removeAll()
    }
    let domainMask: FileManager.SearchPathDomainMask = global ? .localDomainMask : .userDomainMask
    let directories = NSSearchPathForDirectoriesInDomains(.inputMethodsDirectory, domainMask, true)
    for pathStr in directories {
      let contents = (try? FileManager.default.contentsOfDirectory(atPath: pathStr)) ?? [String]()
      guard !contents.isEmpty else { return }
      contents.forEach { contentStr in
        let url = URL(filePath: pathStr).appending(path: contentStr)
        guard let bundle = Bundle(url: url) else { return }
        if global {
          rootBundles.append(bundle.asBundleItem)
        } else {
          userBundles.append(bundle.asBundleItem)
        }
      }
    }
  }

  public func trash() {
    let toTrashA: [BundleItem] = rootBundles.filter(\.ticked)
    let toTrashB: [BundleItem] = userBundles.filter(\.ticked)
    var toTrash: [BundleItem] = toTrashA + toTrashB
    toTrash.append(contentsOf: userBundles.filter(\.ticked))
    var urls = [URL]()
    toTrash.forEach { bundleItem in
      if let executableName = bundleItem.executableName {
        let killTask = Process()
        killTask.launchPath = "/usr/bin/killall"
        killTask.arguments = [executableName]
        killTask.launch()
        killTask.waitUntilExit()
      }
      do {
        try FileManager.default.trashItem(at: bundleItem.url, resultingItemURL: nil)
      } catch {
        urls.append(bundleItem.url)
      }
    }
    if !urls.isEmpty {
      NSWorkspace.shared.activateFileViewerSelecting(urls)
    }
    if !toTrashA.isEmpty { scan(global: true) }
    if !toTrashB.isEmpty { scan(global: false) }
  }
}

public struct BundleItem: Hashable, Identifiable {
  public var ticked: Bool
  public var title: String
  public var url: URL
  public var path: String
  public var iconString: String
  public var executableName: String?

  public init(ticked: Bool = false, title: String, url: URL, iconString: String, executableName: String?) {
    self.ticked = ticked
    self.title = title
    self.url = url
    self.iconString = iconString
    self.executableName = executableName
    path = url.path(percentEncoded: false)
  }

  public var id: URL { url }

  public var bundleIcon: some View {
    if let nsImage = NSImage(contentsOfFile: iconString) {
      Image(nsImage: nsImage).resizable().frame(width: 16, height: 16)
    } else {
      Image(.appIconFallback).resizable().frame(width: 16, height: 16)
    }
  }
}

public extension Bundle {
  var asBundleItem: BundleItem {
    .init(
      title: bundleTitle, url: bundleURL,
      iconString: iconPath,
      executableName: executableURL?.lastPathComponent
    )
  }

  var bundleTitle: String {
    (localizedInfoDictionary ?? infoDictionary)?["CFBundleName"] as? String ?? bundleURL.lastPathComponent
  }

  var iconPath: String {
    var iconStr = infoDictionary?["CFBundleIconFile"] as? String ?? "AppIcon"
    if iconStr.suffix(5).lowercased() != ".icns" {
      iconStr.append(".icns")
    }
    let result = bundleURL.appending(path: "Contents/Resources/\(iconStr)").path(percentEncoded: false)
    return result
  }
}
