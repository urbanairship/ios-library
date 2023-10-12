/* Copyright Airship and Contributors */

import AirshipCore
import SwiftUI
import WebKit


struct LayoutsList: View {

    let layouts: [LayoutFile]

    init(type: LayoutType) {
        self.layouts = Layouts.shared.layouts.filter { $0.type == type }
    }

    // Retrieve the list of layouts template names from the 'Layouts' folder

    @State var errorMessage: String?
    @State var showError: Bool = false
    
    @State private var configurationFileName = ""
    @State private var showBanner = false

    var body: some View {

        List {
            ForEach(self.layouts, id: \.self) { layout in
                Button(layout.fileName) {
                    do {
                        try Layouts.shared.openLayout(layout)
                    } catch {
                        self.showError = true
                        self.errorMessage = "Failed to open layout \(error)"
                    }
                }
            }
        }
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text(self.errorMessage ?? "error"),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        LayoutsList(type: .modal)
    }
}
