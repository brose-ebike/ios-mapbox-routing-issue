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
    @Published var waypoints: [Waypoint]? {
        didSet { print("waypoints: \(waypoints?.count ?? 0)") }
    }

    @Published var arrivedWaypoints: [Waypoint] = []
    var remainingWaypoints: [Waypoint] = Constants.routeCoordinates.map { .init(coordinate: $0) } {
            didSet { print("remainingWaypoints: \(remainingWaypoints.count)") }
    }
    
    private var routeResponse: RouteResponse?
    private var navigationService: NavigationService?
    private var isRecalculating: Bool = false
    private var lastRecalculation = Date()
    
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
        self.routeResponse = routeResponse
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
            self?.waypoints = matchOptions.waypoints
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

// MARK: - Back-Routing

extension ContentViewModel {
    func backRoute(from location: CLLocation, progress: RouteProgress) {
        guard isRecalculating == false else {
            print("backrouting is already running")
            return
        }
        guard abs(lastRecalculation.timeIntervalSinceNow) > Constants.minimumRecalculationInterval else {
            print("last recalculation just happened")
            return
        }
        print("backRoute from location: \(location)")
        
        isRecalculating = true
        lastRecalculation = Date()
        
        var routeWaypoints = remainingWaypoints
        print("original routeWaypoints: \(routeWaypoints.map { $0.coordinate })")
//        routeWaypoints = routeWaypoints.filter { waypoint in
//            arrivedWaypoints.map { $0.coordinate }.contains(waypoint.coordinate) == false
//        }
//        print("filtered routeWaypoints: \(routeWaypoints.map { $0.coordinate })")
        // find closest point to route to
        let sorted = routeWaypoints.sorted { left, right in
            left.coordinate.distance(to: location.coordinate) < right.coordinate.distance(to: location.coordinate)
        }
        if let first = sorted.first {
            // Remove all points in the array that are earlier than the nearest point
            print("Routing to nearest waypoint: \(first.coordinate), waypoints: \(routeWaypoints.map { $0.coordinate })")
            if let index = routeWaypoints.firstIndex(of: first) {
                routeWaypoints.removeFirst(index)
            }
            print("New waypoints: \(routeWaypoints.map { $0.coordinate })")
        }
        // Prepend current location
        routeWaypoints.insert(.init(location: location), at: 0)
        
//        let routeOptions = progress.reroutingOptions(from: location)
//        var waypoints = routeOptions.waypoints
//        if waypoints.count > 2 {
//            // remove current location for the calculation
//            let currentLocation = waypoints.removeFirst()
//
//            // Sort all waypoints by their distance to the current location
//            let sorted = waypoints.sorted { left, right in
//                left.coordinate.distance(to: location.coordinate) < right.coordinate.distance(to: location.coordinate)
//            }
//
//            // If the nearest one is not the closest one, we need to remove the waypoints
//            // before the closest one
//            if let first = sorted.first,
//               first != waypoints.first {
//                // Remove all points in the array that are earlier than the nearest point
//                print("Routing to nearer waypoint: \(first.coordinate), waypoints: \(waypoints.map { $0.coordinate })")
//                if let index = waypoints.firstIndex(of: first) {
//                    waypoints.removeFirst(index)
//                }
//                print("New waypoints: \(waypoints.map { $0.coordinate })")
//            }
//
//            // add the current location back
//            waypoints.insert(currentLocation, at: 0)
//        }
        
        let matchOptions = NavigationMatchOptions(waypoints: routeWaypoints, profileIdentifier: .cycling)
        matchOptions.attributeOptions = [.expectedTravelTime, .distance, .speed]
        
        mapMatching(matchOptions: matchOptions) { [weak self] routeResponse in
            guard let routeResponse = routeResponse else {
                print("Error: No RouteResponse")
                self?.isRecalculating = false
                return
            }
            
            self?.navigationService?.router.updateRoute(with: .init(routeResponse: routeResponse, routeIndex: 0),
                                                        routeOptions: .init(matchOptions: matchOptions),
                                                        completion: nil)
            
            self?.isRecalculating = false
            print("backRoute finished")
        }
    }
}

// MARK: - NavigationServiceDelegate

extension ContentViewModel: NavigationServiceDelegate {
    func navigationService(_ service: NavigationService, didUpdate progress: RouteProgress, with location: CLLocation, rawLocation: CLLocation) {
        print("\(Date()) didUpdate progress: distanceRemaining: \(progress.distanceRemaining), durationRemaining: \(progress.durationRemaining), fractionTraveled: \(progress.fractionTraveled)")
        
        let isOnRoute = service.router.userIsOnRoute(location)
        print("userIsOnRoute: \(isOnRoute)")
        
        route = progress.route
        
        if isOnRoute == false {
            backRoute(from: location, progress: progress)
        }
    }
    
    func navigationService(_ service: NavigationService, shouldRerouteFrom location: CLLocation) -> Bool {
        print("shouldRerouteFrom: \(location)")
        
        backRoute(from: location, progress: service.routeProgress)
        
        return false
    }
    
    func navigationService(_ service: NavigationService, didArriveAt waypoint: Waypoint) -> Bool {
        print("didArriveAt: \(waypoint.coordinate)")
        arrivedWaypoints.append(waypoint)
        
        if let index = remainingWaypoints.firstIndex(where: { $0.coordinate == waypoint.coordinate }) {
            remainingWaypoints.removeFirst(index + 1)
        }
        
        return true
    }
}

enum Constants {
    static let routeCoordinates: [CLLocationCoordinate2D] = [.init(latitude: 40.74163612569854, longitude: -73.99374403493513),
                                                             .init(latitude: 40.74293079743917, longitude: -73.99281050186207),
                                                             .init(latitude: 40.74155114227432, longitude: -73.98958552778382),
                                                             .init(latitude: 40.74221690595822, longitude: -73.98907105362191),
                                                             .init(latitude: 40.742824910521236, longitude: -73.98860362553543),
                                                             .init(latitude: 40.74346951687277, longitude: -73.98816932142395),
                                                             .init(latitude: 40.743116374662996, longitude: -73.98740816778515),
                                                             .init(latitude: 40.74276232589619, longitude: -73.9865921825232),
                                                             .init(latitude: 40.74188782900569, longitude: -73.98730475449612),
                                                             .init(latitude: 40.74087248138878, longitude: -73.98800830150036),
                                                             .init(latitude: 40.740204586123006, longitude: -73.98638537083042),
                                                             .init(latitude: 40.739546964090394, longitude: -73.98475718903514),
                                                             .init(latitude: 40.74019992129571, longitude: -73.98427464539485),
                                                             .init(latitude: 40.740782371079156, longitude: -73.9837959992614),
                                                             .init(latitude: 40.74050763125072, longitude: -73.98309978670369),
                                                             .init(latitude: 40.740133983262986, longitude: -73.98220051214996),
                                                             .init(latitude: 40.738886643164726, longitude: -73.98315780441682),
                                                             .init(latitude: 40.737952496491005, longitude: -73.98088786136883),
                                                             .init(latitude: 40.73858442065284, longitude: -73.98040196284998),
                                                             .init(latitude: 40.73757883413092, longitude: -73.97807400211008),
                                                             .init(latitude: 40.73567202450648, longitude: -73.9795607060094),
                                                             .init(latitude: 40.738251295313496, longitude: -73.98569407715556),
                                                             .init(latitude: 40.73892510776117, longitude: -73.98733508003534),
                                                             .init(latitude: 40.73985374590963, longitude: -73.98957601420553),
                                                             .init(latitude: 40.741397784191776, longitude: -73.98914813357109),
                                                             .init(latitude: 40.74293079743917, longitude: -73.99281050186207),
                                                             .init(latitude: 40.74163612569854, longitude: -73.99374403493513)]
    
    static let minimumRecalculationInterval: TimeInterval = 5
}
