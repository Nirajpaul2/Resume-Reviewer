//
//  ResumeReviewApp.swift
//  ResumeReview
//
//  Created by Niraj Paul on 28/06/26.
//

import SwiftUI
import Supabase
import PhotosUI
import UniformTypeIdentifiers

// Initialize Supabase Client
let supabaseURL = URL(string: "YOUR_SUPABASE_URL")!
let supabaseKey = "YOUR_SUPABASE_ANON_KEY"
let supabase = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: supabaseKey)

struct ContentView: View {
    @State private var inputMode: Int = 0 // 0: Upload File, 1: Paste Text
    @State private var resumeText: String = ""
    
    // File upload states
    @State private var fileData: Data? = nil
    @State private var fileName: String = ""
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var showFileImporter: Bool = false
    
    @State private var feedback: String = ""
    @State private var status: String = "idle" // 'idle', 'uploading', 'reviewing', 'completed', 'failed'
    @State private var activeChannel: RealtimeChannelV2? = nil
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // 1. Status Indicator Header
                    statusHeaderView
                        .padding(.top, 12)
                    
                    // 2. Custom Segmented Controller for Input Modes
                    Picker("Input Method", selection: $inputMode) {
                        Text("Upload Document").tag(0)
                        Text("Paste Text").tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    
                    // 3. Main Input Cards
                    if inputMode == 0 {
                        uploadDocumentCard
                            .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .move(edge: .trailing).combined(with: .opacity)))
                    } else {
                        pasteTextCard
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                    }
                    
                    // 4. Action Button
                    Button(action: {
                        Task {
                            await submitResumeForReview()
                        }
                    }) {
                        HStack {
                            if status == "uploading" || status == "reviewing" {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .padding(.trailing, 8)
                            }
                            Text(buttonText)
                                .font(.headline)
                                .bold()
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isButtonDisabled ? Color.gray : Color.blue)
                        .cornerRadius(16)
                        .shadow(color: isButtonDisabled ? Color.clear : Color.blue.opacity(0.3), radius: 8, y: 4)
                    }
                    .disabled(isButtonDisabled)
                    .padding(.horizontal)
                    
                    // 5. Feedback Display Area (Formatted Card)
                    if !feedback.isEmpty {
                        feedbackCard
                            .padding(.horizontal)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    Spacer()
                }
                .padding(.bottom, 24)
            }
            .navigationTitle("Resume Reviewer")
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: inputMode)
            .animation(.easeInOut, value: status)
            .animation(.easeInOut, value: feedback)
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [UTType.pdf],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result: result)
            }
            .onChange(of: selectedPhotoItem) { newItem in
                handlePhotoSelection(newItem: newItem)
            }
            .onAppear {
                subscribeToChanges()
            }
        }
    }
    
    // MARK: - Subviews
    
    // Status Header View
    private var statusHeaderView: some View {
        HStack(spacing: 8) {
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
                .font(.system(size: 18, weight: .bold))
            Text(statusMessage)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(statusColor.opacity(0.1))
        .cornerRadius(30)
    }
    
    // Card for PDF & Photo Upload Zone
    private var uploadDocumentCard: some View {
        VStack(spacing: 16) {
            if fileData != nil {
                // File Selected State
                HStack(spacing: 16) {
                    Image(systemName: fileName.hasSuffix(".pdf") ? "doc.richtext.fill" : "photo.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(fileName)
                            .font(.headline)
                            .lineLimit(1)
                        Text("\(Double(fileData?.count ?? 0) / 1024.0 / 1024.0, specifier: "%.2f") MB")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: clearSelectedFile) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.title3)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                )
            } else {
                // Empty State Drop Zone
                VStack(spacing: 20) {
                    Image(systemName: "doc.viewfinder.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    
                    Text("Select your resume file")
                        .font(.headline)
                    
                    Text("Supports PDF, screenshots, or photos of resumes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    HStack(spacing: 16) {
                        // PDF Selector
                        Button(action: { showFileImporter = true }) {
                            HStack {
                                Image(systemName: "doc.fill")
                                Text("Choose PDF")
                            }
                            .font(.subheadline)
                            .bold()
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(12)
                        }
                        
                        // Photos Selector
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                            HStack {
                                Image(systemName: "photo")
                                Text("Select Photo")
                            }
                            .font(.subheadline)
                            .bold()
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                            .background(Color.purple.opacity(0.1))
                            .foregroundColor(.purple)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.vertical, 32)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round, miterLimit: 10, dash: [6, 4]))
                )
            }
        }
        .padding(.horizontal)
    }
    
    // Card for Text Input
    private var pasteTextCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Paste your resume text here:")
                .font(.headline)
                .foregroundColor(.secondary)
            
            TextEditor(text: $resumeText)
                .frame(height: 200)
                .padding(8)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
        }
        .padding(.horizontal)
    }
    
    // Feedback Display Card
    private var feedbackCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.yellow)
                    .font(.title2)
                Text("AI Review Feedback")
                    .font(.title3)
                    .bold()
                Spacer()
            }
            
            Divider()
            
            ScrollView {
                Text(feedback)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(4)
            }
            .frame(maxHeight: 400)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
    
    // MARK: - Logic Helpers
    
    private var buttonText: String {
        switch status {
        case "uploading": return "Uploading..."
        case "reviewing": return "Reviewing with AI..."
        default: return "Submit for Review"
        }
    }
    
    private var isButtonDisabled: Bool {
        if status == "uploading" || status == "reviewing" {
            return true
        }
        if inputMode == 0 {
            return fileData == nil
        } else {
            return resumeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
    
    private var statusIcon: String {
        switch status {
        case "uploading": return "arrow.up.circle.fill"
        case "reviewing": return "brain.head.profile"
        case "completed": return "checkmark.circle.fill"
        case "failed": return "exclamationmark.triangle.fill"
        default: return "doc.text.magnifyingglass"
        }
    }
    
    private var statusColor: Color {
        switch status {
        case "uploading", "reviewing": return .orange
        case "completed": return .green
        case "failed": return .red
        default: return .blue
        }
    }
    
    private var statusMessage: String {
        switch status {
        case "uploading": return "Uploading file to server..."
        case "reviewing": return "AI is analyzing your resume..."
        case "completed": return "Review complete! See feedback below."
        case "failed": return "Analysis failed. Please try again."
        default: return "Ready to scan your resume"
        }
    }
    
    // MARK: - Actions & Handlers
    
    private func clearSelectedFile() {
        self.fileData = nil
        self.fileName = ""
        self.selectedPhotoItem = nil
    }
    
    // Handle photos pick
    private func handlePhotoSelection(newItem: PhotosPickerItem?) {
        guard let newItem = newItem else { return }
        Task {
            if let data = try? await newItem.loadTransferable(type: Data.self) {
                DispatchQueue.main.async {
                    self.fileData = data
                    self.fileName = "screenshot_\(Int(Date().timeIntervalSince1970)).png"
                }
            }
        }
    }
    
    // Handle PDF imports
    private func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            
            if let data = try? Data(contentsOf: url) {
                self.fileData = data
                self.fileName = url.lastPathComponent
            }
        case .failure(let error):
            print("File selection error: \(error)")
        }
    }
    
    // Submit for review action
    func submitResumeForReview() async {
        status = "uploading"
        feedback = ""
        
        var uploadPath: String? = nil
        
        // Upload File if in File upload mode
        if inputMode == 0, let data = fileData {
            let uniqueId = UUID().uuidString
            let extensionName = fileName.hasSuffix(".pdf") ? "pdf" : "png"
            let targetPath = "\(uniqueId).\(extensionName)"
            
            do {
                _ = try await supabase.storage
                    .from("resumes")
                    .upload(path: targetPath, file: data)
                
                uploadPath = targetPath
            } catch {
                print("Upload failed: \(error)")
                status = "failed"
                feedback = "Failed to upload file to storage: \(error.localizedDescription)"
                return
            }
        }
        
        // Insert record to DB table
        var newReview: [String: String] = ["status": "pending"]
        if inputMode == 1 {
            newReview["resume_text"] = resumeText
        } else if let path = uploadPath {
            newReview["file_path"] = path
        }
        
        do {
            try await supabase.database
                .from("resume_reviews")
                .insert(newReview)
                .execute()
            
            status = "reviewing"
        } catch {
            print("Database insert failed: \(error)")
            status = "failed"
            feedback = "Failed to insert into database: \(error.localizedDescription)"
        }
    }
    
    // Subscribe to Postgres Realtime events
    func subscribeToChanges() {
        let channel = supabase.channel("reviews_channel")
        
        let changeStream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "resume_reviews"
        )
        
        Task {
            try? await channel.subscribe()
            
            for await change in changeStream {
                switch change {
                case .update(let action):
                    do {
                        let updatedRecord = try action.decodeRecord(as: ResumeReview.self, decoder: JSONDecoder())
                        DispatchQueue.main.async {
                            if updatedRecord.status == "completed" {
                                self.feedback = updatedRecord.review_feedback ?? "No feedback provided."
                                self.status = "completed"
                            } else if updatedRecord.status == "failed" {
                                self.status = "failed"
                                self.feedback = "AI Review failed."
                            }
                        }
                    } catch {
                        print("Decoding error: \(error)")
                    }
                default:
                    break
                }
            }
        }
        
        self.activeChannel = channel
    }
}
