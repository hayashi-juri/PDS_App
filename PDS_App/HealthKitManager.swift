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

class HealthKitManager: ObservableObject {
    private let healthStore = HKHealthStore()
    @Published var isAuthorized: Bool = false
    @Published var userID: String? = nil // 認証後に生成されるuserID
    
    /// HealthKitの認証とデータ取得を一括で処理
    func authorizeAndFetchHealthData(firestoreManager: FirestoreManager, completion: @escaping (Bool, Error?) -> Void) {
        requestAuthorization { [weak self] success, error in
            guard let self = self else { return }
            if success {
                self.isAuthorized = true
                print("HealthKit Authority Success")
                // 認証成功時にuserIDを生成
                self.userID = UserManager.shared.getOrCreateUserID()
                guard let userID = self.userID else {
                    print("User ID generation failed")
                    completion(false, nil)
                    return
                }

                if let userID = self.userID {
                    print("Authorisation Success: User ID \(userID)")
                } else {
                    print("error: User ID could not generated. Trying again.")
                    self.userID = UserManager.shared.getOrCreateUserID()
                    if let newUserID = self.userID {
                        print("Successfully generated: User ID \(newUserID)")
                    } else {
                        print("Regeneration failed: User ID could not generated.")
                        completion(false, NSError(domain: "HealthKitManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not generate User ID"]))
                        return
                    }
                }

                // データ取得と保存
                self.fetchHealthDataAndSave(to: firestoreManager, userID: userID) { fetchError in
                    if let fetchError = fetchError {
                        print("Failed to fetch data from HealthKit: \(fetchError.localizedDescription)")
                    } else {
                        print("HealthKit data fetched successfully and saved at Firestore")
                    }
                    completion(true, fetchError)
                }
            } else {
                print("HealthKit Authorization failed: \(error?.localizedDescription ?? "Unknown error")")
                completion(false, error)
            }
        }
    }
    
    /// HealthKitの認証
    private func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        let readTypes: Set<HKObjectType> = [
            HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
        ]
        
        healthStore.requestAuthorization(toShare: nil, read: readTypes) { success, error in
            DispatchQueue.main.async {
                completion(success, error)
            }
        }
    }
    
    /// データ取得とFirestoreへの保存
    func fetchHealthDataAndSave(to firestoreManager: FirestoreManager, userID: String, completion: @escaping (Error?) -> Void) {
        let dataTypes: [HKSampleType] = [
            HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
        ]
        
        var allData: [[String: Any]] = []
        let dispatchGroup = DispatchGroup()
        
        for type in dataTypes {
            dispatchGroup.enter()
            fetchData(for: type, startDate: Date().addingTimeInterval(-3 * 24 * 60 * 60)) { result in
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
            guard let userID = self.userID else {
                print("error: User ID does not exist.")
                completion(NSError(domain: "HealthKitManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "User ID cannot find."]))
                return
            }
            
            firestoreManager.saveUserSettings(
                userID: userID,
                groupID: "default",
                isAnonymous: false,
                deletionDate: Date(),
                healthDataSettings: [],
                userName: "SampleUser"
            ) { result in
                switch result {
                case .success:
                    print("Data saved successfully!")
                    completion(nil)
                case .failure(let error):
                    print("Data saving failed: \(error.localizedDescription)")
                    completion(error)
                }
            }
        }
    }
    
    /// HealthKitデータを取得
    private func fetchData(for sampleType: HKSampleType, startDate: Date, completion: @escaping (Result<[[String: Any]], Error>) -> Void) {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictEndDate)

        let query = HKSampleQuery(sampleType: sampleType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
            guard error == nil else {
                completion(.failure(error!))
                return
            }

            var resultData: [[String: Any]] = []
            if let quantitySamples = samples as? [HKQuantitySample] {
                for sample in quantitySamples {
                    let unit: HKUnit
                    switch sampleType {
                    case HKQuantityType.quantityType(forIdentifier: .stepCount):
                        unit = .count()
                    case HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning):
                        unit = .meter()
                    case HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned),
                         HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned):
                        unit = .kilocalorie()
                    default:
                        unit = .count() // デフォルトの単位
                    }

                    resultData.append([
                        "type": sampleType.identifier,
                        "value": sample.quantity.doubleValue(for: unit),
                        "date": sample.startDate
                    ])
                }
            }
            completion(.success(resultData))
        }
        healthStore.execute(query)
    }
}
