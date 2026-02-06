//
//  AppSettings.swift
//  Cleany
//
//  Created by Leo Bähre on 2/6/26.
//


import Foundation
import Combine

final class AppSettings: ObservableObject {

    static let shared = AppSettings()

    private enum Keys {
        static let cleanupIntervalHours = "cleanupIntervalHours"
        static let cutoffDays = "cutoffDays"
        static let runAtLogin = "runAtLogin"
    }

    @Published var cleanupIntervalHours: Int = 6 {
        didSet {
            UserDefaults.standard.set(cleanupIntervalHours, forKey: Keys.cleanupIntervalHours)
        }
    }

    @Published var cutoffDays: Int = 7 {
        didSet {
            UserDefaults.standard.set(cutoffDays, forKey: Keys.cutoffDays)
        }
    }

    @Published var cleanAtLogin: Bool = true {
        didSet {
            UserDefaults.standard.set(cleanAtLogin, forKey: Keys.runAtLogin)
        }
    }

    private init() {
        let defaults = UserDefaults.standard

        if defaults.object(forKey: Keys.cleanupIntervalHours) != nil {
            cleanupIntervalHours = defaults.integer(forKey: Keys.cleanupIntervalHours)
        }

        if defaults.object(forKey: Keys.cutoffDays) != nil {
            cutoffDays = defaults.integer(forKey: Keys.cutoffDays)
        }

        if defaults.object(forKey: Keys.runAtLogin) != nil {
            cleanAtLogin = defaults.bool(forKey: Keys.runAtLogin)
        }
    }
}
