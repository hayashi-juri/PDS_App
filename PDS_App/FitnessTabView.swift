//
//  TabView.swift
//  PDS_App
//
//  Created by Juri Hayashi on 2024/12/20.
//

import SwiftUI

struct FitnessTabView: View {
    @State var selectedTab = "Home"

    init() {
        // Tab appearance
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.stackedLayoutAppearance.selected.iconColor = .systemPink
        // set icon color
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.systemPink]
        // icon name color
        UITabBar.appearance().standardAppearance = appearance
        // set appearance to Tab
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tag("Home")
                .tabItem {
                    Image(systemName: "house")
                    Text("Home")
                }

            HistoricDataView()
                .tag("HistoricData")
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("Historic Data")
                }
        }
    }
}

struct PDS_AppPreviews: PreviewProvider {
    static var previews:some View {
        FitnessTabView()
    }
}

#Preview {
    FitnessTabView()
}
