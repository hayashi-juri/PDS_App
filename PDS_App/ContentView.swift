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
                    /*VisualizeView(firestoreManager: firestoreManager)
                        .tabItem {
                            Image(systemName: "chart.bar")
                            Text("データ")
                        }*/

                    SettingView(firestoreManager: firestoreManager, healthKitManager: healthKitManager)
                        .tabItem {
                            Image(systemName: "gear")
                            Text("設定")
                        }
                }
                .onAppear {
                    if let userID = healthKitManager.userID {
                        firestoreManager.fetchHealthData(userID: userID) { result in
                            switch result {
                            case .success:
                                print("データ取得成功")
                            case .failure(let error):
                                print("データ取得失敗: \(error.localizedDescription)")
                            }
                        }
                    }
                }
            } else {
                ProgressView("認証中...")
                    .onAppear {
                        healthKitManager.authorizeAndFetchHealthData(firestoreManager: firestoreManager) { success, _ in
                            isHealthKitAuthorized = success
                        }
                    }
            }
        }
    }
}

