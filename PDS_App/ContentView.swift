//
//  ContentView.swift
//  PDS_App
//
//  Created by Juri Hayashi on 2024/12/20.
//
import SwiftUI

struct ContentView: View {
    let firestoreManager: FirestoreManager // Firestore管理を受け取る
    @StateObject var healthKitManager: HealthKitManager // HealthKit管理
    @State private var isHealthKitAuthorized: Bool = false // 認証状態のトラッキング

    var body: some View {
        Group {
            if isHealthKitAuthorized {
                TabView {
                    VisualizeView() // データのグラフ化タブ
                        .tabItem {
                            Image(systemName: "chart.bar")
                            Text("データ")
                        }

                    DataShareView() // データシェアタブ
                        .tabItem {
                            Image(systemName: "person.2.fill")
                            Text("シェア")
                        }

                    SettingView(firestoreManager: firestoreManager) // 設定タブ
                        .tabItem {
                            Image(systemName: "gear")
                            Text("設定")
                        }
                }
            } else {
                // 認証中のローディング画面を表示
                VStack {
                    ProgressView("HealthKitの認証中...")
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding()
                }
                .onAppear(perform: requestHealthKitAuthorization)
            }
        }
    }

    /// HealthKitの認証をリクエスト
    private func requestHealthKitAuthorization() {
        healthKitManager.requestAuthorization { success, error in
            DispatchQueue.main.async {
                if success {
                    isHealthKitAuthorized = true
                    print("HealthKit認証が成功しました")
                } else {
                    print("HealthKit認証に失敗しました: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        }
    }
}
