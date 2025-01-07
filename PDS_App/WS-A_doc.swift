//
//  WS-agreement.swift
//  PDS_App
//
//  Created by Juri Hayashi on 2025/01/06.
//

import Foundation

let wsAgreement: [String: Any] = [
    "name": "Data Sharing Agreement",
    "context": [
        "agreementInitiator": "User123",
        "agreementResponder": "DataService",
        "expirationTime": "2025-12-31T23:59:59Z"
    ],
    "terms": [
        "serviceDescriptionTerm": [
            "dataType": "HealthKit",
            "sharingScope": [
                "groupID": "GroupA",
                "anonymity": "Anonymous"
            ]
        ]
    ]
]

