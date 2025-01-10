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

    var body: some View {
        if healthKitManager.isAuthorized {
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
            VStack(spacing: 20) {
                Text("HealthKitの認証が必要です")
                    .font(.headline)

                Button(action: {
                    healthKitManager.requestAuthorization { success, error in
                        if success {
                            print("HealthKit認証が成功しました")
                        } else {
                            print("HealthKit認証に失敗しました: \(error?.localizedDescription ?? "Unknown error")")
                        }
                    }
                }) {
                    Text("認証をリクエスト")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .padding()
            .navigationTitle("認証が必要です")
        }
    }
}

