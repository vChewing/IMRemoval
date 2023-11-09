// (c) 2023 and onwards The vChewing Project (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

import SwiftUI

struct ContentView: View {
  @ObservedObject var viewModel = ViewModel.shared
  @State private var highlightedRoot: URL?
  @State private var highlightedUser: URL?
  @State private var highlightedRunning: URL?
  @State private var sortOrder = [KeyPathComparator(\BundleItem.path)]
  @State private var runningResults: [BundleItem] = []
  @State private var alertState: AlertState = .null {
    willSet {
      switch newValue {
      case .null: showAlert = false
      default: showAlert = true
      }
    }
  }

  @State private var showAlert = false

  enum AlertState {
    case null
    case promptForRemoval
    case listingRunningIMEsThatRemoved

    var title: String {
      switch self {
      case .null: ""
      case .promptForRemoval: "i18n:notice.willTrashTheTickedItems.title".i18n
      case .listingRunningIMEsThatRemoved: "i18n:notice.runningIMEs".i18n
      }
    }

    var message: String? {
      switch self {
      case .null: nil
      case .promptForRemoval: "i18n:notice.willTrashTheTickedItems.description".i18n
      case .listingRunningIMEsThatRemoved: nil
      }
    }
  }

  var body: some View {
    VStack(spacing: 5) {
      VSplitView {
        Table(viewModel.rootBundles, selection: $highlightedRoot, sortOrder: $sortOrder) {
          TableColumn("　", value: \.ticked, comparator: BoolComparator()) { thisLine in
            HStack {
              if let index = viewModel.rootBundles.firstIndex(where: { thisLine.id == $0.id }) {
                AnyView(Toggle("　", isOn: $viewModel.rootBundles[index].ticked).labelsHidden())
              } else {
                AnyView(EmptyView())
              }
              thisLine.bundleIcon.onTapGesture(count: 2) {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: thisLine.path)])
              }
            }
          }.width(42)
          TableColumn("i18n:fieldName.imeTitle", value: \.title) { thisLine in
            let url = URL(fileURLWithPath: thisLine.path)
            Text(thisLine.title).onTapGesture(count: 2) {
              NSWorkspace.shared.activateFileViewerSelecting([url])
            }
          }.width(170)
          TableColumn("i18n:fieldName.imeBundlePath.public", value: \.path) { thisLine in
            let url = URL(fileURLWithPath: thisLine.path)
            Text(thisLine.path).onTapGesture(count: 2) {
              NSWorkspace.shared.activateFileViewerSelecting([url])
            }
          }
        }.frame(minHeight: 200)
        Table(viewModel.userBundles, selection: $highlightedUser, sortOrder: $sortOrder) {
          TableColumn("　", value: \.ticked, comparator: BoolComparator()) { thisLine in
            HStack {
              if let index = viewModel.userBundles.firstIndex(where: { thisLine.id == $0.id }) {
                AnyView(Toggle("　", isOn: $viewModel.userBundles[index].ticked).labelsHidden())
              } else {
                AnyView(EmptyView())
              }
              thisLine.bundleIcon.onTapGesture(count: 2) {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: thisLine.path)])
              }
            }
          }.width(42)
          TableColumn("i18n:fieldName.imeTitle", value: \.title) { thisLine in
            let url = URL(fileURLWithPath: thisLine.path)
            Text(thisLine.title).onTapGesture(count: 2) {
              NSWorkspace.shared.activateFileViewerSelecting([url])
            }
          }.width(170)
          TableColumn("i18n:fieldName.imeBundlePath.currentUser", value: \.path) { thisLine in
            let url = URL(fileURLWithPath: thisLine.path)
            Text(thisLine.path).onTapGesture(count: 2) {
              NSWorkspace.shared.activateFileViewerSelecting([url])
            }
          }
        }.frame(minHeight: 100)
      }
      .font(.system(.body).monospacedDigit())
      HStack {
        Spacer()
        Button("i18n:button.openPublicFolder") {
          let path = NSSearchPathForDirectoriesInDomains(.inputMethodsDirectory, .localDomainMask, true).first
          guard let path = path else { return }
          NSWorkspace.shared.open(URL(fileURLWithPath: path))
        }
        Button("i18n:button.openUserSpaceFolder") {
          let path = NSSearchPathForDirectoriesInDomains(.inputMethodsDirectory, .userDomainMask, true).first
          guard let path = path else { return }
          NSWorkspace.shared.open(URL(fileURLWithPath: path))
        }
        Button("i18n:button.rescan") {
          Task {
            await scan()
          }
        }
        Button {
          alertState = .promptForRemoval
        } label: {
          Label(title: { Text("i18n:button.removeTickedIME").bold() }, icon: { Image(systemName: "trash") })
        }
        .disabled(viewModel.nothingTicked)
        .alert(alertState.title, isPresented: $showAlert) {
          Button("i18n:dialog.button.OK") {
            Task {
              withAnimation {
                switch alertState {
                case .listingRunningIMEsThatRemoved:
                  alertState = .null
                  runningResults.removeAll()
                case .null: break
                case .promptForRemoval:
                  runningResults = viewModel.trash()
                  if runningResults.isEmpty {
                    alertState = .null
                  } else {
                    alertState = .listingRunningIMEsThatRemoved
                  }
                }
              }
            }
          }
          if alertState == .promptForRemoval {
            Button("i18n:dialog.button.Cancel") {
              alertState = .null
            }
          }
        } message: {
          switch alertState {
          case .null: EmptyView()
          case .promptForRemoval:
            if let msg = alertState.message {
              Text(msg)
            }
          case .listingRunningIMEsThatRemoved:
            ForEach(runningResults) { resultItem in
              HStack {
                Text("\(resultItem.title) -> \(resultItem.path)")
              }
            }
          }
        }
      }.padding(.bottom, 10).padding([.horizontal], 10)
    }
    .frame(minWidth: 684, minHeight: 454, alignment: .center)
    .onAppear {
      Task {
        await scan()
      }
    }
  }

  private func scan() async {
    withAnimation {
      viewModel.scan(global: true)
      viewModel.scan(global: false)
    }
  }

  private struct BoolComparator: SortComparator {
    typealias Compared = Bool

    func compare(_ lhs: Bool, _ rhs: Bool) -> ComparisonResult {
      switch (lhs, rhs) {
      case (true, false):
        return order == .forward ? .orderedDescending : .orderedAscending
      case (false, true):
        return order == .forward ? .orderedAscending : .orderedDescending
      default: return .orderedSame
      }
    }

    var order: SortOrder = .forward
  }
}

#Preview {
  ContentView()
}

private extension String {
  var i18n: String {
    NSLocalizedString(self, comment: "")
  }
}
