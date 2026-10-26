import SwiftUI

struct EditorRootView: View {
    let model: EditorModel
    let actions: EditorActions

    var body: some View {
        VStack(spacing: 0) {
            EditorToolbarView(model: model, actions: actions)
            Divider()
            EditorCanvas(model: model)
        }
    }
}
