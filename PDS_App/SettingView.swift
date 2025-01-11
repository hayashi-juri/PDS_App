//
//  SettingView.swift
//  PDS_App
//
//  Created by Juri Hayashi on 2025/01/10.
/*
 Firestoreから保存されているデータ取得する。
 DataShareViewやVisualizerViewとデータを連携できるようにする。
 */
//
import SwiftUI

struct SettingView: View {
    let firestoreManager: FirestoreManager
    @ObservedObject var healthKitManager: HealthKitManager

    @State private var groupSelection: String = "Public"
    @State private var isAnonymous: Bool = false
    @State private var deletionDate: Date = Date()
    @State private var healthDataSettings: [HealthDataSetting] = [
        HealthDataSetting(id: "stepCount", type: "歩数", isShared: true),
        HealthDataSetting(id: "distanceWalkingRunning", type: "距離", isShared: false),
        HealthDataSetting(id: "basalEnergyBurned", type: "基礎代謝", isShared: true),
        HealthDataSetting(id: "activeEnergyBurned", type: "消費カロリー", isShared: false),

    ]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("共有グループ")) {
                    Picker("グループを選択", selection: $groupSelection) {
                        Text("Family").tag("Family")
                        Text("Friends").tag("Friends")
                        Text("Public").tag("Public")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                Section(header: Text("匿名または実名")) {
                    Toggle("匿名で共有しますか？", isOn: $isAnonymous)
                }

                Section(header: Text("データの削除期限")) {
                    DatePicker("削除期限を設定", selection: $deletionDate, displayedComponents: .date)
                        .datePickerStyle(CompactDatePickerStyle())
                }

                Section(header: Text("共有設定")) {
                    ForEach($healthDataSettings) { $setting in
                        Toggle(setting.type, isOn: $setting.isShared)
                    }
                }
            }
            .navigationTitle("設定")
            .navigationBarItems(trailing: Button("保存") {
                saveSettings()
            })
        }
    }

    private func saveSettings() {
        guard let userID = healthKitManager.userID else {
            print("エラー: userIDが設定されていません")
            return
        }

        firestoreManager.saveUserSettings(
            userID: userID,
            groupID: groupSelection,
            isAnonymous: isAnonymous,
            deletionDate: deletionDate,
            healthDataSettings: healthDataSettings
        ) { result in
            switch result {
            case .success:
                print("設定が保存されました")
            case .failure(let error):
                print("設定の保存に失敗しました: \(error.localizedDescription)")
            }
        }
    }
}

struct HealthDataSetting: Identifiable {
    var id: String
    var type: String
    var isShared: Bool
}
