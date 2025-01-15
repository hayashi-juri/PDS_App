//
//  DataShareView.swift
//  PDS_App
//
//  Created by Juri Hayashi on 2025/01/10.
//

import SwiftUI

struct DataShareView: View {
    let userID: String
    @ObservedObject var firestoreManager: FirestoreManager

    @State private var groupSettings: [String: [String: Bool]] = [:]
    @State private var sharedData: [HealthDataItem] = []
    @State private var selectedGroup: String = "Family" // 初期選択グループ
    @State private var errorMessage: String?

    let dataTypeDisplayNames: [String: String] = [
        "stepCount": "Steps",
        "distanceWalkingRunning": "Distance",
        "basalEnergyBurned": "Basal Energy",
        "activeEnergyBurned": "Active Energy"
    ]

    var body: some View {
        
        VStack {
            Text("Data Sharing")
                .font(.title)
                .padding()

            Picker("Select Group", selection: $selectedGroup) {
                ForEach(Array(groupSettings.keys), id: \.self) { group in
                    Text(group).tag(group)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            .onChange(of: selectedGroup) {
                filterSharedData()
            }

            Form {
                Section(header: Text("Shared Health Data")) {
                    if sharedData.isEmpty {
                        Text("No data available for this group.")
                            .foregroundColor(.gray)
                    }

                    else {
                        // データをリスト化
                        List(sharedData) { item in
                            VStack(alignment: .leading) {
                                Text("Type: \(dataTypeDisplayNames[item.type] ?? item.type)")
                                Text("Value: \(String(format: "%.2f", item.value))")
                                Text("Date: \(item.date, formatter: dateFormatter)")
                            }
                        }
                    }
                }
            }

            .onAppear {
                fetchGroupSettings()
            }

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            }
        }
    }

    private func fetchGroupSettings() {
        firestoreManager.fetchGroupSettings(userID: userID) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let settings):
                    self.groupSettings = settings
                    if let firstGroup = settings.keys.first {
                        self.selectedGroup = firstGroup
                        self.filterSharedData()
                    }
                case .failure(let error):
                    self.errorMessage = "Failed to fetch group settings: \(error.localizedDescription)"
                }
            }
        }
    }

    private func filterSharedData() {
        firestoreManager.fetchFilteredHealthData(userID: userID, groupID: selectedGroup) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    self.sharedData = data
                case .failure(let error):
                    self.errorMessage = "Failed to fetch health data: \(error.localizedDescription)"
                }
            }
        }
    }


    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
}

