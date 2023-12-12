import CoreLocation
import MapKit
import SwiftUI

struct MapRouteView: View {
    @StateObject private var locationManager = LocationManager()

    var body: some View {
        Group {
            if let userLocation = locationManager.location {
                ZStack(alignment: .center) {
                    MapView(userLocation: userLocation, destinationCoordinate: CLLocationCoordinate2D(latitude: 45.559020, longitude: -122.672970))
                    VStack {
                        Spacer()
                        Text("Lat:\(userLocation.latitude) Lon:\(userLocation.longitude)")
                            .padding(8)
                            .font(.footnote)
                            .foregroundColor(.white)
                            .background(Capsule()
                                .foregroundColor(.gray)
                                .opacity(0.8)
                                .shadow(radius: 4))
                    }
                }.padding(8)
            } else {
                Text("Determining your location...")
            }
        }
    }
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var location: CLLocationCoordinate2D?
    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last?.coordinate {
            DispatchQueue.main.async {
                self.location = location
            }
        }
    }
}

struct MapView: UIViewRepresentable {
    var userLocation: CLLocationCoordinate2D
    let destinationCoordinate: CLLocationCoordinate2D

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator

        // Update the region to center on the user's location
        let region = MKCoordinateRegion(center: userLocation, latitudinalMeters: 900, longitudinalMeters: 900)
        mapView.setRegion(region, animated: true)

        // Set up and calculate the route
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: userLocation))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destinationCoordinate))
        request.transportType = .automobile

        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            guard let route = response?.routes.first else { return }
            mapView.addOverlay(route.polyline)
            mapView.setVisibleMapRect(route.polyline.boundingMapRect, animated: true)
        }

        // Manage annotations
        updateAnnotations(mapView: mapView)

        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {


    }

    func updateAnnotations(mapView: MKMapView) {
        mapView.removeAnnotations(mapView.annotations)

        // Add user location annotation
        let userAnnotation = MKPointAnnotation()
        userAnnotation.coordinate = userLocation
        userAnnotation.title = "Your Location"
        mapView.addAnnotation(userAnnotation)

        // Add destination annotation
        let destinationAnnotation = MKPointAnnotation()
        destinationAnnotation.coordinate = destinationCoordinate
        destinationAnnotation.title = "NETs Site 🚑"
        destinationAnnotation.subtitle = "Your local NETs meeting point"
        mapView.addAnnotation(destinationAnnotation)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView

        init(_ parent: MapView) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            let renderer = MKPolylineRenderer(overlay: overlay)
            renderer.strokeColor = .systemGreen
            renderer.lineWidth = 5
            return renderer
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let identifier = "Placemark"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)

            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }

            return annotationView
        }
    }
}
