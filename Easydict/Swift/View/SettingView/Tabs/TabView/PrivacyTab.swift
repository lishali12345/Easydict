//
//  PrivacyTab.swift
//  Easydict
//
//  Created by Kyle on 2023/10/30.
//  Copyright © 2023 izual. All rights reserved.
//

import SwiftUI

struct PrivacyTab: View {
    var body: some View {
        Form {
            Section {
                Text("setting.privacy.telemetry_disabled")
                    .font(.body)
                    .multilineTextAlignment(.leading)
            } header: {
                Text("privacy_statement")
            }
        }
        .formStyle(.grouped)
    }
}

#Preview {
    PrivacyTab()
}
