# Local AI Resume Reviewer (iOS + Supabase + n8n + Gemini)

A local, event-driven AI Resume Reviewer app built for iOS that accepts copy-pasted text, PDFs, or screenshots and delivers detailed, actionable career feedback in under 3 seconds.

## 📱 App Preview

https://youtu.be/oRiscj2zaUE


## 🏗️ System Architecture
The app uses an event-driven architecture to keep the client lightweight and reactive:

```mermaid
graph TD
    A[iOS App Client] -->|1. Upload PDF/Image| B(Supabase Storage)
    B -->|2. Insert Row| C(Supabase Database)
    C -->|3. Trigger Webhook| D[n8n Automation Canvas]
    D -->|4. Download File| B
    D -->|5. Extract Text| E[Extract from File Node]
    E -->|6. Review Resume| F(Google Gemini 1.5 Flash)
    F -->|7. Save Feedback| C
    C -->|8. Push Realtime Updates| A
