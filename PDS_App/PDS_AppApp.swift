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

//user123@test.com, User123

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
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

        // AppCheck Provider を登録
        // let providerFactory = YourSimpleAppCheckProviderFactory()
        // AppCheck.setAppCheckProviderFactory(providerFactory)

        // Firebase を初期化
        FirebaseApp.configure()

        return true
    }
}

@main
struct PDS_AppApp: App {
    // register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    private let authManager = AuthManager() // AuthManager を初期化
    private let firestoreManager: FirestoreManager
    private let healthKitManager: HealthKitManager

    init() {
        // AuthManagerを他のマネージャーに渡す
        self.firestoreManager = FirestoreManager(authManager: authManager)
        self.healthKitManager = HealthKitManager(authManager: authManager)
    }

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
