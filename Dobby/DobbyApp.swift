//
//  DobbyApp.swift
//  Dobby
//
//  Created by Armando Esparza Garcia on 02/04/26.
//

import SwiftUI

@main
struct DobbyApp: App {
    private let deps = AppDependencies.live()

    var body: some Scene {
        WindowGroup {
            RootView(deps: deps)
        }
    }
}
