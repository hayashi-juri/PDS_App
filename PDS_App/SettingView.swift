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
        HealthDataSetting(id: "stepCount", type: "Step Count", isShared: true),
        HealthDataSetting(id: "distanceWalkingRunning", type: "Distance", isShared: false),
        HealthDataSetting(id: "basalEnergyBurned", type: "Basal Metabolism", isShared: true),
        HealthDataSetting(id: "activeEnergyBurned", type: "Active Energy", isShared: false),

    ]
    @State private var userName: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Groups")) {
                    Picker("Please select a group", selection: $groupSelection) {
                        Text("Family").tag("Family")
                        Text("Friends").tag("Friends")
                        Text("Public").tag("Public")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                Section(header: Text("Given Name / Anonymous")) {
                    Toggle("Do you want to use anonymous", isOn: $isAnonymous)
                        .onChange(of: isAnonymous) { newValue in
                            if !newValue {
                                userName = "" // 匿名が無効化された場合、ユーザーネームをリセット
                            }
                        }

                    // 匿名の場合のみ表示
                    if isAnonymous {
                        TextField("Fill in your name", text: $userName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding()
                    }                }

                Section(header: Text("Data Deletion")) {
                    DatePicker("Setting Data Deletion", selection: $deletionDate, displayedComponents: .date)
                        .datePickerStyle(CompactDatePickerStyle())
                }

                Section(header: Text("Health Data Sharing")) {
                    ForEach($healthDataSettings) { $setting in
                        Toggle(setting.type, isOn: $setting.isShared)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarItems(trailing: Button("Save") {
                saveSettings()
            })
        }
    }

    private func saveSettings() {
        guard let userID = healthKitManager.userID else {
            print("error: userID does not exist")
            return
        }

        firestoreManager.saveUserSettings(
            userID: userID,
            groupID: groupSelection,
            isAnonymous: isAnonymous,
            deletionDate: deletionDate,
            healthDataSettings: healthDataSettings,
            userName: isAnonymous ? userName : nil
        ) { result in
            switch result {
            case .success:
                print("Settings saved successfully!")
            case .failure(let error):
                print("Settings save failed: \(error.localizedDescription)")
            }
        }
    }
}

struct HealthDataSetting: Identifiable {
    var id: String
    var type: String
    var isShared: Bool
}
