//
//  ContentView.swift
//  MapboxRoutingIssue
//
//  Created by Niclas Raabe on 01.09.22.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: ContentViewModel
    
    var body: some View {
        if let route = viewModel.route,
           let waypoints = viewModel.waypoints {
            MapboxMapView(route: route,
                          waypoints: waypoints,
                          arrivedWaypoints: viewModel.arrivedWaypoints,
                          remainingWaypoints: viewModel.remainingWaypoints)
        }
    }
}
