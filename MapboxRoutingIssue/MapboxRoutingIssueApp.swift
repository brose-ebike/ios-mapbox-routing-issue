//
//  MapboxRoutingIssueApp.swift
//  MapboxRoutingIssue
//
//  Created by Niclas Raabe on 01.09.22.
//

import SwiftUI

@main
struct MapboxRoutingIssueApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: ContentViewModel())
        }
    }
}
