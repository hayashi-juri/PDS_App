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
    @State private var healthData: [HealthDataItem] = []

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

                // データ一覧
                Section(header: Text("共有するデータ")) {
                    if healthData.isEmpty {
                        Text("データがありません").foregroundColor(.gray)
                    } else {
                        ForEach(healthData) { item in
                            VStack(alignment: .leading) {
                                Text(item.type)
                                    .font(.headline)
                                Text("値: \(item.value)")
                                    .font(.subheadline)
                                Text("日付: \(item.date, formatter: dateFormatter)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
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

    private func fetchHealthData() {
        firestoreManager.fetchHealthData { data in
            healthData = data
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

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
}()
