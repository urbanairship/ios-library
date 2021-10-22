/* Copyright Airship and Contributors */

import SwiftUI

struct LayoutsList: View {
    
    //Retrieve the list of layouts template names from the 'Layouts' folder
    let layoutsArray = getLayoutsList();
    
    var body: some View {
        NavigationView {
            List {
                ForEach(layoutsArray, id: \.self) { layoutFileName in
                    NavigationLink(destination: LayoutView(fileName: layoutFileName)) {
                        Text(layoutFileName)
                    }
                }
            }
            .navigationTitle("Airship Layouts")
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        LayoutsList()
    }
}
