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

    // ヘルスデータをFirestoreから取得
    func fetchHealthData(userID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let collectionRef = db.collection("users").document(userID).collection("healthData")
        collectionRef.getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
            } else {
                DispatchQueue.main.async {
                    self.healthDataItems = snapshot?.documents.compactMap { document in
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
                    completion(.success(()))
                }
            }
        }
    }

    /*func fetchStepCountData(userID: String) {
     db.collection("users").document(userID).collection("healthData")
     .whereField("type", isEqualTo: "stepCount")
     .getDocuments { snapshot, error in
     if let error = error {
     print("Error fetching step count data: \(error.localizedDescription)")
     return
     }
     self.stepCountData = snapshot?.documents.compactMap { document -> HealthDataItem? in
     try? document.data(as: HealthDataItem.self)
     } ?? []
     print("Fetched \(self.stepCountData.count) step count data points")
     }
     }*/

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
                // Debug log for document content
                print("Processing document: \(document.documentID), content: \(data)")

                guard
                    let type = data["type"] as? String,
                    let value = data["value"] as? Double,
                    let dateString = data["date"] as? String,
                    let date = ISO8601DateFormatter().date(from: dateString)
                else {
                    print("Invalid data format in document: \(document.documentID), content: \(data)")
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

    }

struct HealthDataItem: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
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

