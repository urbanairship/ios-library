/* Copyright Airship and Contributors */

import SwiftUI
import AirshipCore

struct BackgroundView: View {
    var body: some View {
        let colorScheme = [
                           Color(red: 141/255, green: 87/255, blue: 151/255),
                           Color(red: 20/255, green: 31/255, blue: 78/255),
                           Color.black
        ]

        let gradient = Gradient(colors: colorScheme)
        let linearGradient = LinearGradient(gradient: gradient, startPoint: .top, endPoint: .bottom)

        let background = Rectangle()
            .fill(linearGradient)
            .blur(radius: 20, opaque: true)
            .edgesIgnoringSafeArea(.all)

        return background
    }
}

struct WeatherView: View {
    @StateObject var data: WeatherViewModel = WeatherViewModel()

    var foreground:some View {
        VStack(alignment: .leading) {
            HStack {
                Image(data.icon)
                    .resizable()
                    .frame(width: 45, height: 45)
                Text(data.summary)
                    .font(.system(size: 25))
                    .fontWeight(.light)
            }.padding(0)

            HStack {
                Text(data.temperature)
                    .font(.system(size: 120))
                    .fontWeight(.ultraLight)
                Spacer()
                HStack {
                    Spacer()
                    VStack(alignment: .leading) {
                        HStack {
                            Text("FEELS LIKE")
                            Spacer()
                            Text(data.apparentTemperature)
                        }.padding(.bottom, 1)

                        HStack {
                            Text("WIND SPEED")
                            Spacer()
                            Text(data.windSpeed)
                        }.padding(.bottom, 1)

                        HStack {
                            Text("HUMIDITY")
                            Spacer()
                            Text(data.humidity)
                        }.padding(.bottom, 1)

                        HStack {
                            Text("PRECIPITATION")
                            Spacer()
                            Text(data.precipProbability)
                        }.padding(.bottom, 1)
                    }

                }.frame(maxWidth:150).font(.caption)
            }.padding(0)
        }
    }

    var body: some View {
        ZStack {
            BackgroundView()

            VStack {
                Spacer()

                VStack {
                    Text("PORTLAND, OREGON").font(.title).fontWeight(.light)
                    Text(data.time).foregroundColor(.gray)
                }
                Spacer()

                foreground

                Spacer()
            }.padding(22)
        }.colorScheme(.dark)
    }
}
