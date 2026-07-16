# Klass Monorepo

Klass is an educational content generation and management platform focused on the Indonesian education market. 
It enables teachers to generate learning materials (PDF, DOCX, PPTX) using AI-powered LLM interpretation and content drafting, with a marketplace for freelance educational content creators.

## Project Structure

This monorepo contains the following core components:
- `gateway/` (Rust): The core orchestrator API gateway (Axum, SQLx).
- `frontend/` (Flutter): The mobile application client (iOS/Android).
- `media-generator-service/` (FastAPI): Document renderer for PDF, DOCX, and PPTX formats.
- `llm-adapter-service/` (FastAPI): Fallback LLM adapter service.

Please see the respective directories for more details on each component.
