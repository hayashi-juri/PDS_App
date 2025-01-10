//
//  FirestoreManager.swift
//  PDS_App
//
//  Created by Juri Hayashi on 2025/01/07.
//

import FirebaseFirestore

class FirestoreManager {
    private var db: Firestore {
        guard let firestore = Firestore.firestore() as Firestore? else {
            fatalError("Firestore is not properly initialized")
        }
        return firestore
    }

    /// Firestoreに設定を保存するメソッド
        func saveSettings(settings: [String: Any], completion: @escaping (Result<Void, Error>) -> Void) {
            let docRef = db.collection("settings").document("sharedSettings") // 保存先のドキュメントを指定
            docRef.setData(settings) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        }
    /// FirestoreにHealthKitのデータを保存する
    func saveHealthData(data: [[String: Any]], completion: @escaping (Result<Void, Error>) -> Void) {
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
        }

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

struct HealthDataItem: Identifiable {
    let id: String
    let type: String
    let value: Double
    let date: Date
}
