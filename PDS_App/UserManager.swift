//
//  UserManager.swift
//  PDS_App
//
//  Created by Juri Hayashi on 2025/01/11.
//


import Foundation

class UserManager {
    static let shared = UserManager()

    private let userDefaultsKey = "userID"

    /// UUIDを生成または既存のものを取得
    func getOrCreateUserID() -> String {
        if let savedUserID = UserDefaults.standard.string(forKey: userDefaultsKey) {
            return savedUserID
        } else {
            let newUserID = UUID().uuidString
            UserDefaults.standard.set(newUserID, forKey: userDefaultsKey)
            return newUserID
        }
    }
}
