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
                    fetchStepCountData()
                }
                .padding()

                // グラフ表示ボタン
                Button("Show Step Count Graph") {
                    showGraph = true
                }
                .padding()
                .disabled(stepCountData.isEmpty)

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
                //fetchStepCountData()
                print("visual view called")
            }
        }
    }

    private func fetchStepCountData() {
        print("Fetching step count data...")
        firestoreManager.fetchStepCountDataFromSubcollection(userID: userID, dataType: "stepCount") { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    if data.isEmpty {
                        print("No step count data available.")
                    } else {
                        print("Fetched \(data.count) step count data points.")
                    }
                    self.stepCountData = data
                case .failure(let error):
                    print("Error fetching step count data: \(error.localizedDescription)")
                    self.stepCountData = []
                }
            }
        }
    }
}


