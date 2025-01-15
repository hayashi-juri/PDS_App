/*
 ContentView.swift
 PDS_App
 Created by Juri Hayashi on 2024/12/20.

 タブを提供します：

 データの視覚化
 データの共有
 設定管理
 */
/*import SwiftUI


struct ContentView: View {
    @StateObject var authManager = AuthManager() // AuthManagerを追加
    @StateObject var firestoreManager = FirestoreManager
    @StateObject var healthKitManager = HealthKitManager
    @State private var isHealthKitAuthorized: Bool = false

    init() {
        // AuthManagerを共有し、他のマネージャーに渡す
        let sharedAuthManager = AuthManager()
        _authManager = StateObject(wrappedValue: sharedAuthManager)
        _healthKitManager = StateObject(wrappedValue: HealthKitManager(authManager: sharedAuthManager))
        _firestoreManager = StateObject(wrappedValue: FirestoreManager(authManager: sharedAuthManager))
    }

    var body: some View {

        Group {

            if isHealthKitAuthorized && authManager.isLoggedIn {
                TabView {
                    /*VisualizeView(firestoreManager: firestoreManager, healthKitManager: healthKitManager)
                     .tabItem {
                     Image(systemName: "chart.bar")
                     Text("Data Graph")
                     }*/
                    if let userID = healthKitManager.userID {
                        DataShareView(
                            userID: userID,
                            firestoreManager: firestoreManager
                        )
                        .tabItem {
                            Image(systemName: "person.2")
                            Text("Data Share")
                        }

                    } else {
                        Text("User ID not available. Please try again later.")
                    }

                    SettingView(firestoreManager: firestoreManager, healthKitManager: healthKitManager)
                        .tabItem {
                            Image(systemName: "gear")
                            Text("Settings")
                        }
                }
                .onAppear {
                    // fetchHealthDataOnStart()

                    // Firestoreから既存のHealthDataを取得
                    if let userID = healthKitManager.userID {
                        firestoreManager.fetchHealthData(userID: userID) { result in
                            switch result {
                            case .success:
                                print("Data fetched successfully! (from firestore)")
                            case .failure(let error):
                                print("Data fetch failed: \(error.localizedDescription)")
                            }
                        }
                    }
                }
            } else if !authManager.isLoggedIn {
                VStack {
                    Text("Please log in")
                        .font(.title)
                    Button("Log In") {
                        authManager.login(email: "user@example.com", password: "password") { success in
                            if success {
                                print("Login successful.")
                            } else {
                                print("Login failed: \(authManager.authErrorMessage ?? "Unknown error")")
                            }
                        }
                    }
                    .padding()
                }

            } else {
                ProgressView("Authorising...")
                    .onAppear {
                        healthKitManager.authorize { success, error in
                            if success {
                                isHealthKitAuthorized = true
                                print("HealthKit authorization successful.")
                            } else {
                                print("Authorization failed: \(error?.localizedDescription ?? "Unknown error")")
                            }
                        }
                    }
            }
        }
    }


    private func fetchHealthDataOnStart() {
        guard isHealthKitAuthorized else { return }

        healthKitManager.fetchHealthData(to: firestoreManager) { error in
            if let error = error {
                print("Failed to fetch and save HealthKit data: \(error.localizedDescription)")
            } else {
                print("HealthKit data fetched and saved successfully (when app on start).")
            }
        }
    }
}*/

import SwiftUI

struct ContentView: View {
    @StateObject var authManager = AuthManager() // AuthManagerを追加
    @StateObject var firestoreManager: FirestoreManager
    @StateObject var healthKitManager: HealthKitManager
    @State private var isHealthKitAuthorized: Bool = false

    init() {
        // AuthManagerを共有し、他のマネージャーに渡す
        let sharedAuthManager = AuthManager()
        _authManager = StateObject(wrappedValue: sharedAuthManager)
        _healthKitManager = StateObject(wrappedValue: HealthKitManager(authManager: sharedAuthManager))
        _firestoreManager = StateObject(wrappedValue: FirestoreManager(authManager: sharedAuthManager))
    }

    var body: some View {
        /*
         Group {
         if isHealthKitAuthorized && authManager.isLoggedIn {
         TabView {

         VisualizeView(firestoreManager: firestoreManager, healthKitManager: healthKitManager)
         .tabItem {
         Image(systemName: "chart.bar")
         Text("Data Graph")
         }

         if let userID = healthKitManager.userID {
         DataShareView(
         userID: userID,
         firestoreManager: firestoreManager
         )
         .tabItem {
         Image(systemName: "person.2")
         Text("Data Share")
         }
         } else {
         Text("User ID not available. Please try again later.")
         }

         SettingView(
         firestoreManager: firestoreManager,
         healthKitManager: healthKitManager
         )
         .tabItem {
         Image(systemName: "gear")
         Text("Settings")
         }
         }
         .onAppear {
         if let userID = healthKitManager.userID {
         firestoreManager.fetchHealthData(userID: userID) { result in
         switch result {
         case .success:
         print("Data fetched successfully! (from firestore)")
         case .failure(let error):
         print("Data fetch failed: \(error.localizedDescription)")
         }
         }
         }
         }
         } else if !authManager.isLoggedIn {
         VStack {
         Text("Please log in")
         .font(.title)
         Button("Log In") {
         authManager.login(email: "user@example.com", password: "password") { success in
         if success {
         print("Login successful.")
         } else {
         print("Login failed: \(authManager.authErrorMessage ?? "Unknown error")")
         }
         }
         }
         .padding()
         }
         } else {
         ProgressView("Authorising...")
         .onAppear {
         healthKitManager.authorize { success, error in
         if success {
         isHealthKitAuthorized = true
         print("HealthKit authorization successful.")
         } else {
         print("Authorization failed: \(error?.localizedDescription ?? "Unknown error")")
         }
         }
         }
         }
         }
         */
        Group {
            Text("Hello, World!")
            if isHealthKitAuthorized && authManager.isLoggedIn {
                Text("Logged In")
                TabView {
                    // 歩数データ表示（データが取れるかのテスト）
                    VisualizeView(
                        firestoreManager: firestoreManager,
                        healthKitManager: healthKitManager
                    )
                    .tabItem {
                        Image(systemName: "chart.bar")
                        Text("Data Graph")
                    }

                    // ユーザーの設定を保存
                    SettingView(
                        firestoreManager: firestoreManager,
                        healthKitManager: healthKitManager
                    )
                    .tabItem {
                        Image(systemName: "gear")
                        Text("Settings")
                    }
                }
            } else if !authManager.isLoggedIn {
                VStack {
                    Text("Please log in")
                        .font(.title)
                    Button("Log In") {
                        authManager.login(email: "user@example.com", password: "password") { success in
                            if success {
                                print("Login successful.")
                            } else {
                                print("Login failed: \(authManager.authErrorMessage ?? "Unknown error")")
                            }
                        }
                    }
                    .padding()
                }
            } else {
                VStack {
                    ProgressView("Authorising...")
                        .onAppear(perform: authorizeHealthKit)
                }
            }
        }
    }

    private func authorizeHealthKit() {
        healthKitManager.authorizeHK(authManager: authManager) { success, error in
            if success {
                isHealthKitAuthorized = true
                print("HealthKit authorization successful.")
            } else {
                print("Authorization failed: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }

    private func fetchHealthDataOnStart() {
        guard isHealthKitAuthorized else { return }

        healthKitManager.fetchHealthData(to: firestoreManager) { error in
            if let error = error {
                print("Failed to fetch and save HealthKit data: \(error.localizedDescription)")
            } else {
                print("HealthKit data fetched and saved successfully (when app on start).")
            }
        }
    }
}

