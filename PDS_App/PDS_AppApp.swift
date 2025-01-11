//
//  PDS_AppApp.swift
//  PDS_App
//
//  Created by Juri Hayashi on 2024/12/20.
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore
import Firebase

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    return true
  }
}

@main
struct PDS_AppApp: App {
    // register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    private let firestoreManager = FirestoreManager() // Firestoreの操作を管理
    private let healthKitManager = HealthKitManager() // HealthKitの操作を管理


    var body: some Scene {
        WindowGroup {
            ContentView(firestoreManager: firestoreManager, healthKitManager: healthKitManager)
        }
    }
}
