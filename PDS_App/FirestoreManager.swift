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
/*import FirebaseFirestore

class FirestoreManager: ObservableObject {
    private lazy var db = Firestore.firestore()
    
    private let authManager: AuthManager

    // 初期化時に Firestore と AuthManager を注入
    init(db: Firestore = Firestore.firestore(), authManager: AuthManager) {
        self.db = db
        self.authManager = authManager
    }

    // 公開された userID プロパティ
    var userID: String? {
            return authManager.userID
    }

    @Published var userSettings: [String: Any] = [:]
    @Published var healthDataItems: [HealthDataItem] = [] // ヘルスデータアイテムを保持
    @Published var stepCountData: [HealthDataItem] = []   // 歩数データ
    @Published var sharedData: [HealthDataItem] = [] // Firestoreから取得した共有データ
    
    // HealthData の取得
    func fetchHealthData(userID: String, completion: @escaping (Result<[HealthDataItem], Error>) -> Void) {
        guard let userID = authManager.userID else {
            completion(.failure(NSError(domain: "FirestoreManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "User ID is missing."])))
            return
        }

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
    
    // Firestoreに設定を保存
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
    
    // 設定に基づいたデータを取ってくる
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
    
    // ヘルスデータをフィルタリングする
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
}*/

//
//  FirestoreManager.swift
//  PDS_App
//
//  Created by Juri Hayashi on 2025/01/07.
//
import FirebaseFirestore
import FirebaseCore

class FirestoreManager: ObservableObject {
    private let db: Firestore
    private let authManager: AuthManager

    init(authManager: AuthManager) {
            guard let app = FirebaseApp.app() else {
                fatalError("FirebaseApp is not configured. Call FirebaseApp.configure() before initializing FirestoreManager.")
            }
            self.db = Firestore.firestore(app: app)
            self.authManager = authManager
        }

    // 公開された userID プロパティ
    var userID: String? {
        return authManager.userID
    }

    @Published var userSettings: [String: Any] = [:]
    @Published var healthDataItems: [HealthDataItem] = [] // ヘルスデータアイテムを保持 - ContentView
    @Published var stepCountData: [HealthDataItem] = []   // 歩数データ - VisualizeView
    @Published var myHealthData: [HealthDataItem] = []  // 自分のヘルスデータ - DataShareView
    @Published var sharedData: [HealthDataItem] = []      // 他のユーザーのデータ - DataShareView

// ヘルスデータを取得 - ContentView
 func fetchHealthDataFirstTime(userID: String, completion: @escaping (Result<[HealthDataItem], Error>) -> Void) {
     let collectionRef = db.collection("users").document(userID).collection("healthData")
     collectionRef.getDocuments { snapshot, error in
         if let error = error {
             completion(.failure(error))
             return
         }
         let data = snapshot?.documents.compactMap { HealthDataItem(document: $0) } ?? []
         completion(.success(data))
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

    // MARK: 自分のデータを取得
        func fetchMyHealthData(completion: @escaping (Result<[HealthDataItem], Error>) -> Void) {
            guard let userID = userID else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "User ID is missing."])))
                return
            }

            fetchAllHealthData(for: userID, completion: completion)
        }

    // MARK: 他のユーザーのデータを取得
    func fetchSharedHealthData(for userID: String, groupID: String, completion: @escaping (Result<[(userName: String, data: [HealthDataItem])], Error>) -> Void) {
        let group = DispatchGroup()
        var results: [(userName: String, data: [HealthDataItem])] = []
        var fetchError: Error?

        db.collection("users")
            .whereField("groups", arrayContains: groupID)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let documents = snapshot?.documents else {
                    completion(.success([]))
                    return
                }

                for document in documents {
                    group.enter()
                    let userName = document.data()["name"] as? String ?? "Unknown"
                    let healthDataRef = document.reference.collection("healthData")

                    healthDataRef.getDocuments { healthSnapshot, healthError in
                        if let healthError = healthError {
                            fetchError = healthError
                        } else {
                            let data = healthSnapshot?.documents.compactMap { HealthDataItem(document: $0) } ?? []
                            results.append((userName: userName, data: data))
                        }
                        group.leave()
                    }
                }

                group.notify(queue: .main) {
                    if let fetchError = fetchError {
                        completion(.failure(fetchError))
                    } else {
                        completion(.success(results))
                    }
                }
            }
    }

    // MARK: 全てのデータを取得（設定を参照せずに）
        private func fetchAllHealthData(for userID: String, completion: @escaping (Result<[HealthDataItem], Error>) -> Void) {
            let collectionRef = db.collection("users").document(userID).collection("healthData")
            collectionRef.getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                let data = snapshot?.documents.compactMap { HealthDataItem(document: $0) } ?? []
                completion(.success(data))
            }
        }

    // MARK: 他のユーザーの設定を取得
        private func fetchSettings(for userID: String, groupID: String, completion: @escaping (Result<[String: Bool], Error>) -> Void) {
            let settingsRef = db.collection("users").document(userID).collection("settings").document(groupID)
            settingsRef.getDocument { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                } else if let data = snapshot?.data(),
                          let healthDataSettings = data["healthDataSettings"] as? [String: Bool] {
                    completion(.success(healthDataSettings))
                } else {
                    // 空の設定またはドキュメントがない場合、すべて公開とみなす
                    completion(.success([:]))
                }
            }
        }

    // 設定に基づいたデータを取得
    func fetchHealthDataBasedOnSettings(userID: String, settings: [String: Bool], completion: @escaping (Result<[HealthDataItem], Error>) -> Void) {
        var resultData: [HealthDataItem] = []
        let enabledDataTypes = settings.filter { $0.value }.keys
        let dispatchGroup = DispatchGroup()

        for dataType in enabledDataTypes {
            dispatchGroup.enter()
            fetchHealthDataByType(userID: userID, dataType: dataType) { result in
                switch result {
                case .success(let data):
                    resultData.append(contentsOf: data)
                case .failure(let error):
                    print("Error fetching data based on settings.\(dataType): \(error.localizedDescription)")
                }
                dispatchGroup.leave()
            }
        }

        dispatchGroup.notify(queue: .main) {
            completion(.success(resultData))
        }
    }

    // ヘルスデータをデータタイプごとに取得
    private func fetchHealthDataByType(userID: String, dataType: String, completion: @escaping (Result<[HealthDataItem], Error>) -> Void) {
        let collectionRef = db.collection("users").document(userID).collection("healthData").document(dataType).collection("data")
        collectionRef.getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            let data = snapshot?.documents.compactMap {
                HealthDataItem(document: $0) } ?? []
                        completion(.success(data))
        }
    }

    // ユーザー設定の保存
    func saveUserSettings(
        userID: String,
        groupID: String,
        isAnonymous: Bool,
        deletionDate: Date,
        healthDataSettings: [HealthDataSetting],
        userName: String?,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        // データ整形
        let healthDataDict = healthDataSettings.reduce(into: [String: Bool]()) { dict, setting in
            dict[setting.id] = setting.isShared
        }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        let formattedDate = isoFormatter.string(from: deletionDate)

        var settings: [String: Any] = [
            "isAnonymous": isAnonymous,
            "deletionDate": formattedDate,
            "healthDataSettings": healthDataDict
        ]

        if let userName = userName, !userName.isEmpty {
            settings["userName"] = userName
        }

        print("Prepared settings data: \(settings)")

        // Firestore書き込み前にuserIDを確認
        guard let userID = self.userID else {
            print("Error: User ID is nil. Cannot save settings.")
            return
        }
        print("User ID: \(userID)")

        // Firestore書き込み
        let docRef = db.collection("users").document(userID).collection("settings").document(groupID)
        docRef.setData(settings) { error in
            if let error = error {
                print("Failed to save settings to Firestore: \(error.localizedDescription)")
                completion(.failure(error))
            } else {
                print("Settings saved successfully to Firestore.")
                completion(.success(()))
            }
        }
    }

    // 歩数データをサブコレクションから取得
    func fetchStepCountDataFromSubcollection(userID: String, dataType: String, completion: @escaping (Result<[HealthDataItem], Error>) -> Void) {
        let collectionRef = db.collection("users").document(userID).collection("healthData").document(dataType).collection("data")

        collectionRef.getDocuments ( completion: {(snapshot, error) in
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

            let data = documents.compactMap {
                document -> HealthDataItem? in
                return HealthDataItem(document: document)
            }

            completion(.success(data))
        })
    }

}

struct HealthDataItem: Identifiable, Equatable {
    let id: String
    let type: String
    let value: Double
    let date: Date

    init?(document: QueryDocumentSnapshot) {
        let data = document.data()
        guard
            let type = data["type"] as? String,
            let value = data["value"] as? Double,
            let timestamp = data["timestamp"] as? Timestamp
        else {
            return nil
        }

        self.id = document.documentID
        self.type = type
        self.value = value
        self.date = timestamp.dateValue()
    }

    // Equatable
    static func == (lhs: HealthDataItem, rhs: HealthDataItem) -> Bool {
        return lhs.id == rhs.id &&
        lhs.type == rhs.type &&
        lhs.value == rhs.value &&
        lhs.date == rhs.date
    }
}
