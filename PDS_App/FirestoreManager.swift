//
//  FirestoreManager.swift
//  PDS_App
//
//  Created by Juri Hayashi on 2025/01/07.
//


import FirebaseFirestore
import Foundation

class FirestoreManager {
    private let db = Firestore.firestore()

    /// Firestoreにテストデータを保存する関数
    func saveTestData(completion: @escaping (Result<Void, Error>) -> Void) {
        let testData: [String: Any] = [
            "name": "Test Agreement",
            "context": [
                "agreementInitiator": "User123",
                "agreementResponder": "TestService",
                "expirationTime": "2025-12-31T23:59:59Z"
            ],
            "terms": [
                "serviceDescriptionTerm": [
                    "dataType": "HealthKit",
                    "sharingScope": [
                        "groupID": "GroupA",
                        "anonymity": "Anonymous"
                    ]
                ]
            ]
        ]

        db.collection("test_agreements").addDocument(data: testData) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }

    /// Firestoreからテストデータを取得する関数
    func fetchTestData(completion: @escaping (Result<[[String: Any]], Error>) -> Void) {
        db.collection("test_agreements").getDocuments { (snapshot, error) in
            if let error = error {
                completion(.failure(error))
            } else if let snapshot = snapshot {
                let documents = snapshot.documents.map { $0.data() }
                completion(.success(documents))
            }
        }
    }
}
