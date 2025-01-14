//
//  FirestoreManager.swift
//  PDS_App
//
//  Created by Juri Hayashi on 2025/01/07.
/*
 グループごとの実名・匿名、データ削除期限、各ヘルスデータ項目に対しての共有の有無を設定し、Firestoreにドキュメントとして保存。
 Firestoreのセキュリティルールでドキュメントを参照できるようにする。
 */
//
import FirebaseFirestore

class FirestoreManager: ObservableObject {
    private lazy var db = Firestore.firestore()

    @Published var userSettings: [String: Any] = [:]
    @Published var healthDataItems: [HealthDataItem] = [] // ヘルスデータアイテムを保持
    @Published var stepCountData: [HealthDataItem] = []   // 歩数データ
    @Published var sharedData: [HealthDataItem] = [] // Firestoreから取得した共有データ


    func fetchHealthData(userID: String, completion: @escaping (Result<[HealthDataItem], Error>) -> Void) {
        let collectionRef = db.collection("users").document(userID).collection("healthData")
        print("Fetching data for custom user ID: \(userID)")

        collectionRef.getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
            } else {
                let data = snapshot?.documents.compactMap { document -> HealthDataItem? in
                    guard
                        let type = document.data()["type"] as? String,
                        let value = document.data()["value"] as? Double,
                        let timestamp = document.data()["date"] as? Timestamp
                    else {
                        return nil
                    }
                    return HealthDataItem(
                        id: document.documentID,
                        type: type,
                        value: value,
                        date: timestamp.dateValue()
                    )
                } ?? []
                completion(.success(data))
            }
        }
    }


    // 歩数データをサブコレクションから取得
    func fetchStepCountDataFromSubcollection(userID: String, dataType: String, completion: @escaping (Result<[HealthDataItem], Error>) -> Void) {
        let collectionRef = db.collection("users").document(userID).collection("healthData").document(dataType).collection("data")

        collectionRef.getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching \(dataType) data: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            guard let documents = snapshot?.documents else {
                print("No \(dataType) data found")
                completion(.success([]))
                return
            }

            let data = documents.compactMap { document -> HealthDataItem? in
                let data = document.data()
                guard
                    let type = data["type"] as? String,
                    let value = data["value"] as? Double,
                    let dateString = data["date"] as? String,
                    let date = ISO8601DateFormatter().date(from: dateString)
                else {
                    print("Invalid data format in document: \(document.documentID)")
                    return nil
                }

                return HealthDataItem(
                    id: document.documentID,
                    type: type,
                    value: value,
                    date: date
                )
            }

            completion(.success(data))
        }
    }

    // Firestoreから設定を取得
    func saveUserSettings(userID: String, groupID: String, isAnonymous: Bool, deletionDate: Date, healthDataSettings: [HealthDataSetting], userName: String?, completion: @escaping (Result<Void, Error>) -> Void) {
        let healthDataDict = healthDataSettings.reduce(into: [String: Bool]()) { dict, setting in
            dict[setting.id] = setting.isShared
        }

        var settings: [String: Any] = [
            "isAnonymous": isAnonymous,
            "deletionDate": ISO8601DateFormatter().string(from: deletionDate),
            "healthDataSettings": healthDataDict
        ]

        if let userName = userName, !userName.isEmpty {
            settings["userName"] = userName // ユーザーネームを保存
        }

        let docRef = db.collection("users").document(userID).collection("settings").document(groupID)
        docRef.setData(settings) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }

    // Firestoreに設定を保存
    func saveUserSettings(userID: String, groupID: String, settings: [String: Any], completion: @escaping (Result<Void, Error>) -> Void) {
        let docRef = db.collection("users").document(userID).collection("settings").document(groupID)
        docRef.setData(settings) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }


    // ヘルスデータを保存するメソッド
    func saveHealthDataByType(userID: String, healthData: [[String: Any]], completion: @escaping (Result<Void, Error>) -> Void) {
        let userRef = db.collection("users").document(userID).collection("healthData")
        let batch = db.batch()

        for data in healthData {
            guard let type = data["type"] as? String else {
                print("Invalid data: Missing 'type' field")
                continue
            }

            let dataRef = userRef.document(type).collection("data").document() // サブコレクションに保存
            batch.setData(data, forDocument: dataRef)
        }

        batch.commit { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }

    // グループ設定を取得
    func fetchGroupSettings(userID: String, completion: @escaping (Result<[String: [String: Bool]], Error>) -> Void) {
        let collectionRef = db.collection("users").document(userID).collection("settings")

        collectionRef.getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
            } else {
                guard let documents = snapshot?.documents else {
                    completion(.success([:]))
                    return
                }

                var groupSettings: [String: [String: Bool]] = [:]
                for document in documents {
                    if let settings = document.data()["healthDataSettings"] as? [String: Bool] {
                        groupSettings[document.documentID] = settings
                    }
                }
                completion(.success(groupSettings))
            }
        }
    }

    // firestoreから共有ヘルスデータを取得
    func fetchSharedHealthData(userID: String, completion: @escaping (Result<[HealthDataItem], Error>) -> Void) {
        let collectionRef = db.collection("users").document(userID).collection("healthData")

        collectionRef.getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching shared health data for user \(userID): \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            guard let documents = snapshot?.documents else {
                print("No documents found for user: \(userID)")
                completion(.success([]))
                return
            }

            let data = documents.compactMap { document -> HealthDataItem? in
                print("Processing document: \(document.documentID), content: \(document.data())")
                guard
                    let type = document.data()["type"] as? String,
                    let value = document.data()["value"] as? Double,
                    let timestamp = document.data()["date"] as? Timestamp
                else {
                    return nil
                }
                return HealthDataItem(
                    id: document.documentID,
                    type: type,
                    value: value,
                    date: timestamp.dateValue()
                )
            }

            print("Fetched data: \(data)")
            completion(.success(data))
        }
    }

    // activeEnergyBurned を取得する関数
    func fetchActiveEnergyBurned(userID: String, completion: @escaping (Result<[HealthDataItem], Error>) -> Void) {
        fetchHealthDataByType(userID: userID, dataType: "activeEnergyBurned", completion: completion)
    }

    // stepCount を取得する関数
    func fetchStepCount(userID: String, completion: @escaping (Result<[HealthDataItem], Error>) -> Void) {
        fetchHealthDataByType(userID: userID, dataType: "stepCount", completion: completion)
    }

    // distanceWalkingRunning を取得する関数
    func fetchDistanceWalkingRunning(userID: String, completion: @escaping (Result<[HealthDataItem], Error>) -> Void) {
        fetchHealthDataByType(userID: userID, dataType: "distanceWalkingRunning", completion: completion)
    }

    // basalEnergyBurned を取得する関数
    func fetchBasalEnergyBurned(userID: String, completion: @escaping (Result<[HealthDataItem], Error>) -> Void) {
        fetchHealthDataByType(userID: userID, dataType: "basalEnergyBurned", completion: completion)
    }

    // 共通のヘルスデータ取得処理
    private func fetchHealthDataByType(userID: String, dataType: String, completion: @escaping (Result<[HealthDataItem], Error>) -> Void) {
        let collectionRef = db.collection("users").document(userID).collection("healthData").document(dataType).collection("data")

        collectionRef.getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
            } else {
                let data = snapshot?.documents.compactMap { document -> HealthDataItem? in
                    guard
                        let value = document.data()["value"] as? Double,
                        let dateString = document.data()["date"] as? String,
                        let date = ISO8601DateFormatter().date(from: dateString)
                    else {
                        return nil
                    }
                    return HealthDataItem(
                        id: document.documentID,
                        type: dataType,
                        value: value,
                        date: date
                    )
                } ?? []
                completion(.success(data))
            }
        }
    }

    func fetchHealthDataBasedOnSettings(userID: String, settings: [String: Bool], completion: @escaping (Result<[HealthDataItem], Error>) -> Void) {
        var resultData: [HealthDataItem] = []
        var fetchCount = 0
        let enabledDataTypes = settings.filter { $0.value }.keys

        for dataType in enabledDataTypes {
            fetchHealthDataByType(userID: userID, dataType: dataType) { result in
                fetchCount += 1

                switch result {
                case .success(let data):
                    resultData.append(contentsOf: data)
                case .failure(let error):
                    print("Error fetching \(dataType): \(error.localizedDescription)")
                }

                // すべてのデータ取得処理が完了したら completion を呼び出す
                if fetchCount == enabledDataTypes.count {
                    completion(.success(resultData))
                }
            }
        }

        // 有効なデータタイプがない場合は空の結果を返す
        if enabledDataTypes.isEmpty {
            completion(.success([]))
        }
    }

    func fetchFilteredHealthData(userID: String, groupID: String, completion: @escaping (Result<[HealthDataItem], Error>) -> Void) {
        let docRef = db.collection("users").document(userID).collection("settings").document(groupID)

        docRef.getDocument { snapshot, error in
            if let error = error {
                completion(.failure(error))
            } else if let data = snapshot?.data(),
                      let healthDataSettings = data["healthDataSettings"] as? [String: Bool] {
                self.fetchHealthDataBasedOnSettings(userID: userID, settings: healthDataSettings, completion: completion)
            } else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No settings found."])))
            }
        }
    }


}

struct HealthDataItem: Identifiable, Codable, Equatable {
    var id: String
    var type: String
    var value: Double
    var date: Date

    static func == (lhs: HealthDataItem, rhs: HealthDataItem) -> Bool {
        return lhs.id == rhs.id &&
               lhs.type == rhs.type &&
               lhs.value == rhs.value &&
               lhs.date == rhs.date
    }
}


