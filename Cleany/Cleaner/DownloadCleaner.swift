//
//  DownloadCleaner.swift
//  Cleany
//
//  Created by Leo Bähre on 2/6/26.
//

import Foundation
import AppKit
import UniformTypeIdentifiers

struct DownloadCleaner {

    private let cutoffDays: Int = AppSettings.shared.cutoffDays
    private let bookmarkKey = "DownloadsURLBookmark"

    func clean() {
        guard let downloadsURL = obtainDownloadsURL() else {
            print("No access to Downloads folder.")
            return
        }

        // Always stop access when done
        defer {
            downloadsURL.stopAccessingSecurityScopedResource()
        }

        runCleanup(in: downloadsURL)
    }

    private func runCleanup(in downloadsURL: URL) {
        print("Cleaning Downloads at:", downloadsURL.path)

        let cutoffDate = Calendar.current.date(
            byAdding: .day,
            value: -cutoffDays,
            to: Date()
        )!

        let fileManager = FileManager.default

        guard let files = try? fileManager.contentsOfDirectory(
            at: downloadsURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .contentTypeKey],
            options: .skipsHiddenFiles
        ) else {
            print("Failed to list Downloads contents.")
            return
        }

        for file in files {
            guard
                let modifiedDate = try? file
                    .resourceValues(forKeys: [.contentModificationDateKey])
                    .contentModificationDate,
                modifiedDate < cutoffDate
            else {
                continue
            }

            if isPDF(file) {
                movePDF(file, in: downloadsURL)
                print("PDF file found:", file.lastPathComponent, "modified on", modifiedDate, "- moved to pdfs folder.")
                continue
            }

            print("Old file found:", file.lastPathComponent, "modified on", modifiedDate)
            
            
            do {
                try FileManager.default.trashItem(
                    at: file,
                    resultingItemURL: nil
                )
                print("Trashed: ", file)
            } catch {
                print("Failed to trash:", error)
            }
        }
    }

    private func isPDF(_ url: URL) -> Bool {
        guard let type = try? url
            .resourceValues(forKeys: [.contentTypeKey])
            .contentType else {
            return false
        }

        return type.conforms(to: .pdf)
    }

    private func movePDF(_ file: URL, in downloadsURL: URL) {
        let fileManager = FileManager.default

        guard let pdfsFolder = ensurePDFsFolder(in: downloadsURL) else {
            print("Could not ensure pdfs folder.")
            return
        }

        let destination = pdfsFolder.appendingPathComponent(file.lastPathComponent)

        // Avoid overwriting
        guard !fileManager.fileExists(atPath: destination.path) else {
            print("PDF already exists:", destination.lastPathComponent)
            return
        }

        do {
            try fileManager.moveItem(at: file, to: destination)
            print("Moved PDF:", file.lastPathComponent)
        } catch {
            print("Failed to move PDF:", file.lastPathComponent, error)
        }
    }

    private func ensurePDFsFolder(in downloadsURL: URL) -> URL? {
        let pdfsFolder = downloadsURL.appendingPathComponent("pdfs")

        if !FileManager.default.fileExists(atPath: pdfsFolder.path) {
            do {
                try FileManager.default.createDirectory(
                    at: pdfsFolder,
                    withIntermediateDirectories: false
                )
            } catch {
                print("Failed to create pdfs folder:", error)
                return nil
            }
        }

        return pdfsFolder
    }

    private func obtainDownloadsURL() -> URL? {
        if let url = loadDownloadsURL() {
            return url
        }

        print("Requesting Downloads access…")

        if let url = requestDownloadsAccess() {
            saveBookmark(for: url)
            return loadDownloadsURL()
        }

        return nil
    }

    private func requestDownloadsAccess() -> URL? {
        let panel = NSOpenPanel()
        panel.message = "Cleany needs access to your Downloads folder"
        panel.prompt = "Allow Access"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = FileManager.default
            .urls(for: .downloadsDirectory, in: .userDomainMask)
            .first

        return panel.runModal() == .OK ? panel.url : nil
    }

    private func saveBookmark(for url: URL) {
        do {
            let bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )

            UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)
        } catch {
            print("Failed to save bookmark:", error)
        }
    }

    private func loadDownloadsURL() -> URL? {
        guard let bookmarkData = UserDefaults.standard.data(forKey: bookmarkKey) else {
            return nil
        }

        var isStale = false

        do {
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            guard url.startAccessingSecurityScopedResource() else {
                print("Failed to start accessing Downloads.")
                return nil
            }

            return url
        } catch {
            print("Failed to resolve bookmark:", error)
            return nil
        }
    }
}
