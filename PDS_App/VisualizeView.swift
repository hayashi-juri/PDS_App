//
//  DataVisualize.swift
//  PDS_App
//
//  Created by Juri Hayashi on 2025/01/10.
//

import SwiftUI

struct VisualizeView: View {
    @ObservedObject var firestoreManager: FirestoreManager

    var body: some View {
        VStack {
            Text("Your Progress")
                .font(.title)
                .padding()

            List(firestoreManager.healthDataItems) { item in
                HStack {
                    Text(item.type)
                    Spacer()
                    Text("\(item.value, specifier: "%.2f")")
                        .foregroundColor(.blue)
                    Text(item.date, style: .date)
                        .foregroundColor(.gray)
                }
            }
        }
    }
}

