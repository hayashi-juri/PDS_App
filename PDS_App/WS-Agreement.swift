//
//  WS-Agreement.swift
//  PDS_App
//
//  Created by Juri Hayashi on 2025/01/06.
//

import Foundation

struct WS_Agreement {
    struct DataSetting {
        let id = UUID()
        var identifier: String
        var displayName: String
        var groupID: String
        var anonymity: Bool
        var deletionDate: Date

        init(identifier: String, displayName: String, groupID: String, anonymity: Bool, deletionDate: Date) {
            self.identifier = identifier
            self.displayName = displayName
            self.groupID = groupID
            self.anonymity = anonymity
            self.deletionDate = deletionDate
        }
    }

    static let defaultSettings: [DataSetting] = [
        DataSetting(
            identifier: "stepCount",
            displayName: "歩数",
            groupID: "GroupA",
            anonymity: false,
            deletionDate: Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
        ),
        DataSetting(
            identifier: "distanceWalkingRunning",
            displayName: "歩行/ランニング距離",
            groupID: "GroupA",
            anonymity: false,
            deletionDate: Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
        ),
        DataSetting(
            identifier: "basalEnergyBurned",
            displayName: "基礎代謝エネルギー",
            groupID: "GroupA",
            anonymity: true,
            deletionDate: Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
        ),
        DataSetting(
            identifier: "activeEnergyBurned",
            displayName: "アクティブエネルギー",
            groupID: "GroupB",
            anonymity: true,
            deletionDate: Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
        ),
        DataSetting(
            identifier: "appleMoveTime",
            displayName: "ムーブタイム",
            groupID: "GroupB",
            anonymity: false,
            deletionDate: Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
        ),
        DataSetting(
            identifier: "appleStandTime",
            displayName: "スタンドタイム",
            groupID: "Public",
            anonymity: false,
            deletionDate: Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
        ),
        DataSetting(
            identifier: "sleepAnalysis",
            displayName: "睡眠解析",
            groupID: "GroupA",
            anonymity: true,
            deletionDate: Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
        )
    ]
}


