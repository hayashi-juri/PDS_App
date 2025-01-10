//
//  HomeView.swift
//  PDS_App
//
//  Created by Juri Hayashi on 2025/01/10.
//

import SwiftUI

struct HomeView: View {
    @State private var settings: [WS_Agreement.DataSetting] = WS_Agreement.defaultSettings

    var body: some View {
        TabView {
            // データのグラフ化タブ
            VisualizeView()
                .tabItem {
                    Image(systemName: "chart.bar")
                    Text("Data Graph")
                }

            // アプリ内データシェアタブ
            DataShareView()
                .tabItem {
                    Image(systemName: "person.2.fill")
                    Text("Data Share")
                }

            // 設定タブ
            /*SettingView(firestoreManager: firestoreManager)
                            .tabItem {
                                Image(systemName: "gear")
                                Text("設定")
                            }*/
        }
    }
}

