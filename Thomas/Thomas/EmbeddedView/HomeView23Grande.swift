import SwiftUI
import AirshipCore

struct HomeView23Grande: View {
    @State var tabIndex = 0
    var body: some View {
        GeometryReader { geo in

            VStack {
                VStack {
                    Image("23GrandeHomeBanner")
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width * 0.75, alignment: .center)
                        .clipped()
                }
                .frame(maxWidth: .infinity)
                .background(Color.white)

                ScrollView(showsIndicators: false) {


                    AirshipEmbeddedView(id: "home_special_offer")
                        .setAirshipEmbeddedStyle(DismissableStyle())


                    Spacer(minLength: 30)

                    VStack(spacing:0) {
                        FashionMenu(tabIndex: $tabIndex)
                        Separation()
                        FashionImages(tabIndex: $tabIndex)
                            .frame(height: max(300.0, geo.size.height * 0.50))
                    }

                    Text("NEW ARRIVALS")
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing:10) {
                            Spacer()
                            Image("23GrandeArrival1")
                                .resize(width: geo.size.width * 0.40)
                            Image("23GrandeArrival2")
                                .resize(width: geo.size.width * 0.40)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
        .onAppear {
            Layouts.shared.layouts.filter { $0.type == .sceneEmbedded }.forEach {
                do {
                    try Layouts.shared.openLayout($0)
                } catch {
                    print("error: \(error)")
                }
            }
        }
    }
}


struct Separation: View {
    var body: some View {
        return Rectangle()
            .fill(Color.red)
            .frame(height:5.0)
            .allowsHitTesting(false)
    }
}

struct FashionImages: View {
    @State private var isUserSwiping = false
    @State private var offsetValue = CGFloat(0.0)
    @Binding var tabIndex: Int

    var body: some View {
        TabView(selection: $tabIndex) {
            ForEach((0..<4), id: \.self) { index in
                Image("23GrandeAllFashion")
                    .resizable()
                    .scaledToFill()
            }
        }.tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
    }
}

struct HomeView23Grande_Previews: PreviewProvider {
    static var previews: some View {
        HomeView23Grande()
    }
}

struct FashionMenu: View {
    @Binding var tabIndex: Int
    var body: some View {
        VStack {
            HStack {
                TabBarButton(text: "All FASHION", isSelected: .constant(tabIndex == 0))
                    .onTapGesture { onButtonTapped(index: 0) }
                TabBarButton(text: "JEANS", isSelected: .constant(tabIndex == 1))
                    .onTapGesture { onButtonTapped(index: 1) }
                TabBarButton(text: "NEW", isSelected: .constant(tabIndex == 2))
                    .onTapGesture { onButtonTapped(index: 2) }
                TabBarButton(text: "SALE", isSelected: .constant(tabIndex == 3))
                    .onTapGesture { onButtonTapped(index: 3) }
            }
        }
    }

    private func onButtonTapped(index: Int) {
                withAnimation { tabIndex = index }
    }
}

struct TabBarButton: View {
    let text: String
    @Binding var isSelected: Bool
    var body: some View {
        VStack {
            Text(text)
                .fontWeight(.heavy)
                .font(.custom("Avenir", size: 14))
            Rectangle()
                .fill(isSelected ? Color.primary : Color.clear)
                .frame(height: 6.0)
        }
    }
}

extension Image {
    func resize(width: CGFloat? = nil, height: CGFloat? = nil) -> some View {
        return self
            .resizable()
            .scaledToFill()
            .frame(width: width, height: height)
            .clipped()
    }
}


public struct DismissableStyle: AirshipEmbeddedViewStyle {
    @ViewBuilder
    public func makeBody(configuration: AirshipEmbeddedViewStyleConfiguration) -> some View {
        if let view = configuration.views.first {
            VStack {
                Button("Dismiss") {
                    view.dismiss()
                }
                view
            }
        } else {
            configuration.placeHolder
        }
    }
}
