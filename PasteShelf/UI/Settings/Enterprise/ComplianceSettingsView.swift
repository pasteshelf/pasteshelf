//
//  ComplianceSettingsView.swift
//  PasteShelf
//
//  Container view for compliance settings, hosting HIPAA, GDPR, and SOC 2 sub-sections.
//

import SwiftUI

// MARK: - ComplianceSettingsView

/// Container view for the Compliance settings tab within Enterprise preferences.
///
/// Hosts placeholder sections for HIPAA, GDPR, and SOC 2 compliance tools.
/// Each section will be replaced by dedicated sub-views in subsequent phases.
struct ComplianceSettingsView: View {

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Label("Compliance", systemImage: "checkmark.shield.fill")
                        .font(.title2.bold())
                    Text("HIPAA, GDPR, and SOC 2 compliance tools for regulated industries.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Divider()

                // Placeholder sections — will be replaced by dedicated views
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("HIPAA Compliance", systemImage: "cross.case.fill")
                            .font(.headline)
                        Text("Enhanced audit logging, data retention controls, access controls, and encryption verification for HIPAA-regulated environments.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("GDPR Tools", systemImage: "person.badge.shield.checkmark.fill")
                            .font(.headline)
                        Text("Data export, data deletion, consent management, and privacy dashboard for GDPR compliance.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("SOC 2 Preparation", systemImage: "doc.badge.gearshape.fill")
                            .font(.headline)
                        Text("Security controls documentation, access control evidence, encryption verification, and audit trail exports.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }
            }
            .padding()
        }
    }
}

// MARK: - Previews

#if DEBUG
struct ComplianceSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ComplianceSettingsView()
            .frame(width: 600, height: 500)
    }
}
#endif
