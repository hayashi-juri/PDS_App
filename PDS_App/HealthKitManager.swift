//
//  HealthKitManager.swift
//  PDS_App
//
//  Created by Juri Hayashi on 2025/01/07.
//

import HealthKit
import Foundation

class HealthKitManager: ObservableObject {
    var healthStore: HKHealthStore?
    @Published var isAuthorized: Bool = false // 認証状態を管理するプロパティ

    init() {
        if checkHKAvailability() {
            // 初期化時に認証状態を確認
            requestAuthorization { success, _ in
                DispatchQueue.main.async {
                    self.isAuthorized = success
                }
            }
        }
    }

    /// HealthKit が利用可能か確認
    /// - Returns: 利用可能なら `true`
    private func checkHKAvailability() -> Bool {
        if HKHealthStore.isHealthDataAvailable() {
            healthStore = HKHealthStore()
            return true
        } else {
            print("HealthKit is not available on this device")
            return false
        }
    }

    /// HealthKit の認証をリクエスト
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        guard let healthStore = healthStore else {
            completion(false, nil)
            return
        }

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

    
}

