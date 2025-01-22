//
//  FirestoreManager.swift
//  PDS_App
//
//  Created by Juri Hayashi on 2025/01/07.
//
import FirebaseFirestore
import FirebaseCore
import ZIPFoundation

// smaple@example.com

class FirestoreManager: ObservableObject {
    let db: Firestore
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
    //@Published var sharedData: [HealthDataItem] = []      // 他のユーザーのデータ - DataShareView
    @Published var sharedOthersData: [(userName: String, data: [HealthDataItem])] = []
    @Published var sharedMyData: [(userName: String, data: [HealthDataItem])] = []
    @Published var exportProgress: Double = 0.0 // 進捗を通知
    @Published var exportedFileURL: URL? = nil // 完了したファイルのURL
    @Published var exportError: Error? = nil // エラー通知


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

    //fetchMyhealthdata で直近の１日のデータのみ取得し、データの値の合計を計算したい

    // MARK: 自分のデータを取得
    func fetchMyHealthData(for currentUserID: String, groupID: String, completion: @escaping (Result<[(userName: String, totalData: [String: Double])], Error>) -> Void) {
        let group = DispatchGroup()
        var results: [(userName: String, totalData: [String: Double])] = []
        var fetchError: Error?

        let now = Date() // デフォルトでUTC
        let twentyFourHoursAgo = Calendar.current.date(byAdding: .hour, value: -24, to: now)!

        print("Starting fetchMyHealthData with settings filtering for user: \(currentUserID)")
        print("❤️ Fetching data from: \(twentyFourHoursAgo) to: \(now)")

        self.db.collection("users")
            .whereField("role", isEqualTo: "me")
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    print("❌ Error fetching Admin users: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }

                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    print("ℹ️ No Admin users found")
                    completion(.success([]))
                    return
                }

                print("📝 Found \(documents.count) users in group")
                let dataTypes = ["stepCount", "activeEnergyBurned", "distanceWalkingRunning", "basalEnergyBurned"]

                for document in documents {
                    group.enter()

                    guard let userName = document.data()["name"] as? String else {
                        print("❌ Missing name for user document: \(document.documentID)")
                        group.leave()
                        continue
                    }

                    let otherUserID = document.documentID
                    print("🔍 Processing data for user: \(userName) (ID: \(otherUserID))")

                    // まずユーザーの設定を取得
                    let settingsRef = self.db.collection("users")
                        .document(otherUserID)
                        .collection("settings")
                        .document(groupID)

                    settingsRef.getDocument { settingsSnapshot, settingsError in
                        if let settingsError = settingsError {
                            print("⚠️ Error fetching settings for \(userName): \(settingsError.localizedDescription)")
                            group.leave()
                            return
                        }

                        // 設定データの取得と解析
                        var healthDataSettings: [String: Bool] = [:]
                        var isAnonymous = false
                        //var anonymousName: String?
                        var displayName: String = userName

                        if let settingsData = settingsSnapshot?.data() {
                            healthDataSettings = settingsData["healthDataSettings"] as? [String: Bool] ?? [:]
                            isAnonymous = settingsData["isAnonymous"] as? Bool ?? false
                            print("📋 Settings found for \(userName): \(healthDataSettings)")

                            if isAnonymous {
                                if let anonymousName = settingsData["userNameforAnonymous"] as? String {
                                    print("✅ Anonymous user detected: \(anonymousName)")
                                    displayName = anonymousName
                                } else {
                                    print("ℹ️ Anonymous user detected, but no anonymous name set. Using default.")
                                }
                            } else {
                                print("👤 Regular user detected: \(userName)")
                            }

                        } else {
                            print("ℹ️ No settings found for \(userName), using default (all shared)")
                            for dataType in dataTypes {
                                healthDataSettings[dataType] = true
                            }
                        }

                        var userTotalData: [String: Double] = [:]
                        let userGroup = DispatchGroup()

                        // 設定に基づいてデータタイプをフィルタリング
                        for dataType in dataTypes {
                            guard healthDataSettings[dataType] == true else {
                                print("🔒 Skipping \(dataType) for \(userName) due to settings")
                                continue
                            }

                            userGroup.enter()
                            print("📊 Fetching \(dataType) for \(userName)")

                            let healthDataRef = self.db.collection("users")
                                .document(otherUserID)
                                .collection("healthData")
                                .document(dataType)
                                .collection("data")
                                .whereField("date", isGreaterThanOrEqualTo: ISO8601DateFormatter().string(from: twentyFourHoursAgo))
                                .whereField("date", isLessThanOrEqualTo: ISO8601DateFormatter().string(from: now))

                            healthDataRef.getDocuments { healthSnapshot, healthError in
                                defer { userGroup.leave() }

                                if let healthError = healthError {
                                    print("❌ Error fetching \(dataType) for \(userName): \(healthError.localizedDescription)")
                                    fetchError = healthError
                                    return
                                }

                                if let documents = healthSnapshot?.documents {
                                    print("✅ Fetched \(documents.count) \(dataType) records for \(userName)")
                                    // Calculate total for this data type
                                    let total = documents.compactMap { doc -> Double? in
                                        if let value = doc.data()["value"] as? Double {
                                            return value
                                        } else if let value = doc.data()["value"] as? Int {
                                            return Double(value)
                                        }
                                        return nil
                                    }.reduce(0, +)

                                    userTotalData[dataType] = total
                                    print("📊 Total \(dataType) for \(userName): \(total)")
                                }
                            }
                        }

                        // 各ユーザーのデータ取得完了時
                        userGroup.notify(queue: .main) {
                            print("⭐️ Appending totals for user \(displayName)")
                            results.append((userName: displayName, totalData: userTotalData))
                            group.leave()
                        }
                    }
                }

                // 全ユーザーのデータ取得完了時
                group.notify(queue: .main) {
                    print("🏁 All data fetching completed. Total results: \(results.count)")
                    if let fetchError = fetchError {
                        completion(.failure(fetchError))
                    } else {
                        completion(.success(results))
                    }
                }
            }
    }



    // MARK: 他のユーザーのデータを取得（shared_userロール限定）
    func fetchSharedHealthData(for currentUserID: String, groupID: String, completion: @escaping (Result<[(userName: String, data: [HealthDataItem])], Error>) -> Void) {
        let group = DispatchGroup()
        var results: [(userName: String, data: [HealthDataItem])] = []
        var fetchError: Error?

        print("Starting fetchSharedHealthData with settings filtering for groupID: \(groupID)")

        self.db.collection("users")
            .whereField("role", isEqualTo: "shared_user")
            .whereField("groups", arrayContains: groupID)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    print("❌ Error fetching users: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }

                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    print("ℹ️ No users found for group \(groupID)")
                    completion(.success([]))
                    return
                }

                print("📝 Found \(documents.count) users in group")

                let dataTypes = ["stepCount", "activeEnergyBurned", "distanceWalkingRunning", "basalEnergyBurned"]

                for document in documents {
                    group.enter()

                    guard let userName = document.data()["name"] as? String else {
                        print("❌ Missing name for user document: \(document.documentID)")
                        group.leave()
                        continue
                    }

                    let otherUserID = document.documentID
                    print("🔍 Processing data for user: \(userName) (ID: \(otherUserID))")

                    // まずユーザーの設定を取得
                    let settingsRef = self.db.collection("users")
                        .document(otherUserID)
                        .collection("settings")
                        .document(groupID)

                    settingsRef.getDocument { settingsSnapshot, settingsError in
                        if let settingsError = settingsError {
                            print("⚠️ Error fetching settings for \(userName): \(settingsError.localizedDescription)")
                            group.leave()
                            return
                        }

                        // 設定データの取得と解析
                        var healthDataSettings: [String: Bool] = [:]
                        var isAnonymous = false
                        var anonymousName: String?
                        var deletionDate: Date?

                        if let settingsData = settingsSnapshot?.data() {
                            healthDataSettings = settingsData["healthDataSettings"] as? [String: Bool] ?? [:]
                            isAnonymous = settingsData["isAnonymous"] as? Bool ?? false
                            print("📋 Settings found for \(userName): \(healthDataSettings)")

                            if isAnonymous {
                                if let anonymousName = settingsData["userNameForAnonymous"] as? String {
                                    print("✅ Anonymous user detected: \(anonymousName)")
                                } else {
                                    print("ℹ️ Anonymous user detected, but no anonymous name set. Using default.")
                                }
                            } else {
                                print("👤 Regular user detected: \(userName)")
                            }

                            if let deletionDateString = settingsData["deletionDate"] as? String {
                                let formatter = ISO8601DateFormatter()
                                deletionDate = formatter.date(from: deletionDateString)
                                print("🗓️ delation date is \(String(describing: deletionDate))")
                            }

                        } else {
                            print("ℹ️ No settings found for \(userName), using default (all shared)")
                            // デフォルトですべてのデータタイプを共有可能とする
                            for dataType in dataTypes {
                                healthDataSettings[dataType] = true
                            }
                        }

                        var userHealthData: [HealthDataItem] = []
                        let userGroup = DispatchGroup()

                        // 設定に基づいてデータタイプをフィルタリング
                        for dataType in dataTypes {
                            // 設定で共有が許可されているデータタイプのみ取得
                            guard healthDataSettings[dataType] == true else {
                                print("🔒 Skipping \(dataType) for \(userName) due to settings")
                                continue
                            }

                            userGroup.enter()
                            print("📊 Fetching \(dataType) for \(userName)")

                            let healthDataRef = self.db.collection("users")
                                .document(otherUserID)
                                .collection("healthData")
                                .document(dataType)
                                .collection("data")

                            healthDataRef.getDocuments { healthSnapshot, healthError in
                                defer { userGroup.leave() }

                                if let healthError = healthError {
                                    print("❌ Error fetching \(dataType) for \(userName): \(healthError.localizedDescription)")
                                    fetchError = healthError
                                    return
                                }
//test01@example.com
                                if let documents = healthSnapshot?.documents {
                                    print("✅ Fetched \(documents.count) \(dataType) records for \(userName)")

                                    let filteredDocuments = documents.filter { doc in
                                        if let deletionDate = deletionDate {
                                            if let dateString = doc.data()["date"] as? String,
                                               let dataDate = ISO8601DateFormatter().date(from: dateString) {
                                                return dataDate < deletionDate
                                            }
                                            print("✅ Document excluded due to deletionDate")
                                        }
                                        return true
                                    }

                                    let data = documents.compactMap { HealthDataItem(document: $0) }
                                    userHealthData.append(contentsOf: data)
                                }
                            }
                        }
                        // 各ユーザーのデータ取得完了時
                        userGroup.notify(queue: .main) {
                            let displayName = isAnonymous ? (anonymousName ?? "Anonymous User") : userName
                            print("⭐️ 現在：Appending data for user \(displayName) with \(userHealthData.count) items")
                            results.append((userName: userName, data: userHealthData))
                            group.leave()
                        }
                    }
                }

                // 全ユーザーのデータ取得完了時
                group.notify(queue: .main) {
                    print("🏁 All data fetching completed. Total results: \(results.count)")
                    if let fetchError = fetchError {
                        completion(.failure(fetchError))
                    } else {
                        completion(.success(results))
                    }
                }
            }
    }

    // ユーザー設定の保存 - SettingView
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
            settings["userNameforAnonymous"] = userName
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

    // 歩数データをサブコレクションから取得 - VisualizeView
    func fetchStepCountDataFromSubcollection(userID: String, dataType: String, completion: @escaping (Result<[HealthDataItem], Error>) -> Void) {
        // Firestoreクエリの参照を作成
        let collectionRef = db.collection("users")
            .document(userID)
            .collection("healthData")
            .document(dataType)
            .collection("data")

        // Firestoreからドキュメントを取得
        collectionRef.getDocuments { snapshot, error in
            if let error = error {
                // Firestoreクエリのエラー処理
                print("Error fetching \(dataType) data: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            guard let documents = snapshot?.documents else {
                // ドキュメントが見つからない場合
                print("No \(dataType) data found for userID: \(userID)")
                completion(.success([]))
                return
            }

            // ログ: 取得したドキュメント数を表示
            print("Fetched \(documents.count) documents for \(dataType).")

            // ドキュメントをHealthDataItemに変換
            let data = documents.compactMap { HealthDataItem(document: $0) }

            // ログ: 正常に処理されたデータポイントの数を出力
            print("Successfully processed \(data.count) \(dataType) data points.")

            // 成功時の結果を返す
            completion(.success(data))
        }
    }

    // MARK: 自身の全てのヘルスデータを　mascine readable　な形式で取得
    private func processFirestoreData(_ data: [[String: Any]]) throws -> Data {
        let entries = try data.map { try HealthDataEntry(from: $0) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(entries)
    }

    private func saveHealthDataToJSON(documents: [QueryDocumentSnapshot], type: String, userID: String) throws -> URL {
        let data = documents.map { $0.data() }
        let jsonData = try processFirestoreData(data)
        let fileName = "\(type)_\(userID).json"
        guard let fileURL = saveFileToDocumentsDirectory(data: jsonData, fileName: fileName) else {
            throw NSError(domain: "FileError", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to save file"])
        }

        if let jsonString = String(data: jsonData.prefix(200), encoding: .utf8) {
            print("🔍 JSON Preview for \(type): \(jsonString)...")
        }

        print("💾 JSON file saved for \(type) at: \(fileURL.path)")
        return fileURL
    }

    private func saveFileToDocumentsDirectory(data: Data, fileName: String) -> URL? {
        let fileManager = FileManager.default
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ Failed to access documents directory")
            return nil
        }

        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        do {
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
            try data.write(to: fileURL, options: .atomic)
            print("📁 Documents Directory: \(documentsDirectory.path)")
            return fileURL
        } catch {
            print("❌ Failed to save file '\(fileName)': \(error.localizedDescription)")
            return nil
        }
    }

    func saveSplitJSONToFirestore(jsonData: Data, collectionName: String, completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            // JSONデータをデコード
            guard let jsonArray = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [[String: Any]] else {
                throw NSError(domain: "DecodingError", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to decode JSON"])
            }

            let batch = db.batch()
            let collectionRef = db.collection(collectionName)

            for (index, entry) in jsonArray.enumerated() {
                let documentRef = collectionRef.document("entry_\(index)")
                batch.setData(entry, forDocument: documentRef)
            }

            batch.commit { error in
                if let error = error {
                    print("❌ Error saving split JSON to Firestore: \(error.localizedDescription)")
                    completion(.failure(error))
                } else {
                    print("✅ Split JSON successfully saved to Firestore in \(collectionName)")
                    completion(.success(()))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }


    func exportAndCompressHealthData(for userID: String, completion: @escaping (Result<URL, Error>) -> Void) {
        let dataTypes = ["stepCount", "activeEnergyBurned", "distanceWalkingRunning", "basalEnergyBurned"]
        var allFiles: [URL] = []
        let dispatchGroup = DispatchGroup()

        for dataType in dataTypes {
            dispatchGroup.enter()
            var lastDocument: DocumentSnapshot?

            func fetchNextPage() {
                var query = db.collection("users")
                    .document(userID)
                    .collection("healthData")
                    .document(dataType)
                    .collection("data")
                    .limit(to: 50)

                if let lastDoc = lastDocument {
                    query = query.start(afterDocument: lastDoc)
                }

                query.getDocuments { [weak self] snapshot, error in
                    guard let self = self else {
                        dispatchGroup.leave()
                        return
                    }

                    if let error = error {
                        print("❌ Error fetching \(dataType): \(error.localizedDescription)")
                        dispatchGroup.leave()
                        return
                    }

                    guard let snapshot = snapshot else {
                        dispatchGroup.leave()
                        return
                    }

                    lastDocument = snapshot.documents.last
                    do {
                     let fileURL = try self.saveHealthDataToJSON(documents: snapshot.documents, type: dataType, userID: userID)
                     allFiles.append(fileURL)
                     } catch {
                     print("❌ Error processing \(dataType): \(error.localizedDescription)")
                     }

                    if snapshot.documents.count == 50 {
                        fetchNextPage()
                    } else {
                        dispatchGroup.leave()
                    }
                }
            }
            fetchNextPage()
        }

        dispatchGroup.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.compressFilesToZip(fileURLs: allFiles, zipFileName: "HealthData_\(userID).zip", completion: completion)
        }
    }

    private func compressFilesToZip(fileURLs: [URL], zipFileName: String, completion: @escaping (Result<URL, Error>) -> Void) {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            completion(.failure(NSError(domain: "FileError", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to access documents directory"])))
            return
        }

        let zipFileURL = documentsDirectory.appendingPathComponent(zipFileName)
        do {
            if FileManager.default.fileExists(atPath: zipFileURL.path) {
                try FileManager.default.removeItem(at: zipFileURL)
            }

            do {
                let archive = try Archive(url: zipFileURL, accessMode: .create)
                for fileURL in fileURLs {
                    try archive.addEntry(with: fileURL.lastPathComponent, fileURL: fileURL)
                }
                completion(.success(zipFileURL))
            } catch {
                print("❌ Failed to create ZIP: \(error.localizedDescription)")
                completion(.failure(error))
            }

            completion(.success(zipFileURL))
        } catch {
            print("❌ Failed to create ZIP: \(error.localizedDescription)")
            completion(.failure(error))
        }
    }

    // 他のユーザーのグループ、ロールを編集
    func updateUserSettings(userID: String, groups: [String], role: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let userRef = db.collection("users").document(userID)
        let data: [String: Any] = [
            "groups": groups,
            "role": role
        ]
        userRef.updateData(data) { error in
            if let error = error {
                print("Failed to update user settings: \(error.localizedDescription)")
                completion(.failure(error))
            } else {
                print("User settings updated successfully.")
                completion(.success(()))
            }
        }
    }
}


struct HealthDataItem: Identifiable, Equatable {
    let id: String
    let type: String
    let value: Double
    let date: Date

    init?(document: QueryDocumentSnapshot) {
        let data = document.data()

        // Debug: ログを追加してデータを確認
        print("Initializing HealthDataItem with document: \(document.documentID), data: \(data)")

        // `type`フィールドの取得と検証
        guard let type = data["type"] as? String else {
            print("Error: Missing or invalid 'type' field in document \(document.documentID)")
            return nil
        }

        // `value`フィールドの取得と検証
        let value: Double
            if let doubleValue = data["value"] as? Double {
                value = doubleValue
            } else if let intValue = data["value"] as? Int {
                value = Double(intValue)
            } else {
                print("Error: Missing or invalid 'value' field in document \(document.documentID)")
                return nil
            }

        // `timestamp`または`date`を使ってDate型に変換
        var parsedDate: Date? = nil
        if let timestamp = data["timestamp"] as? Timestamp {
            parsedDate = timestamp.dateValue()
        } else if let dateString = data["date"] as? String {
            let dateFormatter = ISO8601DateFormatter()
            parsedDate = dateFormatter.date(from: dateString)
        }

        // 日付が解析できない場合は初期化を失敗
        guard let date = parsedDate else {
            print("Error: Missing or invalid 'date' or 'timestamp' field in document \(document.documentID)")
            return nil
        }

        // プロパティを設定
        self.id = document.documentID
        self.type = type
        self.value = value
        self.date = date

        // Debug: 正常に初期化された場合
        print("Successfully initialized HealthDataItem with ID: \(id), type: \(type), value: \(value), date: \(date)")
    }

    // Equatable
    static func == (lhs: HealthDataItem, rhs: HealthDataItem) -> Bool {
        return lhs.id == rhs.id &&
               lhs.type == rhs.type &&
               lhs.value == rhs.value &&
               lhs.date == rhs.date
    }
}

struct HealthDataEntry: Codable {
    let type: String
    let date: String
    let value: Double

    init(from firestoreData: [String: Any]) throws {
        guard let type = firestoreData["type"] as? String else {
            throw EncodingError.invalidValue("type", .init(codingPath: [], debugDescription: "Missing or invalid type"))
        }

        // 日付の処理
        guard let dateStr = firestoreData["date"] as? String else {
            throw EncodingError.invalidValue("date", .init(codingPath: [], debugDescription: "Missing or invalid date"))
        }

        // 値の処理
        let value: Double
        if let doubleValue = firestoreData["value"] as? Double {
            value = doubleValue
        } else if let intValue = firestoreData["value"] as? Int {
            value = Double(intValue)
        } else if let stringValue = firestoreData["value"] as? String,
                  let doubleValue = Double(stringValue) {
            value = doubleValue
        } else {
            throw EncodingError.invalidValue("value", .init(codingPath: [], debugDescription: "Invalid value format"))
        }

        self.type = type
        self.date = dateStr
        self.value = value
    }
}

