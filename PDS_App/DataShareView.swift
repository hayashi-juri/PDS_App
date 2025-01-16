//
//  DataShareView.swift
//  PDS_App
//
//  Created by Juri Hayashi on 2025/01/10.
//

import SwiftUI
import Charts

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
    
    let dataTypeUnits: [String: String] = [
        "stepCount": "steps",
        "distanceWalkingRunning": "km",
        "basalEnergyBurned": "kcal",
        "activeEnergyBurned": "kcal"
    ]
    
    /// グループタブの順序を固定
    private var orderedGroupKeys: [String] {
        let predefinedOrder = ["Family", "Friends", "Public"]
        let sortedKeys = predefinedOrder.filter { Array(groupSettings.keys).contains($0) }
        return sortedKeys
    }
    
    var body: some View {
        VStack {
            Text("Data Sharing")
                .font(.title)
                .padding()
            
            Picker("Select Group", selection: $selectedGroup) {
                ForEach(orderedGroupKeys, id: \.self) { group in
                    Text(group).tag(group)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            .onChange(of: selectedGroup) {
                filterSharedData()
            }
            
            Form {
                Section(header: Text("Total Values by Type")) {
                    if groupedDataTotals.isEmpty {
                        Text("No data available for this group.")
                            .foregroundColor(.gray)
                    } else {
                        // データタイプごとの合計値を表示
                        ForEach(Array(groupedDataTotals.keys), id: \.self) { (key: String) in
                            HStack {
                                Text(dataTypeDisplayNames[key] ?? key)
                                Spacer()
                                Text(formattedNumberWithUnit(groupedDataTotals[key] ?? 0, type: key))
                                
                            }
                        }
                    }
                }
                Section(header: Text("Details")) {
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
    
    /// 数値をカンマ区切りにフォーマットし、小数点以下を切り捨て
    private func formattedNumberWithUnit(_ value: Double, type: String) -> String {
        let truncatedValue = floor(value) // 小数点以下を切り捨て
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let formattedNumber = formatter.string(from: NSNumber(value: truncatedValue)) ?? String(Int(truncatedValue))
        let unit: String = dataTypeUnits[type] ?? "" // 単位を取得（存在しない場合は空文字）
        return "\(formattedNumber) \(unit)"
    }
    
    /// 各データタイプの合計値を計算するプロパティ
    private var groupedDataTotals: [String: Double] {
        var totals: [String: Double] = [:]
        for item in sharedData {
            totals[item.type, default: 0] += item.value
        }
        return totals
    }
    
}
