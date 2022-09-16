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
    let waypoints: [Waypoint]
    let arrivedWaypoints: [Waypoint]
    let remainingWaypoints: [Waypoint]
    
    let routeAnnotationID = UUID().uuidString
    let waypointsAnnotationID = "Waypoints"
    
    func makeUIView(context: UIViewRepresentableContext<MapboxMapView>) -> NavigationMapView {
        let mapView = NavigationMapView(frame: .zero)
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        mapView.mapView.location.options.puckType = .puck2D(.init())
        
        let geometry = Geometry.polygon(Polygon([Constants.routeCoordinates]))
        var camera = mapView.mapView.mapboxMap.camera(for: geometry,
                                                      padding: .init(top: 10, left: 10, bottom: 10, right: 10),
                                                      bearing: 0,
                                                      pitch: 0)
        camera.zoom = 15.5
        mapView.mapView.mapboxMap.setCamera(to: camera)
        
        return mapView
    }
    
    fileprivate func addLineAnnotation(_ uiView: NavigationMapView) {
        uiView.mapView.annotations.removeAnnotationManager(withId: routeAnnotationID)
        // Make sure, that the location is above all annotations by getting the layer
        // identifier of the location indicator and position the lines below this layer
        var layerPosition: MapboxMaps.LayerPosition?
        if let identifier = uiView.mapView.mapboxMap.style.allLayerIdentifiers.first(where: { $0.type == .locationIndicator }) {
            layerPosition = .below(identifier.id)
        }
        let lineAnnnotationManager = uiView.mapView.annotations.makePolylineAnnotationManager(id: routeAnnotationID,
                                                                                              layerPosition: layerPosition)
        lineAnnnotationManager.annotations = [routeAnnotation]
        lineAnnnotationManager.lineCap = .round
    }
    
    fileprivate func addWaypointAnnotations(_ uiView: NavigationMapView) {
        uiView.mapView.annotations.removeAnnotationManager(withId: waypointsAnnotationID)
        
        let circleAnnnotationManager = uiView.mapView.annotations.makeCircleAnnotationManager(id: waypointsAnnotationID)
        circleAnnnotationManager.annotations = Constants.routeCoordinates.map { annotation(waypoint: .init(coordinate: $0), color: .gray) }
            + waypoints.map { annotation(waypoint: $0, color: .black) }
            + arrivedWaypoints.map { annotation(waypoint: $0, color: .green, circleRadius: 8) }
            + remainingWaypoints.map { annotation(waypoint: $0, color: .blue) }
    }
    
    func updateUIView(_ uiView: NavigationMapView, context: UIViewRepresentableContext<MapboxMapView>) {
        uiView.show([route])
        
        addLineAnnotation(uiView)
        addWaypointAnnotations(uiView)
    }
    
    var routeAnnotation: MapboxMaps.PolylineAnnotation {
        var lineAnnotation = PolylineAnnotation(id: "RideID",
                                                lineCoordinates: Constants.routeCoordinates)
        lineAnnotation.lineColor = StyleColor(UIColor.red.withAlphaComponent(0.75))
        lineAnnotation.lineWidth = 6
        lineAnnotation.lineJoin = .round
        return lineAnnotation
    }
    
    func annotation(waypoint: Waypoint, color: UIColor, circleRadius: Double = 6) -> CircleAnnotation {
        var circleAnnotation = CircleAnnotation(centerCoordinate: waypoint.coordinate)
        circleAnnotation.circleColor = StyleColor(color)
        circleAnnotation.circleRadius = circleRadius
        return circleAnnotation
    }
}
