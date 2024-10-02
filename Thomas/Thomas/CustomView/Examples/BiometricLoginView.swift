/* Copyright Airship and Contributors */

import SwiftUI
import LocalAuthentication

enum LoginState {
    case ready
    case authenticated
    case fallback
    case loading
}

@MainActor
class BiometricLoginViewModel:ObservableObject {
    init(context: LAContext = LAContext(), state: LoginState = .ready) {
        self.context = context
        self.state = state
    }
    
    var context:LAContext = LAContext()

    @Published var state:LoginState = .ready

    private func onAppear() {
        context.localizedCancelTitle = "Enter Username/Password"
    }

    func updateState(state:LoginState){
        withAnimation{
            self.state = state
        }
    }

    private func testPolicy(){
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            print(error?.localizedDescription ?? "Can't evaluate policy")

            self.updateState(state: .fallback)
            return
        }
    }

    func evaluatePolicy() {
        self.updateState(state: .loading)

        Task {
            do {

                try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Log in to your account")
                self.updateState(state: .authenticated)

            } catch let error {
                print(error.localizedDescription)
                self.updateState(state: .fallback)
            }
        }
    }
}

struct BiometricLoginView: View {
    @StateObject var viewModel:BiometricLoginViewModel = BiometricLoginViewModel()

    var loginButton: some View {
        Button(action: viewModel.evaluatePolicy) {
            HStack {
                Image(systemName: "faceid")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                Text("Login with Face ID").font(.title)
            }
            .padding()
            .foregroundColor(.white)
            .background(Color.cyan.opacity(0.7))
            .cornerRadius(8)
        }
    }

    var readyView: some View{
        VStack(alignment: .center) {
            Spacer()
            loginButton
            Spacer()
        }
    }

    var authenticatedView: some View{
        VStack(alignment: .center) {
            Spacer()
            Text("Authenticated!").font(.title).foregroundColor(.white)
            Spacer()
        }
    }

    var fallbackView: some View{
        VStack(alignment: .center) {
            Spacer()
            Text("Log in with password instead").font(.title).foregroundColor(.white)
            Spacer()
        }
    }

    var loadingView: some View{
        VStack(alignment: .center) {
            Spacer()
            Text("Loading...").font(.title).foregroundColor(.white)
            Spacer()
        }
    }

    private func makeGlassmorphic<T: View>(_ content: T) -> some View {
        ZStack(alignment: .center) {
            CameraView().edgesIgnoringSafeArea(.all).offset(x:40)

            LinearGradient(colors: [Color.cyan.opacity(0.7), Color.purple.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)

            Circle()
                .frame(width: 300)
                .foregroundColor(Color.blue.opacity(0.3))
                .blur(radius: 10)
                .offset(x: -100, y: -150)

            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .frame(width: 500, height: 500)
                .foregroundStyle(LinearGradient(colors: [Color.purple.opacity(0.6), Color.mint.opacity(0.5)], startPoint: .top, endPoint: .leading))
                .offset(x: 300)
                .blur(radius: 30)
                .rotationEffect(.degrees(30))

            Circle()
                .frame(width: 450)
                .foregroundStyle(Color.pink.opacity(0.6))
                .blur(radius: 20)
                .offset(x: 200, y: -200)
            content
        }
        .edgesIgnoringSafeArea(.all)
    }

    var body: some View {
        makeGlassmorphic(    Group {
            switch viewModel.state {
            case .ready:
                readyView
            case .authenticated:
                authenticatedView
            case .fallback:
                fallbackView
            case .loading:
                loadingView
            }
        }
      )
    }
}
