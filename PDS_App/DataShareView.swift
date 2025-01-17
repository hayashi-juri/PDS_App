//
//  DataShareView.swift
//  PDS_App
//
//  Created by Juri Hayashi on 2025/01/10.
//

import SwiftUI
import Charts
import FirebaseAuth
import FirebaseFirestore

struct DataShareView: View {
    let userID: String

    @ObservedObject var firestoreManager: FirestoreManager

    @State private var myData: [HealthDataItem] = [] // 自分のヘルスデータ
    @State private var sharedData: [(userName: String, data: [HealthDataItem])] = [] // 他のユーザーのヘルスデータ

    @State private var selectedGroup: String = "Family" // 初期選択グループ
    @State private var errorMessage: String?

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
            .onChange(of: selectedGroup) {
                fetchData()
            }

            Form {
                Section(header: Text("My Data")) {
                    if myData.isEmpty {
                        Text("No health data available.")
                            .foregroundColor(.gray)
                    } else {
                        List(myData) { item in
                            healthDataRow(item: item)
                        }
                    }
                }

                Section(header: Text("Shared Data")) {
                    if sharedData.isEmpty {
                        Text("No shared data available.")
                            .foregroundColor(.gray)
                    } else {
                        List {
                            ForEach(sharedData, id: \.userName) { userData in
                                Section(header: Text(userData.userName)) {
                                    ForEach(userData.data) { item in
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
                fetchHealthDataQ() // 初回表示時にデータ取得
            }

            // エラーメッセージ
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            }
        }
    }

    // ヘルスデータの行ビュー
    private func healthDataRow(item: HealthDataItem) -> some View {
        VStack(alignment: .leading) {
            let typeDisplayName = dataTypeDisplayNames[item.type] ?? item.type
            let valueText = String(format: "%.2f", item.value)
            Text("Type: \(typeDisplayName)")
            Text("Value: \(valueText)")
            Text("Date: \(item.date, formatter: dateFormatter)")
        }
    }

    private func fetchHealthDataQ() {
        // 現在のユーザーIDを取得
        guard let userID = Auth.auth().currentUser?.uid else {
            print("Error: No authenticated user.")
            return
        }

        // Firestoreリファレンスを作成
        let healthDataRef = Firestore.firestore()
            .collection("users")
            .document(userID)
            .collection("healthData")
            .document("stepCount")
            .collection("data")

        // Firestoreからデータを取得
        healthDataRef.getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching health data: \(error.localizedDescription)")
            } else {
                print("Successfully fetched health data")
                if let documents = snapshot?.documents {
                    for document in documents {
                        print("Document ID: \(document.documentID), Data: \(document.data())")
                    }
                } else {
                    print("No documents found")
                }
            }
        }
    }

    private func fetchData() {
        fetchMyData()
        fetchSharedData()
    }

    private func fetchMyData() {
        firestoreManager.fetchMyHealthData { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    print("Fetched My Data: \(data)")
                    print("Fetching MyData for userID: \(userID)")
                    self.myData = data
                case .failure(let error):
                    self.errorMessage = "Failed to fetch my data: \(error.localizedDescription)"
                    print("Error fetching MyData: \(error.localizedDescription)")
                }
            }
        }
    }

    private func fetchSharedData() {
        firestoreManager.fetchSharedHealthData(for: userID, groupID: selectedGroup) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    self.sharedData = data.map { (key, value) in
                        (userName: key, data: value)
                    }
                case .failure(let error):
                    self.errorMessage = "Failed to fetch shared data: \(error.localizedDescription)"
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

