package router

import (
	"log"	
	"net/http"
	"os"	
	"taskEcho/back_end/internal/handler"
	"taskEcho/back_end/internal/middleware"
	"taskEcho/back_end/internal/service"

	"github.com/gorilla/mux"
)

func NewRouter() *mux.Router {
	r := mux.NewRouter()

	// CORSミドルウェアを全体に適用
	r.Use(middleware.CORSHandler)

	// --- 1. サービスの初期化 ---
	// 環境変数からAPIキーを取得 (main.goでconfigが読み込まれている前提)
	apiKey := os.Getenv("GEMINI_API_KEY")
  
	// Geminiサービスのインスタンス作成
	geminiService, err := service.NewGeminiService(apiKey)
	if err != nil {
		// APIキーがない場合などはログを出して続行（該当機能を使うとエラーになります）
		log.Printf("Warning: Failed to initialize GeminiService: %v", err)
	}

	// --- 2. ハンドラーの初期化 ---
	// 作成したサービスをハンドラーに渡します
	embeddingHandler := handler.NewEmbeddingHandler(geminiService)

	// --- 3. ルーティング登録 ---	
	// 要約エンドポイント
	r.HandleFunc("/summarize", middleware.Authenticate(handler.SummarizeHandler)).Methods(http.MethodPost)

	// 2. ベクトル化エンドポイント
	r.HandleFunc("/api/encode", middleware.Authenticate(embeddingHandler.HandleEncode)).Methods(http.MethodPost)
	r.HandleFunc("/api/encode", func(w http.ResponseWriter, r *http.Request) {
		// middleware.CORSHandler がヘッダーをセットしてくれるので、ここではOKを返すだけで良い
		w.WriteHeader(http.StatusOK)
	}).Methods(http.MethodOptions)

	return r
}
