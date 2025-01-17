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
    static let shared = AuthManager() // シングルトンインスタンス

    @Published var isLoggedIn: Bool = false
    @Published var userID: String?
    @Published var authErrorMessage: String?
    @Published var email: String = "" // ユーザーが入力するメール
    @Published var password: String = "" // ユーザーが入力するパスワード
    @Published var isRegistering: Bool = false // 登録/ログインの切り替え


    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }

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
                        print("Error signing in: \(error.localizedDescription)")
                        self?.authErrorMessage = error.localizedDescription
                        completion(false)
                    } else {
                        print("Successfully signed in. User ID: \(authResult?.user.uid ?? "")")
                        self?.userID = authResult?.user.uid
                        self?.isLoggedIn = true
                        self?.authErrorMessage = nil
                        completion(true)
                    }
                }
            }
        }

    // 登録
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

    // グループIDを追加するメソッド
        func addGroupToUser(groupId: String, completion: @escaping (Result<Void, Error>) -> Void) {
            guard let userId = userID else {
                completion(.failure(NSError(domain: "AuthManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not logged in."])))
                return
            }

            let db = Firestore.firestore()
            let userRef = db.collection("users").document(userId)

            userRef.updateData([
                "groups": FieldValue.arrayUnion([groupId])
            ]) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
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
