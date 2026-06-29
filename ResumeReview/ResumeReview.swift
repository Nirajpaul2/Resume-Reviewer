//
//  ResumeReviewApp.swift
//  ResumeReview
//
//  Created by Niraj Paul on 28/06/26.
//

import Foundation

struct ResumeReview: Codable, Identifiable {
    let id: UUID
    let resume_text: String?
    let file_path: String?
    let review_feedback: String?
    let status: String
    let created_at: String
}

