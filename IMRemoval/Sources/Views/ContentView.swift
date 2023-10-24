// (c) 2023 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import SwiftUI

struct ContentView: View {
  @ObservedObject var viewModel = ViewModel.shared
  @State private var highlightedRoot: URL?
  @State private var highlightedUser: URL?
  @State private var sortOrder = [KeyPathComparator(\BundleItem.path)]
  @State private var alertTitle = "i18n:notice.willTrashTheTickedItems.title".i18n
  @State private var alertDescription = "i18n:notice.willTrashTheTickedItems.description".i18n
  @State private var showAlert = false

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
              thisLine.bundleIcon
            }
          }.width(42)
          TableColumn("i18n:fieldName.imeTitle", value: \.title).width(170)
          TableColumn("i18n:fieldName.imeBundlePath.public", value: \.path)
        }.frame(minHeight: 200)
        Table(viewModel.userBundles, selection: $highlightedUser, sortOrder: $sortOrder) {
          TableColumn("　", value: \.ticked, comparator: BoolComparator()) { thisLine in
            HStack {
              if let index = viewModel.userBundles.firstIndex(where: { thisLine.id == $0.id }) {
                AnyView(Toggle("　", isOn: $viewModel.userBundles[index].ticked).labelsHidden())
              } else {
                AnyView(EmptyView())
              }
              thisLine.bundleIcon
            }
          }.width(42)
          TableColumn("i18n:fieldName.imeTitle", value: \.title).width(170)
          TableColumn("i18n:fieldName.imeBundlePath.currentUser", value: \.path)
        }.frame(minHeight: 100)
      }
      .font(.system(.body).monospacedDigit())
      HStack {
        Spacer()
        Button("i18n:button.openPublicFolder") {
          let path = NSSearchPathForDirectoriesInDomains(.inputMethodsDirectory, .localDomainMask, true).first
          guard let path = path else { return }
          NSWorkspace.shared.open(URL(filePath: path))
        }
        Button("i18n:button.openUserSpaceFolder") {
          let path = NSSearchPathForDirectoriesInDomains(.inputMethodsDirectory, .userDomainMask, true).first
          guard let path = path else { return }
          NSWorkspace.shared.open(URL(filePath: path))
        }
        Button("i18n:button.rescan") {
          Task {
            await scan()
          }
        }
        Button {
          showAlert = true
        } label: {
          Label(title: { Text("i18n:button.removeTickedIME").bold() }, icon: { Image(systemName: "trash") })
        }
        .disabled(viewModel.nothingTicked)
        .alert(alertTitle, isPresented: $showAlert) {
          Button("i18n:dialog.button.OK") {
            showAlert = false
            Task {
              withAnimation {
                viewModel.trash()
              }
            }
          }
          Button("i18n:dialog.button.Cancel") {
            showAlert = false
          }
        } message: {
          Text(alertDescription)
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
