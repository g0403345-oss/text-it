//
//  ContentView.swift
//  Text it
//
//  Created by Justin Gül on 11.05.26.
//

import SwiftUI
import SwiftData

// Legacy-Einstieg – die echte UI lebt in RootView.
struct ContentView: View {
    var body: some View {
        RootView()
    }
}

#Preview {
    ContentView()
        .modelContainer(DataController.shared)
        .environment(AppState())
}
