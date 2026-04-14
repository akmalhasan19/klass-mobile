# Klass Project Overview

This workspace contains the codebase for **Klass**, a multi-service application likely aimed at educational content or personalized project recommendations. It consists of a Laravel backend, a Flutter mobile frontend, and two specialized Python FastAPI services for LLM integration and media generation.

## Project Architecture

The project is structured into four main components:

1.  **`backend/` (Laravel/PHP):** The core backend API. It manages users, subjects, topics, and the "Homepage Configurator" for personalized project recommendations. It acts as the central orchestrator, communicating with the specialized Python services.
2.  **`frontend/` (Flutter/Dart):** The mobile application client (iOS/Android). It consumes the backend API to display feeds like the "Homepage Recommendation Feed".
3.  **`llm-adapter-service/` (FastAPI/Python):** A dedicated service that serves as the single boundary for LLM interactions (supporting Gemini and OpenAI). It handles request validation, semantic caching, rate limiting, budget governance, and cost tracking using a PostgreSQL database.
4.  **`media-generator-service/` (FastAPI/Python):** A service responsible for rendering learning materials into various formats (.docx, .pdf, .pptx) based on specifications provided by the Laravel backend. It uses tools like `python-docx`, `reportlab`, and `python-pptx`.

## Building and Running

### Backend (Laravel)
*   **Directory:** `backend/`
*   **Tests:** Run tests using Artisan:
    ```bash
    php artisan test --testdox
    ```
*   **Note:** The backend relies on a database (migrations and seeders are present).

### Frontend (Flutter)
*   **Directory:** `frontend/`
*   **Running:** Run the app specifying the backend API URL:
    ```bash
    flutter run --dart-define=API_BASE_URL=http://<BACKEND_IP>:8000/api
    ```
*   **Tests:** Run Flutter tests:
    ```bash
    flutter test -r expanded
    ```

### LLM Adapter Service (FastAPI)
*   **Directory:** `llm-adapter-service/`
*   **Setup:** Install dependencies: `pip install -r requirements.txt`
*   **Database:** Requires a separate PostgreSQL database. Run migrations: `python -m app.database migrate`
*   **Running:** Start the development server: `uvicorn app.main:app --reload`
*   **Deployment:** Designed to be deployed as a Docker-based Hugging Face Space.

### Media Generator Service (FastAPI)
*   **Directory:** `media-generator-service/`
*   **Setup:** Install dependencies: `pip install -r requirements.txt`
*   **Running:** Start the development server: `uvicorn app.main:app --reload`
*   **Deployment:** Designed to be deployed as a Docker-based Hugging Face Space.

## Development Conventions & Inter-Service Communication

*   **Authentication (Service-to-Service):** Communication between the Laravel backend and the Python services (`llm-adapter-service` and `media-generator-service`) is secured using timestamped HMAC SHA-256 signatures via shared secrets.
*   **LLM Adapter Caching & Governance:** The LLM adapter extensively uses PostgreSQL for caching responses and enforcing rate limits and daily cost budgets per route.
*   **Media Generation Flow:** The Laravel backend determines the business logic and final export type, then sends a signed specification payload to the `media-generator-service`, which acts as a "dumb" renderer and returns a signed download URL for the artifact.
*   **Code Quality:** The backend has configurations for `styleci` and `phpunit`. The frontend uses standard Dart analysis (`analysis_options.yaml`). The Python services use `pytest` for testing.