import Foundation
import EventKit
import ArgumentParser

// MARK: - Command Line Parser
struct CalendarTransfer: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "calendar-transfer",
        abstract: "Transfer files using Calendar events",
        subcommands: [Upload.self, Download.self, List.self]
    )
}

// MARK: - List Command
extension CalendarTransfer {
    struct List: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List all available files for transfer"
        )
        
        func run() throws {
            let transfer = try CalendarFileTransfer()
            let files = try transfer.listAvailableFiles()
            
            if files.isEmpty {
                print("No files available for transfer")
                return
            }
            
            print("\nAvailable files:")
            print("------------------------")
            for file in files {
                print("File: \(file.name)")
                print("Size: \(file.size) bytes")
                print("------------------------")
            }
        }
    }
}

// MARK: - Upload Command
extension CalendarTransfer {
    struct Upload: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "upload",
            abstract: "Upload a file to Calendar"
        )
        
        @Argument(help: "Path to the file to upload")
        var filePath: String
        
        func run() throws {
            let transfer = try CalendarFileTransfer()
            let fileURL = URL(fileURLWithPath: filePath)
            
            print("Uploading file: \(fileURL.lastPathComponent)")
            try transfer.uploadFile(at: fileURL)
            print("Success! File uploaded successfully")
            print("Use 'calendar-transfer list' to see all available files")
            print("Use 'calendar-transfer download <filename> <save-directory>' to download")
        }
    }
}

// MARK: - Download Command
extension CalendarTransfer {
    struct Download: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "download",
            abstract: "Download a file from Calendar"
        )
        
        @Argument(help: "Name of the file to download")
        var fileName: String
        
        @Argument(help: "Directory to save the downloaded file")
        var saveDirectory: String
        
        func run() throws {
            let transfer = try CalendarFileTransfer()
            let savePath = URL(fileURLWithPath: saveDirectory)
            
            print("Downloading file: \(fileName)")
            try transfer.downloadFile(named: fileName, savePath: savePath)
            print("File downloaded successfully to: \(saveDirectory)")
        }
    }
}

// MARK: - Calendar File Transfer Implementation
class CalendarFileTransfer {
    private let eventStore = EKEventStore()
    private let calendar: EKCalendar
    private let eventPrefix = "FileTransfer_"
    private let calendarName = "files"  // Specific calendar name
    
    struct TransferFile {
        let name: String
        let size: Int
    }
    
    // Fixed date components for January 1st, 2024 at 12:00 PM
    private let fixedDate: Date = {
        var components = DateComponents()
        components.year = 2024
        components.month = 1
        components.day = 1
        components.hour = 12
        components.minute = 0
        components.second = 0
        return Calendar.current.date(from: components)!
    }()
    
    init() throws {
            let semaphore = DispatchSemaphore(value: 0)
            var accessGranted = false
            
            eventStore.requestAccess(to: .event) { granted, error in
                accessGranted = granted
                semaphore.signal()
            }
            _ = semaphore.wait(timeout: .now() + 30.0)
            
            guard accessGranted else {
                throw TransferError.calendarAccessDenied
            }
            
            // Get all calendars
            let allCalendars = eventStore.calendars(for: .event)
            
            // Debug: Print all available calendars
            print("\nAvailable calendars:")
            for cal in allCalendars {
                print("- Title: \(cal.title)")
                print("  Source: \(cal.source.title)")
                print("  Type: \(cal.source.sourceType.rawValue)")
                print("  Allows modifications: \(cal.allowsContentModifications)")
                print("-------------------")
            }
            
            // Simple calendar search without closure syntax
            var foundCalendar: EKCalendar?
            for cal in allCalendars {
                if cal.title == calendarName {
                    foundCalendar = cal
                    break
                }
            }
            
            if let calendar = foundCalendar {
                print("Using calendar: \(calendar.title)")
                self.calendar = calendar
            } else {
                throw TransferError.noFilesCalendar
            }
        }
    
    func uploadFile(at path: URL) throws {
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw TransferError.fileNotFound
        }
        
        let fileData = try Data(contentsOf: path)
        let fileName = path.lastPathComponent
        
        // Clean up existing file if present
        try cleanupExisting(fileName: fileName)
        
        let event = EKEvent(eventStore: eventStore)
        event.calendar = calendar
        event.title = eventPrefix + fileName
        event.startDate = fixedDate
        event.endDate = fixedDate.addingTimeInterval(3600) // 1 hour duration
        event.timeZone = TimeZone(identifier: "UTC")  // Use UTC for consistency
        
        let base64Data = fileData.base64EncodedString()
        event.notes = [
            "FILE_TRANSFER_DATA",
            fileName,
            String(fileData.count),
            base64Data
        ].joined(separator: "|")
        
        try eventStore.save(event, span: .thisEvent)
    }
    
    func downloadFile(named fileName: String, savePath: URL) throws {
        let predicate = eventStore.predicateForEvents(
            withStart: fixedDate,
            end: fixedDate.addingTimeInterval(3600),
            calendars: [calendar]
        )
        
        let events = eventStore.events(matching: predicate)
        guard let event = events.first(where: {
            $0.title == eventPrefix + fileName ||
            $0.title.replacingOccurrences(of: eventPrefix, with: "") == fileName
        }) else {
            throw TransferError.fileNotFound
        }
        
        guard let notes = event.notes,
              notes.starts(with: "FILE_TRANSFER_DATA") else {
            throw TransferError.invalidEventFormat
        }
        
        let components = notes.components(separatedBy: "|")
        guard components.count == 4 else {
            throw TransferError.invalidEventFormat
        }
        
        let expectedSize = Int(components[2]) ?? 0
        let base64Data = components[3]
        
        guard let fileData = Data(base64Encoded: base64Data),
              fileData.count == expectedSize else {
            throw TransferError.invalidFileData
        }
        
        let fileURL = savePath.appendingPathComponent(fileName)
        try fileData.write(to: fileURL)
    }
    
    func listAvailableFiles() throws -> [TransferFile] {
        let predicate = eventStore.predicateForEvents(
            withStart: fixedDate,
            end: fixedDate.addingTimeInterval(3600),
            calendars: [calendar]
        )
        
        return eventStore.events(matching: predicate)
            .filter { $0.title.hasPrefix(eventPrefix) }
            .compactMap { event -> TransferFile? in
                guard let notes = event.notes?.components(separatedBy: "|"),
                      notes.count == 4 else {
                    return nil
                }
                let fileName = event.title.replacingOccurrences(of: eventPrefix, with: "")
                let size = Int(notes[2]) ?? 0
                return TransferFile(name: fileName, size: size)
            }
            .sorted { $0.name < $1.name }
    }
    
    private func cleanupExisting(fileName: String) throws {
        let predicate = eventStore.predicateForEvents(
            withStart: fixedDate,
            end: fixedDate.addingTimeInterval(3600),
            calendars: [calendar]
        )
        
        let events = eventStore.events(matching: predicate)
        if let existingEvent = events.first(where: { $0.title == eventPrefix + fileName }) {
            try eventStore.remove(existingEvent, span: .thisEvent)
        }
    }
    
    enum TransferError: Error {
        case calendarAccessDenied
        case noFilesCalendar
        case fileNotFound
        case invalidEventFormat
        case invalidFileData
    }
}

// MARK: - Main
CalendarTransfer.main()
