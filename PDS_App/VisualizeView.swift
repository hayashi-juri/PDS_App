//
//  DataVisualize.swift
//  PDS_App
//
//  Created by Juri Hayashi on 2025/01/10.
//

import SwiftUI
import Charts


struct VisualizeView: View {
    let userID: String

    @ObservedObject var firestoreManager: FirestoreManager
    @ObservedObject var healthKitManager: HealthKitManager
    @State private var showGraph: Bool = false
    @State private var stepCountData: [HealthDataItem] = []
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea(edges: .all)
            
            VStack {
                Text("Your Progress")
                    .font(.title)
                    .padding()
                
                // Step Count データを取得するボタン
                Button("Fetch Step Count Data") {
                    if let userID = healthKitManager.userID {
                        fetchStepCountData(userID: userID, firestoreManager: firestoreManager){ data in stepCountData = data
                            showGraph = true
                        }
                    } else {
                        print("User ID is missing.")
                    }
                }
                .padding()
                
                // グラフ表示
                Button("Show Step Count Graph") {
                    showGraph = true
                }
                .padding()
                .disabled(stepCountData.isEmpty) // データがない場合は無効化
                
                // グラフの表示
                if showGraph {
                    if !stepCountData.isEmpty {
                        Chart(stepCountData) { data in
                            BarMark(
                                x: .value("Date", data.date, unit: .day),
                                y: .value("Steps", data.value)
                            )
                        }
                        .frame(height: 300)
                        .padding()
                    } else {
                        Text("No step count data available")
                            .foregroundColor(.gray)
                    }
                }
            }
            
            .onAppear {
                    fetchStepCountData(userID: userID, firestoreManager: firestoreManager) { data in
                        self.stepCountData = data
                        print("Fetched \(data.count) step count data points on appear.")
                    }
            }
            // firestoreManager.stepCountData の変更を監視
            .onChange(of: firestoreManager.stepCountData) {
                print("Step count data updated: \(firestoreManager.stepCountData)") // デバッグログ
                if !firestoreManager.stepCountData.isEmpty {
                    showGraph = true // データが更新されたらグラフを表示する
                }
            }
        }
    }
}

extension VisualizeView {
    func fetchStepCountData(userID: String, firestoreManager: FirestoreManager, completion: @escaping ([HealthDataItem]) -> Void) {
        firestoreManager.fetchStepCountDataFromSubcollection(userID: userID, dataType: "stepCount") { result in
            switch result {
            case .success(let data):
                print("Fetched \(data.count) step count data points.")
                completion(data)
            case .failure(let error):
                print("Error fetching step count data: \(error.localizedDescription)")
                completion([])
            }
        }
    }
}



