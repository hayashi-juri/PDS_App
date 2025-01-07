//
//  ContentView.swift
//  PDS_App
//
//  Created by Juri Hayashi on 2024/12/20.
//

import SwiftUI
import FirebaseFirestore

struct ContentView: View {
    @StateObject var healthKitManager = HealthKitManager()
    private let firestoreManager = FirestoreManager()

    var body: some View {
        VStack {
            Text("Firestore Test")
                .padding()

            // "Save Test Data" ボタン
            Button(action: {
                handleFirestoreOperation {
                    saveTestData()
                }
            }) {
                Text("Save Test Data")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }

            // "Fetch Test Data" ボタン
            Button(action: {
                handleFirestoreOperation {
                    fetchTestData()
                }
            }) {
                Text("Fetch Test Data")
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .onAppear {
            healthKitManager.requestAuthorization { success, error in
                if success {
                    print("HealthKit authorization completed successfully")
                } else {
                    print("HealthKit authorization failed: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        }
    }

    /// Firestoreの操作を実行する前にHealthKit認証を確認
    private func handleFirestoreOperation(_ operation: @escaping () -> Void) {
        if healthKitManager.isAuthorized {
            operation()
        } else {
            print("HealthKit is not authorized. Requesting authorization...")
            healthKitManager.requestAuthorization { success, _ in
                if success {
                    operation()
                } else {
                    print("Operation aborted because HealthKit authorization failed.")
                }
            }
        }
    }

    /// FirestoreManagerを使用してデータを保存
    private func saveTestData() {
        firestoreManager.saveTestData { result in
            switch result {
            case .success:
                print("Data successfully saved to Firestore!")
            case .failure(let error):
                print("Error saving data: \(error.localizedDescription)")
            }
        }
    }

    /// FirestoreManagerを使用してデータを取得
    private func fetchTestData() {
        firestoreManager.fetchTestData { result in
            switch result {
            case .success(let documents):
                for document in documents {
                    print("Fetched Data: \(document)")
                }
            case .failure(let error):
                print("Error fetching data: \(error.localizedDescription)")
            }
        }
    }
}

