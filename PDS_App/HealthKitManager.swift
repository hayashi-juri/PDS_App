//
//  HealthKitManager.swift
//  PDS_App
//
//  Created by Juri Hayashi on 2025/01/07.
/*
 HealthKit認証機能
 HealthKit認証後、３日分のデータを取得
 HealthKitからデータを取得し、Firestoreにデータをコピーし保存する処理。
 HealthKitデータを１日３回自動更新

 */
//
import HealthKit
import Foundation
import FirebaseFirestore

class HealthKitManager: ObservableObject {
    private let healthStore = HKHealthStore()
    @Published var isAuthorized: Bool = false
    @Published var userID: String?

    private let authManager: AuthManager

    init(authManager: AuthManager) {
        self.authManager = authManager
        self.userID = authManager.userID
    }

    // 認証
    func authorizeHK (completion: @escaping (Bool, Error?) -> Void) {
        let readTypes: Set<HKObjectType> = [
            HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
        ]

        healthStore.requestAuthorization(toShare: nil, read: readTypes) { success, error in
            let workItem = DispatchWorkItem {
                self.isAuthorized = success
                if success {
                    self.userID = self.authManager.userID
                }
                completion(success, error)
            }
            DispatchQueue.main.async(execute: workItem)
        }
    }

    // ヘルスデータを Firestore に保存
    func fetchHealthData(to firestoreManager: FirestoreManager, completion: @escaping (Error?) -> Void) {
        guard let userID = self.userID else {
            completion(NSError(domain: "HealthKitManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "User ID is missing."]))
            return
        }

        let dataTypes: [HKSampleType] = [
            HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]

        var allData: [[String: Any]] = []
        let dispatchGroup = DispatchGroup()

        for type in dataTypes {
            dispatchGroup.enter()
            fetchData(for: type, startDate: Date().addingTimeInterval(-2 * 24 * 60 * 60)) { result in
                switch result {
                case .success(let data):
                    allData.append(contentsOf: data)
                case .failure(let error):
                    print("Error fetching data for \(type.identifier): \(error.localizedDescription)")
                }
                dispatchGroup.leave()
            }
        }

        // データ取得の最後にnotifyメソッドを正しく記述
        let workItem = DispatchWorkItem {
            firestoreManager.saveHealthDataByType(userID: userID, healthData: allData) { result in
                switch result {
                case .success:
                    print("Health data saved successfully.")
                    completion(nil)
                case .failure(let error):
                    print("Failed to save health data: \(error.localizedDescription)")
                    completion(error)
                }
            }
        }
        dispatchGroup.notify(queue: DispatchQueue.main) {
            workItem.perform() // DispatchWorkItemを実行
        }

    }

    private func fetchData(for sampleType: HKSampleType, startDate: Date, completion: @escaping (Result<[[String: Any]], Error>) -> Void) {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictEndDate)

        let query = HKSampleQuery(sampleType: sampleType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
            if let error = error {
                print("Error fetching data for \(sampleType.identifier): \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            var resultData: [[String: Any]] = []
            if let quantitySamples = samples as? [HKQuantitySample] {
                for sample in quantitySamples {
                    guard let (unit, type) = self.unitAndType(for: sampleType) else {
                        print("Unsupported sample type: \(sampleType.identifier)")
                        continue
                    }

                    let data: [String: Any] = [
                        "type": type,
                        "value": sample.quantity.doubleValue(for: unit),
                        "date": ISO8601DateFormatter().string(from: sample.startDate)
                    ]

                    print("Fetched data: \(data)") // デバッグ用ログ
                    resultData.append(data)
                }
            }

            completion(.success(resultData))
        }

        healthStore.execute(query)
    }

    private func unitAndType(for sampleType: HKSampleType) -> (HKUnit, String)? {
        switch sampleType {
        case HKQuantityType.quantityType(forIdentifier: .stepCount):
            return (.count(), "stepCount")
        case HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning):
            return (.meter(), "distanceWalkingRunning")
        case HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned):
            return (.kilocalorie(), "basalEnergyBurned")
        case HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned):
            return (.kilocalorie(), "activeEnergyBurned")
        default:
            return nil
        }
    }
}
