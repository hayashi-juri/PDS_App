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
    
    // Firestoreから設定を取得
    func saveUserSettings(userID: String, groupID: String, isAnonymous: Bool, deletionDate: Date, healthDataSettings: [HealthDataSetting], completion: @escaping (Result<Void, Error>) -> Void) {
        let healthDataDict = healthDataSettings.reduce(into: [String: Bool]()) { dict, setting in
            dict[setting.id] = setting.isShared
        }
        
        let settings: [String: Any] = [
            "isAnonymous": isAnonymous,
            "deletionDate": ISO8601DateFormatter().string(from: deletionDate),
            "healthDataSettings": healthDataDict
        ]
        
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
}

struct HealthDataItem: Identifiable {
    var id: String
    var type: String
    var value: Double
    var date: Date
}
