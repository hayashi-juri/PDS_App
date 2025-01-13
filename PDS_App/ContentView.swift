/*
 ContentView.swift
 PDS_App
 Created by Juri Hayashi on 2024/12/20.

 タブを提供します：

 データの視覚化
 データの共有
 設定管理
 */
import SwiftUI

struct ContentView: View {
    @StateObject var firestoreManager = FirestoreManager()
    @StateObject var healthKitManager = HealthKitManager()
    @State private var isHealthKitAuthorized: Bool = false

    var body: some View {
        Group {
            if isHealthKitAuthorized {
                TabView {
                    VisualizeView(firestoreManager: firestoreManager, healthKitManager: healthKitManager)
                        .tabItem {
                            Image(systemName: "chart.bar")
                            Text("Data Graph")
                        }

                    SettingView(firestoreManager: firestoreManager, healthKitManager: healthKitManager)
                        .tabItem {
                            Image(systemName: "gear")
                            Text("Settings")
                        }
                }
                .onAppear {
                    if let userID = healthKitManager.userID {
                        firestoreManager.fetchHealthData(userID: userID) { result in
                            switch result {
                            case .success:
                                print("Data fetched successfully!")
                            case .failure(let error):
                                print("Data fetch failed: \(error.localizedDescription)")
                            }
                        }
                    }
                }
            } else {
                ProgressView("Authorising...")
                    .onAppear {
                        healthKitManager.authorize { success, error in
                            if success {
                                isHealthKitAuthorized = true
                                print("HealthKit authorization successful.")
                            } else {
                                print("Authorization failed: \(error?.localizedDescription ?? "Unknown error")")
                            }
                        }
                    }
            }
        }
    }
}

