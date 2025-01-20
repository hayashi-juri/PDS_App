//
//  DataShareView.swift
//  PDS_App
//
//  Created by Juri Hayashi on 2025/01/10.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Combine

struct DataShareView: View {
    let userID: String

    @ObservedObject var firestoreManager: FirestoreManager

    @State private var sharedData: [(userName: String, data: [HealthDataItem])] = [] // 他のユーザーのヘルスデータ
    @State private var selectedGroup: String = "Family" // 初期選択グループ
    @State private var errorMessage: String?
    @State private var selectedGroupPublisher = PassthroughSubject<String, Never>()
    // デバウンス処理用のキャンセラ
    @State private var cancellables: Set<AnyCancellable> = []

    let groupOptions: [String] = ["Family", "Friends", "Public"] // グループオプション
    let dataTypeDisplayNames: [String: String] = [
        "stepCount": "Steps",
        "distanceWalkingRunning": "Distance",
        "basalEnergyBurned": "Basal Energy",
        "activeEnergyBurned": "Active Energy"
    ]
    let dataTypeUnits: [String: String] = [
        "stepCount": "steps",
        "distanceWalkingRunning": "km",
        "basalEnergyBurned": "kcal",
        "activeEnergyBurned": "kcal"
    ]

    var body: some View {
        VStack {
            Text("Data Sharing")
                .font(.title)
                .padding()

            // グループ選択
            Picker("Select Group", selection: $selectedGroup) {
                ForEach(groupOptions, id: \.self) { group in
                    Text(group).tag(group)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            /*.onReceive(Just(selectedGroup)) { _ in
                fetchData()
            }*/
            .onChange(of: selectedGroup) { newValue in
                    selectedGroupPublisher.send(newValue)
                    }
            Form {
                Section(header: Text("Shared Data")) {
                    if sharedData.isEmpty {
                        Text("No shared data available.")
                            .foregroundColor(.gray)
                    } else {
                        List {
                            ForEach(sharedData, id: \.userName) { userData in
                                Section(header: Text(userData.userName).font(.headline)) {
                                    ForEach(userData.data, id: \.id) { item in
                                        VStack(alignment: .leading) {
                                            let typeDisplayName = dataTypeDisplayNames[item.type] ?? item.type
                                            let valueText = String(format: "%.2f", item.value)
                                            let unit = dataTypeUnits[item.type] ?? ""
                                            Text("\(typeDisplayName): \(valueText) \(unit)")
                                            Text("Date: \(item.date, formatter: dateFormatter)")
                                                .font(.footnote)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .onAppear {
                selectedGroupPublisher
                            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
                            .sink { _ in
                                fetchData()
                                print("fetchData called onAppear")
                            }
                            .store(in: &cancellables)
            }

            // エラーメッセージ
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            }
        }
    }

    private func fetchData() {
        print("データシェアビュー：Fetching shared data for group: \(selectedGroup)")
        guard let currentUserID = firestoreManager.userID else {
            self.errorMessage = "Failed to fetch shared data: User ID is nil."
            return
        }

        firestoreManager.fetchSharedHealthData(for: currentUserID, groupID: selectedGroup) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let userDataList):
                    print("データシェアビュー：Fetched data: \(userDataList)") // デバッグ用ログ
                    self.sharedData = userDataList
                    self.errorMessage = userDataList.isEmpty ? "No shared data available for group \(self.selectedGroup)." : nil
                case .failure(let error):
                    self.errorMessage = "Failed to fetch shared data: \(error.localizedDescription)"
                    print("Error fetching data: \(error.localizedDescription)")
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

