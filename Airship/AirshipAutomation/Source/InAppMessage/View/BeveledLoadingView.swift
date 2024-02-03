/* Copyright Airship and Contributors */

import SwiftUI

struct BeveledLoadingView: View {
    let opacity = 0.7

    var body: some View {
        ZStack {
            RoundedRectangle(cornerSize: CGSize(width: 16, height: 16), style: .continuous)
                .frame(width: 100, height:100)
                .opacity(0.7)
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint:Color.white.opacity(0.7)))
                .scaleEffect(2)
        }
    }
}

#Preview {
    BeveledLoadingView()
}
