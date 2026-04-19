//
//  Created by Mories Hutapea,S.E.,S.Kom
//  Date: 2026-04-19
//

import SwiftUI

private enum AppMetadata {
    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
    }

    static var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
    }
}

struct AboutAppPanel: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("About CleanMacNasio")
                .font(.system(size: 14, weight: .semibold))

            aboutRow(label: "App", value: "CleanMacNasio")
            aboutRow(label: "Version", value: "\(AppMetadata.appVersion) (\(AppMetadata.buildNumber))")

            Button("Show Full About") {
                openWindow(id: "about-window")
            }
            .controlSize(.small)
        }
        .padding(16)
        .background(DashboardStyle.panel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(DashboardStyle.border, lineWidth: 1)
        )
    }

    private func aboutRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(DashboardStyle.mutedText)
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct AboutWindowView: View {
    var body: some View {
        AboutDetailView(versionText: "\(AppMetadata.appVersion) (\(AppMetadata.buildNumber))")
    }
}

private struct AboutDetailView: View {
    let versionText: String

    private let targetDetails: [AboutTargetInfo] = [
        .init(name: "Library Caches", paths: ["~/Library/Caches"]),
        .init(name: "Library Logs", paths: ["~/Library/Logs"]),
        .init(name: "Temporary Directory", paths: ["/var/folders/... (NSTemporaryDirectory)"]),
        .init(name: "Xcode DerivedData", paths: ["~/Library/Developer/Xcode/DerivedData"]),
        .init(name: "Xcode Archives", paths: ["~/Library/Developer/Xcode/Archives"], note: "Perlu konfirmasi khusus sebelum delete."),
        .init(name: "CocoaPods Caches", paths: ["~/Library/Caches/CocoaPods"]),
        .init(name: "SwiftPM Caches", paths: ["~/Library/Caches/org.swift.swiftpm"]),
        .init(name: "npm Caches", paths: ["~/.npm"]),
        .init(name: "Yarn Caches", paths: ["~/Library/Caches/Yarn", "~/.cache/yarn"]),
        .init(name: "pnpm Store", paths: ["~/Library/pnpm/store", "~/.pnpm-store"]),
        .init(name: "Maven Caches", paths: ["~/.m2/repository"]),
        .init(name: "Ivy Caches", paths: ["~/.ivy2/cache"]),
        .init(name: "pip Caches", paths: ["~/.cache/pip", "~/Library/Caches/pip"]),
        .init(name: "Cargo Caches", paths: ["~/.cargo/registry", "~/.cargo/git"]),
        .init(name: "Docker Caches", paths: ["~/.docker/buildx", "~/Library/Caches/com.docker.docker", "~/Library/Containers/com.docker.docker/Data/log"], note: "Fokus ke cache/log lokal Docker yang umum."),
        .init(name: "Android Studio Caches", paths: [
            "~/Library/Caches/Google/AndroidStudio*",
            "~/Library/Logs/Google/AndroidStudio*",
            "~/Library/Application Support/Google/AndroidStudio*/{caches,plugins}",
            "~/Library/Caches/JetBrains/AndroidStudio*",
            "~/Library/Logs/JetBrains/AndroidStudio*",
            "~/Library/Application Support/JetBrains/AndroidStudio*/{caches,plugins}"
        ]),
        .init(name: "Gradle Caches", paths: ["~/.gradle/caches/<versi>", "~/.gradle/caches/<shared>", "~/.gradle/wrapper"], note: "Ditampilkan per versi + shared + wrapper."),
        .init(name: "Flutter/Dart Caches", paths: ["~/.pub-cache", "~/.dartServer", "~/Library/Caches/flutter", "~/Library/Caches/dart", "~/Library/Caches/pub"]),
        .init(name: "Homebrew Caches", paths: ["~/Library/Caches/Homebrew", "~/.cache/Homebrew", "/Library/Caches/Homebrew"]),
        .init(name: "Nix Caches", paths: ["~/.cache/nix", "~/.local/state/nix", "~/Library/Caches/nix"]),
        .init(name: "Trash", paths: ["~/.Trash"])
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("About CleanMacNasio")
                .font(.title3)
                .fontWeight(.bold)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    sectionTitle("Ringkasan")
                    detailText("Name: CleanMacNasio")
                    detailText("Version: \(versionText)")
                    detailText("Fungsi utama: scan cache/junk developer umum dan hapus hanya item yang kamu pilih.")
                    detailText("Aplikasi tidak auto-scan saat dibuka. Scan hanya jalan saat tombol Scan ditekan.")

                    sectionTitle("Cara Kerja")
                    detailText("1. Tekan Scan untuk memulai multi-path scanning.")
                    detailText("2. Tiap kategori menampilkan ukuran total, jumlah file, dan top item terbesar.")
                    detailText("3. Pilih kategori yang ingin dibersihkan (manual selection).")
                    detailText("4. Tekan Clean Selected untuk hapus kategori terpilih saja.")
                    detailText("5. Pantau progress scan/delete di status panel.")
                    detailText("6. Tombol Stop muncul saat scan berjalan untuk membatalkan proses.")

                    sectionTitle("Target & Lokasi Scan")
                    ForEach(targetDetails) { target in
                        targetCard(target)
                    }

                    sectionTitle("Keamanan")
                    detailText("Excluded path tidak akan dihapus.")
                    detailText("Proteksi default aktif untuk path/file sensitif, termasuk: .ssh, Keychains, Provisioning Profiles, .git, serta ekstensi sensitif seperti jks, keystore, p12, cer, pem, key, mobileprovision, db, sqlite, sqlite3.")
                    detailText("Xcode Archives memakai konfirmasi ekstra sebelum proses delete.")

                    sectionTitle("Batasan")
                    detailText("App fokus ke lokasi cache/junk umum developer, bukan file project source.")
                    detailText("Folder yang tidak ada akan otomatis dilewati saat scan (tidak dianggap error fatal).")
                    detailText("Hasil scan sangat bergantung pada kondisi path dan izin akses user macOS saat ini.")
                }
            }
        }
        .padding(20)
        .frame(minWidth: 680, minHeight: 620, alignment: .topLeading)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(DashboardStyle.mutedText)
    }

    private func detailText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func targetCard(_ target: AboutTargetInfo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(target.name)
                .font(.system(size: 13, weight: .bold))
            ForEach(target.paths, id: \.self) { path in
                Text("• \(path)")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(DashboardStyle.mutedText)
            }
            if let note = target.note {
                Text(note)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(DashboardStyle.mutedText)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DashboardStyle.recessedPanel, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

private struct AboutTargetInfo: Identifiable {
    let id: UUID
    let name: String
    let paths: [String]
    let note: String?

    init(name: String, paths: [String], note: String? = nil) {
        self.id = UUID()
        self.name = name
        self.paths = paths
        self.note = note
    }
}
