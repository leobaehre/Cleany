//
//  CleanyApp.swift
//  Cleany
//
//  Created by Leo Bähre on 2/6/26.
//

import SwiftUI
import AppKit

@main
struct CleanyApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self)
    var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}


