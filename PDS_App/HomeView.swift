//
//  HomeView.swift
//  PDS_App
//
//  Created by Juri Hayashi on 2024/12/20.
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        ScrollView(showsIndicators: true) {
            VStack {
                Text("Welcome")
                    .font(.largeTitle)
                    .padding() //add space around the content in the cell
            }

            HStack {

                Spacer() // make sure to put contents in the middle

                VStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Calories")
                            .font(.callout)
                            .bold()
                            .foregroundColor(.red)
                        Text("300 kcal")
                            .bold()
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Active")
                            .font(.callout)
                            .bold()
                            .foregroundColor(.green)
                        Text("30 mins")
                            .bold()
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Stand")
                            .font(.callout)
                            .bold()
                            .foregroundColor(.blue)
                        Text("8 hours")
                            .bold()
                    }
                }

                Spacer()
            }
        }
    }
}

#Preview {
    HomeView()
}
