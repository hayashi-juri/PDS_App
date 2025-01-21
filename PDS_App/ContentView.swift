/*
 ContentView.swift
 PDS_App
 Created by Juri Hayashi on 2024/12/20.

 タブを提供します：

 データの視覚化
 データの共有
 設定管理
 */

import SwiftUI

struct ContentView: View {
    @StateObject var authManager: AuthManager
    @StateObject var firestoreManager: FirestoreManager
    @StateObject var healthKitManager: HealthKitManager
    @State private var isHealthKitAuthorized: Bool = false
    @State private var email: String = "" // メールアドレス入力
    @State private var password: String = "" // パスワード入力
    @State private var isRegistering: Bool = false // ログイン/登録の切り替え

    init(authManager: AuthManager, firestoreManager: FirestoreManager, healthKitManager: HealthKitManager) {
        _authManager = StateObject(wrappedValue: authManager)
        _firestoreManager = StateObject(wrappedValue: firestoreManager)
        _healthKitManager = StateObject(wrappedValue: healthKitManager)
    }

    var body: some View {
        if isHealthKitAuthorized && authManager.isLoggedIn {
            TabView {
                // データ共有
                if let userID = authManager.userID {
                    // データの視覚化
                    VisualizeView(
                        userID: userID,
                        firestoreManager: firestoreManager,
                        healthKitManager: healthKitManager
                    )
                    .tabItem {
                        Image(systemName: "chart.bar")
                        Text("Data Graph")
                    }

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

                // 設定画面
                SettingView(
                    firestoreManager: firestoreManager,
                    healthKitManager: healthKitManager
                )
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
            }
            //.onAppear(perform: fetchHealthDataOnStart)
        }

        else if !authManager.isLoggedIn {
            authView
        } else {
            VStack {
                ProgressView("Authorising...")
                    .onAppear(perform: authorizeHealthKit)
            }
        }
    }

    private func authorizeHealthKit() {
        healthKitManager.authorizeHK { success, error in
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
                print("HealthKit data fetched and saved successfully.")
            }
        }
    }

    private var authView: some View {
        VStack {
            Text(authManager.isRegistering ? "Register" : "Log In")
                .font(.largeTitle)
                .padding()
            
            TextField("Email", text: $authManager.email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            SecureField("Password", text: $authManager.password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            Button(authManager.isRegistering ? "Register" : "Log In") {
                authManager.loginOrRegister { success in
                    if success {
                        print("\(authManager.isRegistering ? "Registration" : "Login") successful.")
                    } else {
                        print("\(authManager.isRegistering ? "Registration" : "Login") failed: \(authManager.authErrorMessage ?? "Unknown error")")
                    }
                }
            }
            .padding()
            .buttonStyle(.bordered)

            Button("Switch to \(authManager.isRegistering ? "Log In" : "Register")") {
                authManager.isRegistering.toggle()
            }
            .padding()

            if let errorMessage = authManager.authErrorMessage {
                Text("Error: \(errorMessage)")
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .padding()
    }

}

