//
//  FirestoreManager.swift
//  PDS_App
//
//  Created by Juri Hayashi on 2025/01/07.
//

import FirebaseFirestore

class FirestoreManager {
    /*private var db: Firestore {
        guard let firestore = Firestore.firestore() as Firestore? else {
            fatalError("Firestore is not properly initialized")
        }
        return firestore
    }*/

    private let db = Firestore.firestore()

    /// グループ設定を保存
        func saveGroupSettings(groupID: String, settings: [String: Any], completion: @escaping (Result<Void, Error>) -> Void) {
            let docRef = db.collection("settings").document(groupID) // グループIDをドキュメントIDとして使用
            docRef.setData(settings) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        }

    /// グループ設定を取得
        func fetchGroupSettings(groupID: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
            let docRef = db.collection("settings").document(groupID)
            docRef.getDocument { document, error in
                if let error = error {
                    completion(.failure(error))
                } else if let document = document, document.exists {
                    completion(.success(document.data() ?? [:]))
                } else {
                    completion(.failure(NSError(domain: "", code: 404, userInfo: [NSLocalizedDescriptionKey: "Document not found"])))
                }
            }
        }
    
    /// FirestoreにHealthKitのデータを保存する
    func saveHealthData(data: [[String: Any]], userID: String, completion: @escaping (Result<Void, Error>) -> Void) {
            let batch = db.batch()
            let collectionRef = db.collection("users").document(userID).collection("healthData")

            for item in data {
                let docRef = collectionRef.document()
                batch.setData(item, forDocument: docRef)
            }

            batch.commit { error in
                completion(error == nil ? .success(()) : .failure(error!))
            }
        }
    /*func saveHealthData(data: [[String: Any]], completion: @escaping (Result<Void, Error>) -> Void) {
            let batch = db.batch()
            let collectionRef = db.collection("healthData")

            for item in data {
                let docRef = collectionRef.document()
                batch.setData(item, forDocument: docRef)
            }

            batch.commit { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        }*/

    /// Firestoreからヘルスデータを取得するメソッド
    func fetchHealthData(completion: @escaping ([HealthDataItem]) -> Void) {
        db.collection("healthData").getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching data: \(error.localizedDescription)")
                completion([])
                return
            }

            let data = snapshot?.documents.compactMap { document -> HealthDataItem? in
                guard
                    let type = document.data()["type"] as? String,
                    let value = document.data()["value"] as? Double,
                    let date = (document.data()["date"] as? Timestamp)?.dateValue()
                else {
                    return nil
                }

                return HealthDataItem(id: document.documentID, type: type, value: value, date: date)
            } ?? []

            completion(data)
        }
    }
}

struct HealthDataSetting: Identifiable {
    var id: String // データ項目ID（例: stepCount）
    var type: String // データ項目名（例: 歩数）
    var isShared: Bool // 共有設定
    var value: Double? // 実際のデータ値（任意）
    var date: Date? // データ取得日時（任意）
}

