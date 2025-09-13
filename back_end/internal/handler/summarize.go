package handler

import (
	"encoding/json"
	"net/http"
	"taskEcho/back_end/internal/config"
	"taskEcho/back_end/internal/service"
	"taskEcho/back_end/internal/model"
)

// SummarizeHandler は要約リクエストを処理するハンドラー
// PUT /summarize
func SummarizeHandler(w http.ResponseWriter, r *http.Request) {
	var req model.SummarizeRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request", http.StatusBadRequest)
		return
	}

	cfg := config.New()
	summary, err := service.GetSummaryFromGeminiWithKey(req.Text, req.Keyword, cfg.APIKey.Gemini)
	if err != nil {
		http.Error(w, "Failed to summarize: "+err.Error(), http.StatusInternalServerError)
		return
	}

	resp := map[string]string{"summarized_text": summary}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(resp)
}
