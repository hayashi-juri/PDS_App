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
        @Published var userID: String?
        @Published var authErrorMessage: String?
        @Published var email: String = "" // ユーザーが入力するメール
        @Published var password: String = "" // ユーザーが入力するパスワード
        @Published var isRegistering: Bool = false // 登録/ログインの切り替え


    func loginOrRegister(completion: @escaping (Bool) -> Void) {
            if isRegistering {
                register(completion: completion)
            } else {
                login(completion: completion)
            }
        }

    // ログイン
    private func login(completion: @escaping (Bool) -> Void) {
            Auth.auth().signIn(withEmail: email, password: password) { [weak self] authResult, error in
                DispatchQueue.main.async {
                    if let error = error {
                        self?.authErrorMessage = error.localizedDescription
                        completion(false)
                    } else {
                        self?.userID = authResult?.user.uid
                        self?.isLoggedIn = true
                        self?.authErrorMessage = nil
                        completion(true)
                    }
                }
            }
        }

    private func register(completion: @escaping (Bool) -> Void) {
            Auth.auth().createUser(withEmail: email, password: password) { [weak self] authResult, error in
                DispatchQueue.main.async {
                    if let error = error {
                        self?.authErrorMessage = error.localizedDescription
                        completion(false)
                    } else {
                        self?.userID = authResult?.user.uid
                        self?.isLoggedIn = true
                        self?.authErrorMessage = nil
                        completion(true)
                    }
                }
            }
        }

    // ログアウト
    func logout() {
            do {
                try Auth.auth().signOut()
                DispatchQueue.main.async {
                    self.isLoggedIn = false
                    self.userID = nil
                }
            } catch {
                self.authErrorMessage = error.localizedDescription
            }
        }

    // 現在のユーザー取得
    func getCurrentUser() -> User? {
        return Auth.auth().currentUser
    }
}
