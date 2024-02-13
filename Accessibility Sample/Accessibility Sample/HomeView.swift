/* Copyright Urban Airship and Contributors */

import SwiftUI
import AirshipCore

struct HomeView: View {

    private func trackAndToast(customEventName:String) {
        let customEventPreamble = "Tracked custom event:\n"

        let event = CustomEvent(name: customEventName, value: 1)
        event.track()

        AppState.shared.toastMessage = Toast.Message(
            text:  "\(customEventPreamble) \(customEventName)",
            duration: 2.0
        )
    }

    var sceneSection: some View {
        Section {
            Button {
                trackAndToast(customEventName: "as_t_banner")
            } label: {
                Label(
                    "Banner",
                    systemImage: "rectangle.portrait.topthird.inset.filled"
                )
            }
            Button {
                trackAndToast(customEventName: "as_t_modal")
            } label: {
                Label(
                    "Modal",
                    systemImage: "rectangle.portrait.center.inset.filled"
                )
            }
            Button {
                trackAndToast(customEventName: "as_t_fullscreen")
            } label: {
                Label(
                    "Fullscreen",
                    systemImage: "rectangle.portrait.inset.filled"
                )
            }
            Button {
                trackAndToast(customEventName: "as_t_story")
            } label: {
                Label(
                    "Story",
                    systemImage: "play.square.stack"
                )
            }
            Button {
                trackAndToast(customEventName: "as_t_survey")
            } label: {
                Label(
                    "Survey",
                    systemImage: "list.bullet.rectangle.portrait"
                )
            }
        } header: {
            Text("Scenes")
                .font(.headline)
        }
    }

    var iaaSection: some View {
        Section {
            Button {
                trackAndToast(customEventName: "as_iaa_banner")
            } label: {
                Label(
                    "Banner",
                    systemImage: "rectangle.portrait.topthird.inset.filled"
                )
            }
            Button {
                trackAndToast(customEventName: "as_iaa_modal")
            } label: {
                Label(
                    "Modal",
                    systemImage: "rectangle.portrait.center.inset.filled"
                )
            }
            Button {
                trackAndToast(customEventName: "as_iaa_fullscreen")
            } label: {
                Label(
                    "Fullscreen",
                    systemImage: "rectangle.portrait.inset.filled"
                )
            }
            Button {
                trackAndToast(customEventName: "as_iaa_html")
            } label: {
                Label(
                    "HTML",
                    systemImage: "safari.fill"
                )
            }
        } header: {
            Text("Messages")
                .font(.headline)
        }
    }

    var body: some View {
        NavigationView {
            Form {
                sceneSection
                iaaSection
            }.navigationTitle("Layout Viewer")
        }
    }
}

#Preview {
    HomeView()
}
