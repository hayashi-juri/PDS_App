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

    @State private var sharedOthersData: [(userName: String, data: [HealthDataItem])] = [] // 他のユーザーのヘルスデータ
    @State private var sharedMyData: [(userName: String, totalData: [String: Double])] = [] // 他のユーザーのヘルスデータ
    @State private var selectedGroup: String = "Family" // 初期選択グループ
    @State private var errorMessage: String?
    @State private var selectedGroupPublisher = PassthroughSubject<String, Never>()
    // デバウンス処理用のキャンセラ
    @State private var cancellables: Set<AnyCancellable> = []
    @State private var isShowingExportView = false

    let groupOptions: [String] = ["Family", "Friends", "Public"] // グループオプション

    let dataTypeDisplayNames: [String: String] = [
        "stepCount": "Steps",
        "distanceWalkingRunning": "Distance",
        "basalEnergyBurned": "Basal Energy",
        "activeEnergyBurned": "Active Energy"
    ]
    let fixedDataTypeOrder: [String] = ["stepCount", "distanceWalkingRunning", "basalEnergyBurned", "activeEnergyBurned"]
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
            
            Button("Export My Data") {
                isShowingExportView = true
            }
            .padding()
            .sheet(isPresented: $isShowingExportView) {
                ExportHealthDataView(firestoreManager: firestoreManager, userID: userID)
            }

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
            .onChange(of: selectedGroup) { oldValue, newValue in
                selectedGroupPublisher.send(newValue)
            }

            Form {
                Section(header: Text("My Data (Last 24 Hours)")) {
                    if sharedMyData.isEmpty {
                        Text("No shared data available.")
                            .foregroundColor(.gray)
                    } else {
                        ForEach(sharedMyData, id: \.userName) { userData in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(userData.userName)
                                    .font(.headline)
                                    .padding(.bottom, 4)

                                ForEach(Array(userData.totalData.keys.sorted()), id: \.self) {
                                    dataType in
                                    if let value = userData.totalData[dataType] {
                                        HStack {
                                            let typeDisplayName = dataTypeDisplayNames[dataType] ?? dataType
                                            let valueText = numberFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
                                            let unit = dataTypeUnits[dataType] ?? ""

                                            Text("\(typeDisplayName):")
                                            Spacer()
                                            Text("\(valueText) \(unit)")
                                                .bold()
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }

                Section(header: Text("Others' Data")) {
                    if sharedOthersData.isEmpty {
                        Text("No shared data available.")
                            .foregroundColor(.gray)
                    } else {
                        ForEach(sharedOthersData, id: \.userName) { userData in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(userData.userName)
                                    .font(.headline)
                                    .padding(.bottom, 4)

                                ForEach(userData.data, id: \.id) { item in
                                    HStack {
                                        let typeDisplayName = dataTypeDisplayNames[item.type] ?? item.type
                                        let valueText = numberFormatter.string(from: NSNumber(value: item.value)) ?? "\(item.value)"
                                        let unit = dataTypeUnits[item.type] ?? ""

                                        Text("\(typeDisplayName):")
                                        Spacer()
                                        Text("\(valueText) \(unit)")
                                            .bold()
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
            }

        }

        .onAppear {
            selectedGroupPublisher
                .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
                .sink { _ in
                    fetchMyData()
                    print("fetchMydaya called onAppear")
                    fetchOthersData()
                    print("fetchOthersData called onAppear")
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


    private func fetchMyData() {
        guard let currentUserID = firestoreManager.userID else {
            self.errorMessage = "Failed to fetch shared data: User ID is nil."
            return
        }

        firestoreManager.fetchMyHealthData(for: currentUserID, groupID: selectedGroup) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let userDataList):
                    self.sharedMyData = userDataList
                    self.errorMessage = userDataList.isEmpty ? "No shared data available" : nil
                case .failure(let error):
                    self.errorMessage = "Failed to fetch shared data: \(error.localizedDescription)"
                }
            }
        }
    }


    private func fetchOthersData() {
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
                    self.sharedOthersData = userDataList
                    self.errorMessage = userDataList.isEmpty ? "No shared data available for group \(self.selectedGroup)." : nil
                case .failure(let error):
                    self.errorMessage = "Failed to fetch shared data: \(error.localizedDescription)"
                    print("Error fetching data: \(error.localizedDescription)")
                }
            }
        }
    }

    private var numberFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0 // 小数点以下を切り捨てる
        return formatter
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        //formatter.timeStyle = .short
        return formatter
    }
}

