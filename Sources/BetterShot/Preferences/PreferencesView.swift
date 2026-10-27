import BetterShotCore
import SwiftUI

struct PreferencesView: View {
    let model: SettingsModel
    let folderStore: any SaveFolderStoring
    let destinations: DestinationsCenter

    var body: some View {
        TabView {
            GeneralTab(model: model, folderStore: folderStore)
                .tabItem { Label("General", systemImage: "gearshape") }
            DestinationsTab(model: model, center: destinations)
                .tabItem { Label("Destinations", systemImage: "icloud.and.arrow.up") }
            ShortcutsTab(model: model)
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
        }
        .frame(width: 540, height: 440)
    }
}
