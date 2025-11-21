package handler

import (
    "net/http"
    "taskEcho/back_end/internal/service" // パッケージ名は環境に合わせてください
    "encoding/json"
)

type EmbeddingRequest struct {
    Text string `json:"text"`
}

type EmbeddingResponse struct {
    Embedding []float32 `json:"embedding"`
}

type EmbeddingHandler struct {
    Service *service.GeminiService
}

func NewEmbeddingHandler(s *service.GeminiService) *EmbeddingHandler {
    return &EmbeddingHandler{Service: s}
}

func (h *EmbeddingHandler) HandleEncode(w http.ResponseWriter, r *http.Request) {
    // CORS対応 (必要であれば)
    w.Header().Set("Access-Control-Allow-Origin", "*")
    w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
    if r.Method == "OPTIONS" {
        return
    }

    var req EmbeddingRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        http.Error(w, "Invalid request body", http.StatusBadRequest)
        return
    }

    embedding, err := h.Service.GenerateEmbedding(r.Context(), req.Text)
    if err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(EmbeddingResponse{Embedding: embedding})
}