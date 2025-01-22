//
//  SettingForOtherUserView.swift
//  PDS_App
//
//  Created by Juri Hayashi on 2025/01/22.
//


import SwiftUI
import FirebaseFirestore

/*struct SettingForOtherUserView: View {
    @ObservedObject var firestoreManager: FirestoreManager

    @State private var selectedUserID: String = ""
    @State private var groups: [String] = []
    @State private var role: String = ""
    @State private var allUsers: [(id: String, name: String)] = []
    @State private var errorMessage: String?

    let roles = ["me", "others", "admin"] // 役割の選択肢
    let groupOptions = ["Family", "Friends", "Public"] // グループの選択肢

    var body: some View {
        VStack {
            Text("Manage Other User Settings")
                .font(.headline)
                .padding()

            // ユーザー選択
            Picker("Select User", selection: $selectedUserID) {
                ForEach(allUsers, id: \.id) { user in
                    Text(user.name).tag(user.id)
                }
            }
            .onChange(of: selectedUserID) { newValue in
                fetchUserField(userID: newValue)
            }
            .pickerStyle(MenuPickerStyle())
            .padding()

            // グループ選択
            MultiSelectPicker(title: "Groups", options: groupOptions, selectedOptions: $groups)

            // ロール選択
            Picker("Role", selection: $role) {
                ForEach(roles, id: \.self) { role in
                    Text(role)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()

            // 保存ボタン
            Button("Save Settings") {
                saveSettings()
            }
            .padding()
            .disabled(selectedUserID.isEmpty)

            // エラーメッセージ
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .onAppear {
            fetchAllUsers()
        }
    }

    private func fetchAllUsers() {
        firestoreManager.db.collection("users").getDocuments { snapshot, error in
            if let error = error {
                self.errorMessage = "Failed to fetch users: \(error.localizedDescription)"
                return
            }

            guard let documents = snapshot?.documents else { return }

            self.allUsers = documents.map {
                let name = $0.data()["name"] as? String ?? "Unknown"
                return (id: $0.documentID, name: name)
            }

            // 初期値を設定
            if let firstUser = allUsers.first {
                self.selectedUserID = firstUser.id
            }
        }
    }

    var listener: ListenerRegistration?

    private func fetchUserField(userID: String) {
        // 既存のリスナーを解除
        listener?.remove()

        // 新しいリスナーを設定
        listener = firestoreManager.db.collection("users").document(userID).addSnapshotListener { snapshot, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to fetch user settings: \(error.localizedDescription)"
                }
                return
            }

            guard let data = snapshot?.data() else { return }

            DispatchQueue.main.async {
                self.groups = data["groups"] as? [String] ?? []
                self.role = data["role"] as? String ?? ""
            }
        }
    }


    private func saveSettings() {
        firestoreManager.updateUserSettings(userID: selectedUserID, groups: groups, role: role) { result in
            switch result {
            case .success:
                self.errorMessage = "Settings updated successfully!"
            case .failure(let error):
                self.errorMessage = "Failed to update settings: \(error.localizedDescription)"
            }
        }
    }
}*/

struct SettingForOtherUserView: View {
    @ObservedObject var firestoreManager: FirestoreManager
    @State private var selectedUserID: String = ""
    @State private var groups: [String] = []
    @State private var role: String = ""
    @State private var allUsers: [(id: String, name: String)] = []
    @State private var errorMessage: String?
    @State private var listener: ListenerRegistration? // Changed to @State property

    let roles = ["me", "shared_user","blocked_user"]
    let groupOptions = ["Family", "Friends", "Public"]

    var body: some View {
        VStack(spacing: 20) {
            Text("Manage Other User Settings")
                .font(.headline)
                .padding(.top, 20)

            Picker("Select User", selection: $selectedUserID) {
                ForEach(allUsers, id: \.id) { user in
                    Text(user.name).tag(user.id)
                }
            }
            .onChange(of: selectedUserID) { oldValue, newValue in
                fetchUserField(userID: newValue)
            }
            .pickerStyle(MenuPickerStyle())
            .padding(.horizontal)

            MultiSelectPicker(title: "Groups", options: groupOptions, selectedOptions: $groups).padding(.horizontal)

            Picker("Role", selection: $role) {
                ForEach(roles, id: \.self) { role in
                    Text(role)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)

            Button("Save Settings") {
                saveSettings()
            }
            .padding()
            .disabled(selectedUserID.isEmpty)

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .onAppear {
            fetchAllUsers()
        }
        .onDisappear {
            // Clean up listener when view disappears
            listener?.remove()
        }
    }

    private func fetchAllUsers() {
        firestoreManager.db.collection("users").getDocuments { snapshot, error in
            if let error = error {
                self.errorMessage = "Failed to fetch users: \(error.localizedDescription)"
                return
            }

            guard let documents = snapshot?.documents else { return }

            self.allUsers = documents.map {
                let name = $0.data()["name"] as? String ?? "Unknown"
                return (id: $0.documentID, name: name)
            }

            if let firstUser = allUsers.first {
                self.selectedUserID = firstUser.id
            }
        }
    }

    private func fetchUserField(userID: String) {
        // Remove existing listener
        listener?.remove()

        // Set new listener
        listener = firestoreManager.db.collection("users").document(userID).addSnapshotListener { snapshot, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to fetch user settings: \(error.localizedDescription)"
                }
                return
            }

            guard let data = snapshot?.data() else { return }

            DispatchQueue.main.async {
                self.groups = data["groups"] as? [String] ?? []
                self.role = data["role"] as? String ?? ""
            }
        }
    }

    private func saveSettings() {
        firestoreManager.updateUserSettings(userID: selectedUserID, groups: groups, role: role) { result in
            switch result {
            case .success:
                self.errorMessage = "Settings updated successfully!"
            case .failure(let error):
                self.errorMessage = "Failed to update settings: \(error.localizedDescription)"
            }
        }
    }
}

struct MultiSelectPicker: View {
    let title: String
    let options: [String]
    @Binding var selectedOptions: [String]

    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.headline)
            ForEach(options, id: \.self) { option in
                Toggle(option, isOn: Binding(
                    get: { selectedOptions.contains(option) },
                    set: { isSelected in
                        if isSelected {
                            selectedOptions.append(option)
                        } else {
                            selectedOptions.removeAll { $0 == option }
                        }
                    }
                ))
            }
        }
    }
}
