//
//  ContactsTabView.swift
//  messagingapp
//
//  Tab view for displaying extracted contacts
//

import SwiftUI

struct ContactsTabView: View {
    @ObservedObject var viewModel: DataExtractionViewModel
    @State private var selectedContact: ExtractedContact?
    
    var body: some View {
        Group {
            if viewModel.contacts.isEmpty {
                DataExtractionEmptyView(
                    icon: "person.2",
                    title: "No Contacts Found",
                    message: "Contact information will appear here when detected in your conversation."
                )
            } else {
                List {
                    ForEach(viewModel.contacts) { contact in
                        ContactRow(contact: contact)
                            .onTapGesture {
                                selectedContact = contact
                            }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .sheet(item: $selectedContact) { contact in
            ContactDetailView(contact: contact, viewModel: viewModel)
        }
    }
}

// MARK: - Contact Row

struct ContactRow: View {
    let contact: ExtractedContact
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "person.circle.fill")
                .foregroundColor(.blue)
                .font(.title)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(contact.name)
                        .font(.headline)
                    
                    Spacer()
                    
                    ConfidenceBadge(confidence: contact.confidence)
                }
                
                if let company = contact.company {
                    HStack(spacing: 4) {
                        Image(systemName: "building.2")
                            .font(.caption)
                        Text(company)
                            .font(.subheadline)
                    }
                    .foregroundColor(.secondary)
                }
                
                if let email = contact.email {
                    HStack(spacing: 4) {
                        Image(systemName: "envelope")
                            .font(.caption)
                        Text(email)
                            .font(.subheadline)
                    }
                    .foregroundColor(.secondary)
                }
                
                if let phone = contact.phone {
                    HStack(spacing: 4) {
                        Image(systemName: "phone")
                            .font(.caption)
                        Text(phone)
                            .font(.subheadline)
                    }
                    .foregroundColor(.secondary)
                }
                
                Text(contact.context)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Contact Detail View

struct ContactDetailView: View {
    let contact: ExtractedContact
    @ObservedObject var viewModel: DataExtractionViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isExporting = false
    
    var body: some View {
        NavigationView {
            List {
                Section("Contact Information") {
                    DataDetailRow(icon: "person", label: "Name", value: contact.name)
                    
                    if let company = contact.company {
                        DataDetailRow(icon: "building.2", label: "Company", value: company)
                    }
                    
                    if let email = contact.email {
                        HStack {
                            Image(systemName: "envelope")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            
                            Text("Email")
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Link(email, destination: URL(string: "mailto:\(email)")!)
                                .fontWeight(.medium)
                        }
                    }
                    
                    if let phone = contact.phone {
                        HStack {
                            Image(systemName: "phone")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            
                            Text("Phone")
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Link(phone, destination: URL(string: "tel:\(phone)")!)
                                .fontWeight(.medium)
                        }
                    }
                }
                
                Section("Context") {
                    Text(contact.context)
                        .font(.body)
                }
                
                Section {
                    HStack {
                        Text("Confidence")
                        Spacer()
                        ConfidenceBadge(confidence: contact.confidence)
                    }
                }
                
                Section("Actions") {
                    Button(action: exportToContacts) {
                        HStack {
                            Image(systemName: "person.badge.plus")
                            Text("Add to Contacts")
                            
                            if isExporting {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isExporting)
                    
                    if let email = contact.email {
                        Button(action: {
                            UIPasteboard.general.string = email
                        }) {
                            HStack {
                                Image(systemName: "doc.on.doc")
                                Text("Copy Email")
                            }
                        }
                    }
                    
                    if let phone = contact.phone {
                        Button(action: {
                            UIPasteboard.general.string = phone
                        }) {
                            HStack {
                                Image(systemName: "doc.on.doc")
                                Text("Copy Phone")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Contact Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func exportToContacts() {
        isExporting = true
        Task {
            await viewModel.exportContact(contact)
            isExporting = false
            dismiss()
        }
    }
}

