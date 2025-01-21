//
//  ExportHealthDataView.swift
//  PDS_App
//
//  Created by Juri Hayashi on 2025/01/21.
//
import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import UIKit

struct ExportHealthDataView: View {
    @ObservedObject var firestoreManager: FirestoreManager
    let userID: String

    @State private var isExporting = false
    @State private var exportResultMessage: String? = nil
    @State private var fileToShare: URL? = nil
    @State private var showingShareSheet = false
    @State private var showingDocumentPicker = false

    var body: some View {
        VStack {
            Text("Export Health Data")
                .font(.title)
                .padding()

            if isExporting {
                ProgressView("Exporting...")
                    .padding()
            } else {
                Button("Export Data") {
                    exportData()
                }
                .padding()
                .buttonStyle(.borderedProminent)
            }

            if let message = exportResultMessage {
                Text(message)
                    .foregroundColor(message.contains("Error") ? .red : .green)
                    .padding()
            }
        }
        .padding()
        .sheet(isPresented: $showingShareSheet) {
            if let fileToShare = fileToShare {
                ShareSheet(fileURL: fileToShare)
            }
        }
        .sheet(isPresented: $showingDocumentPicker) {
            if let fileToShare = fileToShare {
                DocumentPicker(fileURL: fileToShare)
            }
        }
    }

    private func exportData() {
        isExporting = true
        exportResultMessage = nil

        firestoreManager.exportAndCompressHealthData(for: userID) { result in
            DispatchQueue.main.async {
                isExporting = false
                switch result {
                case .success(let fileURL):
                    exportResultMessage = "👌 Export complete: \(fileURL.lastPathComponent)"
                    fileToShare = fileURL
                    showingShareSheet = true
                case .failure(let error):
                    exportResultMessage = "🥺 Error: \(error.localizedDescription)"
                }
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let fileURL: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        return activityVC
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct DocumentPicker: UIViewControllerRepresentable {
    let fileURL: URL

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let documentPicker = UIDocumentPickerViewController(forExporting: [fileURL])
        documentPicker.modalPresentationStyle = .formSheet
        return documentPicker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
}
