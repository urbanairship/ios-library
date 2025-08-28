/* Copyright Airship and Contributors */



@MainActor
class ButtonState: ObservableObject {
    let identifier: String
    init(identifier: String) {
        self.identifier = identifier
    }
}
