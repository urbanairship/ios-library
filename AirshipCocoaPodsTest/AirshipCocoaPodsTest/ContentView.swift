import SwiftUI
import AirshipKit

struct ContentView: View {
    @State private var channelId: String = "Loading..."
    @State private var namedUser: String = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Channel ID Display
                VStack(alignment: .leading, spacing: 5) {
                    Text("Channel ID:")
                        .font(.headline)
                    Text(channelId)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.blue)
                        .textSelection(.enabled)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                
                // Named User Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Named User ID:")
                        .font(.headline)
                    
                    HStack {
                        TextField("Enter Named User ID", text: $namedUser)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button("Set") {
                            Task {
                                if namedUser.isEmpty {
                                    await Airship.contact.reset()
                                } else {
                                    await Airship.contact.identify(namedUser)
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                
                // Test Buttons
                VStack(spacing: 15) {
                    Text("Test In-App Automations")
                        .font(.headline)
                    
                    Button("Trigger Test Event") {
                        // This event can be used to trigger in-app messages
                        let event = CustomEvent(name: "test_event")
                        event.track()
                        print("Tracked test_event")
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    
                    Button("Open Message Center") {
                        MessageCenter.shared.display()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
                
                Spacer()
                
                Text("Ready to test full screen in-app automations!")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
            .navigationTitle("Airship Test")
            .task {
                // Get channel ID when view appears
                if let id = await Airship.channel.identifier {
                    channelId = id
                }
                
                // Get current named user
                if let currentNamedUser = await Airship.contact.namedUserID {
                    namedUser = currentNamedUser
                }
            }
        }
    }
}