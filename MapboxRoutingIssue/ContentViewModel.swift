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
        let navigationService = MapboxNavigationService(indexedRouteResponse: .init(routeResponse: routeResponse, routeIndex: 0),
                                                        credentials: Directions.shared.credentials)
        navigationService.delegate = self
        navigationService.start()
                
        self.navigationService = navigationService
    }
}

// MARK: - Map matching

extension ContentViewModel {
    func mapMatching(matchOptions: MatchOptions, callback: @escaping (RouteResponse?) -> Void) {
        Directions.shared.calculateRoutes(matching: matchOptions) { session, result in
            guard case .success(let routeResponse) = result else {
                print("Unexpected result: \(result)")
                callback(nil)
                return
            }
            callback(routeResponse)
        }
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
