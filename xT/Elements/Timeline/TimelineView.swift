//
//  TimelineView.swift
//  xT
//
//  Voice/Selfie timeline — chronological photo grid for tracking
//  physical changes visually over time.
//

import SwiftUI
import PhotosUI
import SwiftData

struct TimelineView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \MediaRecord.captureDate, order: .reverse) private var records: [MediaRecord]

    @State private var showPhotoPicker = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedBodySystem: String = "Face"
    @State private var notes: String = ""
    @State private var expandedRecord: MediaRecord?
    @State private var filterSystem: String? = nil

    private let columns = [
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter chips
                filterBar
                    .padding(.horizontal, 22)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                // Photo grid
                if filteredRecords.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 4) {
                            ForEach(filteredRecords) { record in
                                thumbnailCell(record)
                            }
                        }
                        .padding(.horizontal, 22)
                        .padding(.bottom, 100) // room for add button
                    }
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("TIMELINE")
                        .font(Theme.Fonts.caption2)
                        .foregroundStyle(Theme.Colors.accent)
                        .tracking(1.2)
                }
            }
            .overlay(alignment: .bottom) {
                addButton
            }
            .onChange(of: selectedPhoto) { _, newItem in
                handlePhotoSelection(newItem)
            }
            .sheet(item: $expandedRecord) { record in
                detailSheet(record)
            }
        }
    }

    // MARK: - Filter

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(label: "All", isSelected: filterSystem == nil) {
                    filterSystem = nil
                }
                ForEach(MediaRecord.bodySystemOptions, id: \.self) { system in
                    FilterChip(label: system, isSelected: filterSystem == system) {
                        filterSystem = system
                    }
                }
            }
        }
    }

    private var filteredRecords: [MediaRecord] {
        guard let filter = filterSystem else { return records }
        return records.filter { $0.bodySystem == filter }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 48))
                .foregroundStyle(Theme.Colors.accent.opacity(0.4))
                .padding(.top, 60)

            Text("No photos yet")
                .font(Theme.Fonts.headline)
                .foregroundStyle(.primary)

            Text("Tap + to capture your first timeline photo.\nTrack face, body shape, skin, and hair changes over time.")
                .font(Theme.Fonts.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
    }

    // MARK: - Thumbnail Cell

    private func thumbnailCell(_ record: MediaRecord) -> some View {
        Button(action: { expandedRecord = record }) {
            ZStack {
                if let thumbnail = record.thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 120)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.secondarySystemBackground))
                        .frame(height: 120)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        )
                }

                // Date badge
                VStack {
                    HStack {
                        Spacer()
                        Text(formatDate(record.captureDate))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.black.opacity(0.55))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .padding(5)
                    }
                    Spacer()
                }

                // Voice indicator
                if record.voiceData != nil {
                    VStack {
                        Spacer()
                        HStack {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(.white)
                                .padding(4)
                                .background(.black.opacity(0.5))
                                .clipShape(Circle())
                                .padding(4)
                            Spacer()
                        }
                    }
                }
            }
            .frame(height: 120)
        }
    }

    // MARK: - Add Button

    private var addButton: some View {
        Button(action: { showPhotoPicker = true }) {
            HStack(spacing: 8) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 16))
                Text("Add Photo")
            }
        }
        .asAccentButton()
        .padding(.horizontal, 40)
        .padding(.bottom, 30)
    }

    // MARK: - Photo Selection

    private func handlePhotoSelection(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                // Generate thumbnail
                let thumbnail = generateThumbnail(from: image, size: CGSize(width: 200, height: 200))
                let thumbData = thumbnail?.jpegData(compressionQuality: 0.6)

                let record = MediaRecord(
                    captureDate: Date(),
                    photoData: data,
                    thumbnailData: thumbData,
                    bodySystem: selectedBodySystem,
                    notes: notes.isEmpty ? nil : notes
                )

                modelContext.insert(record)
                try? modelContext.save()

                notes = ""
            }
        }
    }

    private func generateThumbnail(from image: UIImage, size: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    // MARK: - Detail Sheet

    private func detailSheet(_ record: MediaRecord) -> some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let photo = record.photo {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
                            .padding(.horizontal, 22)
                    }

                    // Metadata
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label(record.captureDate.formatted(date: .long, time: .shortened),
                                  systemImage: "calendar")
                                .font(Theme.Fonts.caption)
                                .foregroundStyle(.secondary)

                            Spacer()

                            if let system = record.bodySystem {
                                Label(system, systemImage: "tag")
                                    .font(Theme.Fonts.caption)
                                    .foregroundStyle(Theme.Colors.accent)
                            }
                        }

                        if let notes = record.notes {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("NOTES")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                Text(notes)
                                    .font(Theme.Fonts.callout)
                            }
                        }

                        // Voice playback placeholder
                        if record.voiceData != nil {
                            HStack {
                                Image(systemName: "mic.fill")
                                Text("Voice memo attached")
                                    .font(Theme.Fonts.caption)
                            }
                            .foregroundStyle(Theme.Colors.accentSecondary)
                        }
                    }
                    .padding(.horizontal, 22)
                }
                .padding(.top, 16)
            }
            .background(Color(.systemBackground))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(formatDate(record.captureDate))
                        .font(Theme.Fonts.headline)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { expandedRecord = nil }
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "MMM d, yyyy"
        return df.string(from: date)
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(Theme.Fonts.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? Theme.Colors.accent : Color(.secondarySystemBackground))
                )
        }
    }
}

// MARK: - Preview

#Preview {
    TimelineView()
}