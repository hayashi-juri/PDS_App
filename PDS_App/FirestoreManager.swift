//
//  FirestoreManager.swift
//  PDS_App
//
//  Created by Juri Hayashi on 2025/01/07.
//
import FirebaseFirestore
import FirebaseCore
import ZIPFoundation

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
                        var anonymousName: String?
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



    // MARK: 他のユーザーのデータを取得（UUロール限定）
    func fetchSharedHealthData(for currentUserID: String, groupID: String, completion: @escaping (Result<[(userName: String, data: [HealthDataItem])], Error>) -> Void) {
     let group = DispatchGroup()
     var results: [(userName: String, data: [HealthDataItem])] = []
     var fetchError: Error?

     print("Starting fetchSharedHealthData with settings filtering for groupID: \(groupID)")

     self.db.collection("users")
         .whereField("role", isEqualTo: "others")
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

                             if let documents = healthSnapshot?.documents {
                                 print("✅ Fetched \(documents.count) \(dataType) records for \(userName)")
                                 let data = documents.compactMap { HealthDataItem(document: $0) }
                                 userHealthData.append(contentsOf: data)
                             }
                         }
                     }

                     // 各ユーザーのデータ取得完了時
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

    // 歩数データをサブコレクションから取得
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


    /*func exportAndCompressHealthData(for userID: String, completion: @escaping (Result<URL, Error>) -> Void) {
        let dataTypes = ["stepCount", "activeEnergyBurned", "distanceWalkingRunning", "basalEnergyBurned"]
        var allFiles: [URL] = [] // 保存されたファイルのURLを保持
        let dispatchGroup = DispatchGroup()

        print("📊 Starting export for userID: \(userID)")

        for dataType in dataTypes {
            dispatchGroup.enter()
            print("📊 Fetching \(dataType)")

            let healthDataRef = db.collection("users")
                .document(userID)
                .collection("healthData")
                .document(dataType)
                .collection("data")

            healthDataRef.getDocuments { snapshot, error in
                defer { dispatchGroup.leave() } // 処理完了後にleaveを呼び出す
                if let error = error {
                    print("😭 Failed to fetch documents for \(dataType): \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else {
                    print("😭 No documents found for \(dataType)")
                    return
                }

                print("🙌 Fetched \(documents.count) documents for \(dataType)")

                var allData: [[String: Any]] = []

                for document in documents {
                    allData.append(document.data())
                }

                // JSON形式で永続ディレクトリに保存
                do {
                    let jsonFileName = "\(dataType)_\(userID).json"
                    let jsonData = try JSONSerialization.data(withJSONObject: allData, options: .prettyPrinted)
                    guard let jsonFileURL = self.saveFileToDocumentsDirectory(data: jsonData, fileName: jsonFileName) else {
                        print("🥺 Failed to save JSON file for \(dataType)")
                        return
                    }

                    print("🥰 JSON file saved for \(dataType) at: \(jsonFileURL.path)")
                    allFiles.append(jsonFileURL)
                } catch {
                    print("🥺 Failed to serialize JSON data for \(dataType): \(error.localizedDescription)")
                }
            }
        }

        // 全てのデータ取得処理が完了した後に圧縮処理
        dispatchGroup.notify(queue: .main) {
            print("📦 All data types fetched. Starting compression.")
            self.compressFilesToZip(fileURLs: allFiles, zipFileName: "HealthData_\(userID).zip") { result in
                switch result {
                case .success(let archiveURL):
                    print("🥰 All files compressed to: \(archiveURL.path)")
                    completion(.success(archiveURL))
                case .failure(let error):
                    print("🥺 Failed to compress files: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
        }
    }*/

    func exportAndCompressHealthData(for userID: String, completion: @escaping (Result<URL, Error>) -> Void) {
        let dataTypes = ["stepCount", "activeEnergyBurned", "distanceWalkingRunning", "basalEnergyBurned"]
        var allFiles: [URL] = [] // 保存されたファイルのURLを保持
        let dispatchGroup = DispatchGroup()
        let pageSize = 50 // 1ページあたりのドキュメント数

        print("📊 Starting export for userID: \(userID)")

        for dataType in dataTypes {
            dispatchGroup.enter()
            print("📊 Fetching \(dataType)")

            var lastDocument: DocumentSnapshot? // 前回取得した最後のドキュメント
            var allData: [[String: Any]] = []

            func fetchNextPage() {
                var query = db.collection("users")
                    .document(userID)
                    .collection("healthData")
                    .document(dataType)
                    .collection("data")
                    .limit(to: pageSize)

                if let lastDoc = lastDocument {
                    query = query.start(afterDocument: lastDoc)
                }

                query.getDocuments { snapshot, error in
                    if let error = error {
                        print("😭 Failed to fetch documents for \(dataType): \(error.localizedDescription)")
                        dispatchGroup.leave()
                        return
                    }

                    guard let snapshot = snapshot else {
                        print("😭 No documents found for \(dataType)")
                        dispatchGroup.leave()
                        return
                    }

                    print("🙌 Fetched \(snapshot.documents.count) documents for \(dataType)")

                    for document in snapshot.documents {
                        allData.append(document.data())
                    }

                    if let lastDoc = snapshot.documents.last {
                        lastDocument = lastDoc
                        if snapshot.documents.count == pageSize {
                            // 次のページを取得
                            fetchNextPage()
                            return
                        }
                    }

                    // 全ページのデータを取得した後、JSONに保存
                    do {
                        let jsonFileName = "\(dataType)_\(userID).json"
                        let jsonData = try JSONSerialization.data(withJSONObject: allData, options: .prettyPrinted)
                        guard let jsonFileURL = self.saveFileToDocumentsDirectory(data: jsonData, fileName: jsonFileName) else {
                            print("🥺 Failed to save JSON file for \(dataType)")
                            dispatchGroup.leave()
                            return
                        }

                        print("🥰 JSON file saved for \(dataType) at: \(jsonFileURL.path)")
                        allFiles.append(jsonFileURL)
                        dispatchGroup.leave()
                    } catch {
                        print("🥺 Failed to serialize JSON data for \(dataType): \(error.localizedDescription)")
                        dispatchGroup.leave()
                    }
                }
            }

            fetchNextPage() // 最初のページを取得
        }

        // 全てのデータ取得処理が完了した後に圧縮処理
        dispatchGroup.notify(queue: .main) {
            print("📦 All data types fetched. Starting compression.")
            self.compressFilesToZip(fileURLs: allFiles, zipFileName: "HealthData_\(userID).zip") { result in
                switch result {
                case .success(let archiveURL):
                    print("🥰 All files compressed to: \(archiveURL.path)")
                    completion(.success(archiveURL))
                case .failure(let error):
                    print("🥺 Failed to compress files: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
        }
    }


    // JSONファイルを保存するメソッド
    private func saveFileToDocumentsDirectory(data: Data, fileName: String) -> URL? {
        let fileManager = FileManager.default
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Failed to access documents directory")
            return nil
        }
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("Failed to save file: \(error.localizedDescription)")
            return nil
        }
    }

    // 複数ファイルをZIP形式で圧縮するメソッド
    private func compressFilesToZip(fileURLs: [URL], zipFileName: String, completion: @escaping (Result<URL, Error>) -> Void) {
        do {
            // ドキュメントディレクトリを取得
            guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                throw NSError(domain: "FileError", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to access documents directory"])
            }

            // ZIPファイルのパスを作成
            let zipFileURL = documentsDirectory.appendingPathComponent(zipFileName)

            // 既存のZIPファイルがあれば削除
            if FileManager.default.fileExists(atPath: zipFileURL.path) {
                try FileManager.default.removeItem(at: zipFileURL)
            }

            // ZIPアーカイブを作成
            let zipArchive = Archive(url: zipFileURL, accessMode: .create)!

            // 各ファイルを圧縮してZIPに追加
            for fileURL in fileURLs {
                do {
                    // 元のファイルデータを取得
                    let data = try Data(contentsOf: fileURL)

                    // 圧縮データを作成 (zlib圧縮)
                    let compressedData = try (data as NSData).compressed(using: .zlib)

                    // 一時ファイルに圧縮データを保存
                    let compressedFileURL = documentsDirectory.appendingPathComponent(fileURL.lastPathComponent + ".compressed")
                    try compressedData.write(to: compressedFileURL)

                    // ZIPアーカイブに追加
                    try zipArchive.addEntry(with: fileURL.lastPathComponent, fileURL: compressedFileURL, compressionMethod: .deflate)

                    // 一時ファイルを削除
                    try FileManager.default.removeItem(at: compressedFileURL)
                } catch {
                    print("Failed to process file \(fileURL.lastPathComponent): \(error.localizedDescription)")
                    throw error
                }
            }

            print("📦 ZIP file created at: \(zipFileURL.path)")
            completion(.success(zipFileURL))
        } catch {
            print("Failed to create ZIP file: \(error.localizedDescription)")
            completion(.failure(error))
        }
    }


    // 複数のファイルをZIP形式で圧縮
    /*private func compressFiles(fileURLs: [URL], archiveFileName: String, completion: @escaping (Result<URL, Error>) -> Void) {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            completion(.failure(NSError(domain: "FileError", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to access documents directory"])))
            return
        }

        let archiveURL = documentsDirectory.appendingPathComponent(archiveFileName)

        do {
            let archive = try FileManager.default.createDirectoryContents(atPath: archiveURL.path)
            for fileURL in fileURLs {
                let fileName = fileURL.lastPathComponent
                try archive.addFile(at: fileURL, filename: fileName)
            }

            try archive.close()
            completion(.success(archiveURL))
        } catch {
            completion(.failure(error))
        }
    }*/

    /*private func saveFileToDocumentsDirectory(data: Data, fileName: String) -> URL? {
            let fileManager = FileManager.default
            guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                print("🥲📄 Failed to access documents directory")
                return nil
            }
            let fileURL = documentsDirectory.appendingPathComponent(fileName)
            do {
                try data.write(to: fileURL)
                return fileURL
            } catch {
                print("🥲📁 Failed to save file: \(error.localizedDescription)")
                return nil
            }
        }*/

    // Fixed compression method
       /* private func compressFile(at sourceURL: URL, fileName: String, completion: @escaping (Result<URL, Error>) -> Void) {
            do {
                let data = try Data(contentsOf: sourceURL)

                // Use compression level
                let compressedData = try (data as NSData).compressed(using: .zlib)

                guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                    throw NSError(domain: "FileError", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to access documents directory"])
                }

                let compressedFileURL = documentsDirectory.appendingPathComponent(fileName)

                try compressedData.write(to: compressedFileURL)

                completion(.success(compressedFileURL))
            } catch {
                completion(.failure(error))
            }
        }*/
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
