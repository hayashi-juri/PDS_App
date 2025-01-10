//
//  SettingView.swift
//  PDS_App
//
//  Created by Juri Hayashi on 2025/01/10.
//

import SwiftUI

struct SettingView: View {
    @Binding var setting: WS_Agreement.DataSetting

    var body: some View {
        NavigationView {
            Form {
                // グループ選択
                Section(header: Text("共有グループ")) {
                    Picker("グループを選択", selection: $setting.groupID) {
                        Text("GroupA").tag("GroupA")
                        Text("GroupB").tag("GroupB")
                        Text("Public").tag("Public")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                // 匿名/実名切り替え
                Section(header: Text("匿名または実名")) {
                    Toggle("匿名で共有しますか？", isOn: $setting.anonymity)
                }

                // 削除期限
                Section(header: Text("削除期限")) {
                    DatePicker("期限を選択", selection: $setting.deletionDate, displayedComponents: .date)
                        .datePickerStyle(CompactDatePickerStyle())
                }
            }
            .navigationTitle("設定変更")
            .navigationBarItems(trailing: Button("完了") {
                // 完了ボタンで閉じる
                UIApplication.shared.windows.first { $0.isKeyWindow }?.rootViewController?.dismiss(animated: true, completion: nil)
            })
        }
    }
}
#Preview {
    
}
