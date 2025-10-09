package handler

import (
	"encoding/json"
	"log"
	"net/http"
	"taskEcho/back_end/internal/config"
	"taskEcho/back_end/internal/service"
	"taskEcho/back_end/internal/model"
)

// SummarizeHandler は要約リクエストを処理するハンドラー
// PUT /summarize
func SummarizeHandler(w http.ResponseWriter, r *http.Request) {
	log.Printf("受信したリクエスト: %s %s", r.Method, r.URL.Path)
	
	var req model.SummarizeRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		log.Printf("JSON解析エラー: %v", err)
		http.Error(w, "Invalid request", http.StatusBadRequest)
		return
	}
	
	log.Printf("要約リクエスト - テキスト長: %d, キーワード: %s", len(req.Text), req.Keyword)

	cfg := config.New()
	summary, err := service.GetSummaryFromGeminiWithKey(req.Text, req.Keyword, cfg.APIKey.Gemini)
	if err != nil {
		log.Printf("要約エラー: %v", err)
		http.Error(w, "Failed to summarize: "+err.Error(), http.StatusInternalServerError)
		return
	}

	log.Printf("要約完了 - 結果の長さ: %d", len(summary))
	resp := map[string]string{"summarized_text": summary}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(resp)
}
