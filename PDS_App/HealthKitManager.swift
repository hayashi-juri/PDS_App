//
//  HealthKitManager.swift
//  PDS_App
//
//  Created by Juri Hayashi on 2025/01/07.
//

import HealthKit
import Foundation

class HealthKitManager: ObservableObject {
    private let healthStore = HKHealthStore()
    @Published var isAuthorized: Bool = false

    // 承認
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        let readTypes: Set<HKObjectType> = [
            HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .appleMoveTime)!,
            HKQuantityType.quantityType(forIdentifier: .appleStandTime)!,
            HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
        ]

        healthStore.requestAuthorization(toShare: nil, read: readTypes) { success, error in
            DispatchQueue.main.async {
                self.isAuthorized = success
                completion(success, error)
            }
        }
    }

    /// HealthKitからデータを取得してFirestoreに保存
        func fetchHealthDataAndSave(to firestoreManager: FirestoreManager, completion: @escaping (Error?) -> Void) {
            // データ取得対象
            let dataTypes: [HKSampleType] = [
                HKQuantityType.quantityType(forIdentifier: .stepCount)!,
                HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
                HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned)!,
                HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
                HKQuantityType.quantityType(forIdentifier: .appleMoveTime)!,
                HKQuantityType.quantityType(forIdentifier: .appleStandTime)!,
                HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
            ]

            var allData: [[String: Any]] = []

            let dispatchGroup = DispatchGroup()

            for type in dataTypes {
                dispatchGroup.enter()
                fetchData(for: type) { result in
                    switch result {
                    case .success(let data):
                        allData.append(contentsOf: data)
                    case .failure(let error):
                        print("Error fetching data for \(type.identifier): \(error.localizedDescription)")
                    }
                    dispatchGroup.leave()
                }
            }

            dispatchGroup.notify(queue: .main) {
                firestoreManager.saveHealthData(data: allData) { result in
                    switch result {
                    case .success:
                        completion(nil)
                    case .failure(let error):
                        completion(error)
                    }
                }
            }
        }

        /// 個別のHealthKitデータを取得
        private func fetchData(for sampleType: HKSampleType, completion: @escaping (Result<[[String: Any]], Error>) -> Void) {
            let predicate = HKQuery.predicateForSamples(withStart: Date().addingTimeInterval(-7 * 24 * 60 * 60), // 過去7日間
                                                        end: Date(),
                                                        options: .strictEndDate)

            let query = HKSampleQuery(sampleType: sampleType,
                                      predicate: predicate,
                                      limit: HKObjectQueryNoLimit,
                                      sortDescriptors: nil) { query, samples, error in
                guard error == nil else {
                    completion(.failure(error!))
                    return
                }

                var resultData: [[String: Any]] = []

                if let quantitySamples = samples as? [HKQuantitySample] {
                    for sample in quantitySamples {
                        let value = sample.quantity.doubleValue(for: HKUnit.count())
                        let data: [String: Any] = [
                            "type": sampleType.identifier,
                            "value": value,
                            "date": sample.startDate
                        ]
                        resultData.append(data)
                    }
                }

                if let categorySamples = samples as? [HKCategorySample] {
                    for sample in categorySamples {
                        let data: [String: Any] = [
                            "type": sampleType.identifier,
                            "value": sample.value,
                            "date": sample.startDate
                        ]
                        resultData.append(data)
                    }
                }

                completion(.success(resultData))
            }

            healthStore.execute(query)
        }
}
