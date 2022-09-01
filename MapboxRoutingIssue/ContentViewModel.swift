//
//  ContentViewModel.swift
//  MapboxRoutingIssue
//
//  Created by Niclas Raabe on 01.09.22.
//

import CoreLocation
import MapboxCoreNavigation
import MapboxDirections
import SwiftUI

class ContentViewModel: ObservableObject {
    @Published var route: Route?
    
    private var navigationService: NavigationService?
    
    init() {
        createRoute()
    }
}

// MARK: - Route loading

extension ContentViewModel {
    func createRoute() {
        mapMatching(matchOptions: navigationMatchOptions()) { [weak self] routeResponse in
            guard let routeResponse = routeResponse else {
                print("Could not load route!")
                return
            }
            self?.onRouteLoaded(routeResponse: routeResponse)
        }
    }
    
    func navigationMatchOptions() -> NavigationMatchOptions {
        let options = NavigationMatchOptions(coordinates: Constants.routeCoordinates,
                                             profileIdentifier: .cycling)
        options.attributeOptions = [.expectedTravelTime, .distance, .speed]
        return options
    }
    
    func onRouteLoaded(routeResponse: RouteResponse) {
        guard case .route(let routeOptions) = routeResponse.options else {
            return
        }
        
        let navigationService = MapboxNavigationService(routeResponse: routeResponse,
                                                        routeIndex: 0,
                                                        routeOptions: routeOptions,
                                                        credentials: Directions.shared.credentials,
                                                        simulating: .never)
        navigationService.delegate = self
        navigationService.start()
                
        self.navigationService = navigationService
    }
}

// MARK: - Map matching

extension ContentViewModel {
    func mapMatching(matchOptions: MatchOptions, callback: @escaping (RouteResponse?) -> Void) {
        mapMatchingWithMatchResponse(matchOptions: matchOptions) { [weak self] mapMatchingResponse in
            guard let mapMatchingResponse = mapMatchingResponse else {
                callback(nil)
                return
            }
            guard let routeResponse = try? self?.routeResponse(from: mapMatchingResponse, matchOptions: matchOptions) else {
                return
            }
            callback(routeResponse)
        }
    }
    
    func mapMatchingWithMatchResponse(matchOptions: MatchOptions, callback: @escaping (MapMatchingResponse?) -> Void) {
        Directions.shared.calculateRoutes(options: matchOptions) { _, result in
            guard case .success(let matchResponse) = result else {
                print("Unexpected result: \(result)")
                callback(nil)
                return
            }
            callback(matchResponse)
        }
    }
    
    // We need to create the RouteResponse by ourself because for the
    // working navigation the option type has to be `.route()` 🙈 🙄
    // Using the constructor giving in the MapMatchingResponse is
    // setting the type to `.match()` instead of `.route()`. The change was introduced with
    // commit 3ae5d61b38482cf581277299ca39d43fe6a8cb81 and version 2.5.0
    // in the RouteController of Mapbox
    func routeResponse(from mapMatchingResponse: MapMatchingResponse,
                       matchOptions: MatchOptions) throws -> RouteResponse {
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()
        
        decoder.userInfo[.options] = matchOptions
        decoder.userInfo[.credentials] = Directions.shared.credentials
        encoder.userInfo[.options] = matchOptions
        encoder.userInfo[.credentials] = Directions.shared.credentials
        
        var routes: [Route]?
        
        if let matches = mapMatchingResponse.matches {
            let matchesData = try encoder.encode(matches)
            routes = try decoder.decode([Route].self, from: matchesData)
        }
        
        var waypoints: [Waypoint]?
        
        if let tracepoints = mapMatchingResponse.tracepoints {
            let filtered = tracepoints.compactMap { $0 }
            let tracepointsData = try encoder.encode(filtered)
            waypoints = try decoder.decode([Waypoint].self, from: tracepointsData)
        }
    
        return RouteResponse(httpResponse: mapMatchingResponse.httpResponse,
                             identifier: nil,
                             routes: routes,
                             waypoints: waypoints,
                             options: .route(RouteOptions(matchOptions: matchOptions)), // this is the relevant change
                             credentials: Directions.shared.credentials)
    }
}

// MARK: - NavigationServiceDelegate

extension ContentViewModel: NavigationServiceDelegate {
    func navigationService(_ service: NavigationService, didUpdate progress: RouteProgress, with location: CLLocation, rawLocation: CLLocation) {
        print("\(Date()) didUpdate progress: distanceRemaining: \(progress.distanceRemaining), durationRemaining: \(progress.durationRemaining), fractionTraveled: \(progress.fractionTraveled)")
        print("userIsOnRoute: \(service.router.userIsOnRoute(location))")
        
        route = progress.route
    }
    
    func navigationService(_ service: NavigationService, shouldRerouteFrom location: CLLocation) -> Bool {
        false
    }
}

enum Constants {
    static let routeCoordinates: [CLLocationCoordinate2D] = [.init(latitude: 40.74155114227432, longitude: -73.98958552778382),
                                                             .init(latitude: 40.74346951687277, longitude: -73.98816932142395),
                                                             .init(latitude: 40.74276232589619, longitude: -73.9865921825232),
                                                             .init(latitude: 40.74087248138878, longitude: -73.98800830150036)]
}
