//
//  ProfileStore.swift
//  Stretheo
//

import Foundation
import OSLog
import UIKit

@MainActor
final class ProfileStore {
    static let shared = ProfileStore()

    private static let maxAvatarDimension: CGFloat = 200
    private static let legacyUserDefaultsKey = "userAvatarData"

    // PRIVACY FIX: Avatar moved from UserDefaults to Application Support with NSFileProtectionComplete
    private static let avatarURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("com.zapreff.Stretheo", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("avatar.jpg")
    }()

    private static var didMigrateLegacyAvatar = false

    private init() {
        migrateLegacyAvatarIfNeeded()
    }

    func loadAvatarImage() -> UIImage? {
        migrateLegacyAvatarIfNeeded()
        guard let data = loadAvatar(), let image = UIImage(data: data) else { return nil }
        return image
    }

    func saveAvatarImage(_ image: UIImage) throws {
        let resized = Self.resize(image, maxDimension: Self.maxAvatarDimension)
        guard let data = resized.jpegData(compressionQuality: 0.85) else {
            throw AppError.persistenceFailed("Could not encode avatar")
        }
        saveAvatar(data)
    }

    func deleteAvatarImage() {
        deleteAvatar()
    }

    private func saveAvatar(_ data: Data) {
        do {
            try data.write(to: Self.avatarURL, options: [.atomic, .completeFileProtection])
        } catch {
            StretheoLog.privacy.error(
                "Avatar write failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private func loadAvatar() -> Data? {
        try? Data(contentsOf: Self.avatarURL)
    }

    private func deleteAvatar() {
        try? FileManager.default.removeItem(at: Self.avatarURL)
    }

    private func migrateLegacyAvatarIfNeeded() {
        guard !Self.didMigrateLegacyAvatar else { return }
        Self.didMigrateLegacyAvatar = true

        if FileManager.default.fileExists(atPath: Self.avatarURL.path) {
            UserDefaults.standard.removeObject(forKey: AppSettingsKey.profileAvatarJPEG)
            UserDefaults.standard.removeObject(forKey: Self.legacyUserDefaultsKey)
            return
        }

        if let legacyData = UserDefaults.standard.data(forKey: Self.legacyUserDefaultsKey) {
            saveAvatar(legacyData)
            UserDefaults.standard.removeObject(forKey: Self.legacyUserDefaultsKey)
            UserDefaults.standard.removeObject(forKey: AppSettingsKey.profileAvatarJPEG)
            return
        }

        if let legacyData = UserDefaults.standard.data(forKey: AppSettingsKey.profileAvatarJPEG) {
            saveAvatar(legacyData)
            UserDefaults.standard.removeObject(forKey: AppSettingsKey.profileAvatarJPEG)
            UserDefaults.standard.removeObject(forKey: Self.legacyUserDefaultsKey)
        }
    }

    private static func resize(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension, maxSide > 0 else { return image }

        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
