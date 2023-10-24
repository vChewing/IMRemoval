// (c) 2023 and onwards The vChewing Project (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

import AppKit
import FolderMonitor
import SwiftUI

public class ViewModel: ObservableObject {
  public static let shared = ViewModel()

  @Published var rootBundles: [BundleItem] = []
  @Published var userBundles: [BundleItem] = []

  private var folderMonitorRoot: FolderMonitor?
  private var folderMonitorUser: FolderMonitor?

  private init() {
    let pathRoot = NSSearchPathForDirectoriesInDomains(.inputMethodsDirectory, .localDomainMask, true).first
    if let pathRoot = pathRoot {
      folderMonitorRoot = .init(url: URL(fileURLWithPath: pathRoot))
      folderMonitorRoot?.folderDidChange = { [weak self] in
        guard let self = self else { return }
        self.scan(global: true)
      }
    }

    let pathUser = NSSearchPathForDirectoriesInDomains(.inputMethodsDirectory, .userDomainMask, true).first
    if let pathUser = pathUser {
      folderMonitorUser = .init(url: URL(fileURLWithPath: pathUser))
      folderMonitorUser?.folderDidChange = { [weak self] in
        guard let self = self else { return }
        self.scan(global: false)
      }
    }
  }

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
        let url = URL(fileURLWithPath: pathStr).appendingPathComponent(contentStr)
        guard let bundle = Bundle(url: url) else { return }
        if global {
          rootBundles.append(bundle.asBundleItem)
        } else {
          userBundles.append(bundle.asBundleItem)
        }
      }
    }
  }

  @discardableResult public func trash() -> [BundleItem] {
    var runningApps = [NSRunningApplication]()
    let toTrashA: [BundleItem] = rootBundles.filter(\.ticked)
    let toTrashB: [BundleItem] = userBundles.filter(\.ticked)
    var toTrash: [BundleItem] = toTrashA + toTrashB
    toTrash.append(contentsOf: userBundles.filter(\.ticked))
    var urls = [URL]()
    toTrash.forEach { bundleItem in
      do {
        try FileManager.default.trashItem(at: bundleItem.url, resultingItemURL: nil)
      } catch {
        urls.append(bundleItem.url)
      }
      runningApps.append(
        contentsOf: NSRunningApplication.runningApplications(
          withBundleIdentifier: bundleItem.identifier ?? ""
        )
      )
    }
    if !urls.isEmpty {
      NSWorkspace.shared.activateFileViewerSelecting(urls)
    }
    if !toTrashA.isEmpty { scan(global: true) }
    if !toTrashB.isEmpty { scan(global: false) }
    return runningApps.map(\.asBundleItem)
  }
}

public struct BundleItem: Hashable, Identifiable {
  public var ticked: Bool
  public var title: String
  public var url: URL
  public var path: String
  public var iconString: String
  public var identifier: String?
  public var executableName: String?

  public init(ticked: Bool = false, title: String, url: URL, iconString: String, identifier: String?, executableName: String?) {
    self.ticked = ticked
    self.title = title
    self.url = url
    self.iconString = iconString
    self.identifier = identifier
    self.executableName = executableName
    path = url.path
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
      identifier: bundleIdentifier,
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
    let result = bundleURL.appendingPathComponent("Contents/Resources/\(iconStr)").path
    return result
  }
}

public extension NSRunningApplication {
  var asBundleItem: BundleItem {
    guard let url = bundleURL, let bundle = Bundle(url: url) else {
      return .init(
        title: bundleTitle, url: bundleURL ?? executableURL ?? URL(fileURLWithPath: "/dev/null"),
        iconString: iconPath,
        identifier: bundleIdentifier,
        executableName: executableURL?.lastPathComponent
      )
    }
    return bundle.asBundleItem
  }

  var bundleTitle: String {
    guard let url = bundleURL, let bundle = Bundle(url: url) else { return "PID: \(processIdentifier)" }
    return bundle.bundleTitle
  }

  var iconPath: String {
    guard let url = bundleURL, let bundle = Bundle(url: url) else { return "" }
    return bundle.iconPath
  }
}
