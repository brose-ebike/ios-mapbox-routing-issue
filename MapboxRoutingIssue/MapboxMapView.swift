//
//  MapboxMapView.swift
//  MapboxTest
//
//  Created by Niclas Raabe on 24.02.22.
//

import CoreLocation
import MapboxDirections
import MapboxMaps
import MapboxNavigation
import SwiftUI

struct MapboxMapView: UIViewRepresentable {
    let route: Route
    
    func makeUIView(context: UIViewRepresentableContext<MapboxMapView>) -> NavigationMapView {
        let mapView = NavigationMapView(frame: .zero)
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        mapView.mapView.location.options.puckType = .puck2D(.init())
        
        mapView.show([route])
        
        let geometry = Geometry.polygon(Polygon([Constants.routeCoordinates]))
        var camera = mapView.mapView.mapboxMap.camera(for: geometry,
                                                      padding: .init(top: 10, left: 10, bottom: 10, right: 10),
                                                      bearing: 0,
                                                      pitch: 0)
        camera.zoom = 15.5
        mapView.mapView.mapboxMap.setCamera(to: camera)
        
        return mapView
    }
    
    func updateUIView(_ uiView: NavigationMapView, context: UIViewRepresentableContext<MapboxMapView>) {}
}
