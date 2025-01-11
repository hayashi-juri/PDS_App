//
//  SettingView.swift
//  PDS_App
//
//  Created by Juri Hayashi on 2025/01/10.
//

import SwiftUI

struct SettingView: View {
    @State private var groupSelection: String = "Public"
    @State private var isAnonymous: Bool = false
    @State private var deletionDate: Date = Date()
    @State private var healthDataSettings: [HealthDataSetting] = [
        HealthDataSetting(id: "stepCount", type: "歩数", isShared: true),
        HealthDataSetting(id: "distanceWalkingRunning", type: "距離", isShared: false),
        HealthDataSetting(id: "basalEnergyBurned", type: "基礎代謝", isShared: true),
        HealthDataSetting(id: "activeEnergyBurned", type: "消費カロリー", isShared: false),

    ]

    let firestoreManager: FirestoreManager // FirestoreManagerを受け取る

    var body: some View {
        NavigationView {
            Form {
                // グループ選択
                Section(header: Text("共有グループ")) {
                    Picker("グループを選択", selection: $groupSelection) {
                        Text("Family").tag("Family")
                        Text("Friends").tag("Friends")
                        Text("Public").tag("Public")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                // 実名・匿名
                Section(header: Text("匿名または実名")) {
                    Toggle("匿名で共有しますか？", isOn: $isAnonymous)
                }

                // 削除期限
                Section(header: Text("データの削除期限")) {
                    DatePicker("削除期限を設定", selection: $deletionDate, displayedComponents: .date)
                        .datePickerStyle(CompactDatePickerStyle())
                }

                // 各データ項目の共有設定
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

            .onAppear {
                fetchHealthData()
            }
        }
    }

    private func saveSettings() {
        let settings = [
            "isAnonymous": isAnonymous,
            "deletionDate": ISO8601DateFormatter().string(from: deletionDate)
        ] as [String: Any]

        firestoreManager.saveGroupSettings(groupID: groupSelection, settings: settings) { result in
            switch result {
            case .success:
                print("設定が保存されました")
            case .failure(let error):
                print("設定の保存に失敗しました: \(error.localizedDescription)")
            }
        }
    }
}

/*private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
}()*/
