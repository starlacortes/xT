//
//  MediaRecord.swift
//  xT
//
//  Voice/selfie timeline media attachment model.
//  Stores photos (and optionally voice memos) for tracking physical changes over time.
//

import Foundation
import SwiftData
import SwiftUI

@Model
class MediaRecord: Identifiable, Hashable {
    @Attribute(.unique) var id: String
    var captureDate: Date
    var photoData: Data?                     // JPEG-encoded photo
    var thumbnailData: Data?                 // Small thumbnail for grid display
    var voiceData: Data?                     // Optional voice memo recording
    var bodySystem: String?                  // e.g., "Face", "Body Shape", "Skin"
    var notes: String?                       // Optional user note

    init(
        id: String = UUID().uuidString,
        captureDate: Date = Date(),
        photoData: Data? = nil,
        thumbnailData: Data? = nil,
        voiceData: Data? = nil,
        bodySystem: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.captureDate = captureDate
        self.photoData = photoData
        self.thumbnailData = thumbnailData
        self.voiceData = voiceData
        self.bodySystem = bodySystem
        self.notes = notes
    }

    // Hashable conformance
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: MediaRecord, rhs: MediaRecord) -> Bool { lhs.id == rhs.id }

    /// Reconstruct UIImage from photo data.
    var photo: UIImage? {
        guard let data = photoData else { return nil }
        return UIImage(data: data)
    }

    /// Reconstruct thumbnail UIImage.
    var thumbnail: UIImage? {
        guard let data = thumbnailData else { return photo }
        return UIImage(data: data)
    }
}

// MARK: - Body System Tags

extension MediaRecord {
    static let bodySystemOptions = [
        "Face",
        "Body Shape",
        "Skin",
        "Hair",
        "Full Body",
        "Other"
    ]
}