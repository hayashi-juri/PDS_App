//
//  PDS_AppApp.swift
//  PDS_App
//
//  Created by Juri Hayashi on 2024/12/20.
//

/*import SwiftUI
import FirebaseCore
import FirebaseFirestore
import Firebase
import FirebaseAppCheck*/

import SwiftUI
import FirebaseCore
import FirebaseAppCheck
import FirebaseAuth

/*class YourSimpleAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        return AppAttestProvider(app: app)
    }
}*/

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

        // Firebase を初期化
        FirebaseApp.configure()
        print("FirebaseApp.configure() called")

        FirebaseConfiguration.shared.setLoggerLevel(.debug)
        print("Firebase configured successfully.")

        return true
    }
}

@main
struct PDS_AppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @StateObject private var authManager = AuthManager.shared
    @StateObject private var firestoreManager = FirestoreManager(authManager: AuthManager.shared)
    @StateObject private var healthKitManager = HealthKitManager(authManager: AuthManager.shared)

    var body: some Scene {
        WindowGroup {
            ContentView(
                authManager: authManager,
                firestoreManager: firestoreManager,
                healthKitManager: healthKitManager
            )
        }
    }
}

