//
//  AuthManager.swift
//  PDS_App
//
//  Created by Juri Hayashi on 2025/01/15.
//


import Firebase
import Foundation
import FirebaseAuth

class AuthManager: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var authErrorMessage: String? = nil
    @Published var userID: String? = nil

    // ログイン
    func login(email: String, password: String, completion: @escaping (Bool) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] authResult, error in
            guard let self = self else { return }

            if let error = error {
                self.authErrorMessage = error.localizedDescription
                self.isLoggedIn = false
                self.userID = nil
                completion(false)
            } else {
                self.authErrorMessage = nil
                self.isLoggedIn = true
                self.userID = authResult?.user.uid // FirebaseのユーザーIDを取得
                completion(true)
            }
        }
    }

    // ログアウト
    func logout() {
        do {
            try Auth.auth().signOut()
            self.isLoggedIn = false
            self.userID = nil
        } catch let error as NSError {
            self.authErrorMessage = error.localizedDescription
        }
    }

    // ユーザー作成
    func register(email: String, password: String, completion: @escaping (Bool) -> Void) {
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] authResult, error in
            guard let self = self else { return }

            if let error = error {
                self.authErrorMessage = error.localizedDescription
                completion(false)
            } else {
                self.authErrorMessage = nil
                self.isLoggedIn = true
                self.userID = authResult?.user.uid // FirebaseのユーザーIDを取得
                completion(true)
            }
        }
    }

    // 現在のユーザー取得
    func getCurrentUser() -> User? {
        return Auth.auth().currentUser
    }
}
