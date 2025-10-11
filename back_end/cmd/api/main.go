package main

import (
	"log"
	"net/http"

	"taskEcho/back_end/internal/config"
	"taskEcho/back_end/router"
)

func main() {
	// 設定を初期化（.envファイルの読み込みも含む）
	cfg := config.New()
	log.Printf("Server configuration loaded. Gemini API Key available: %t", cfg.APIKey.Gemini != "")

	r := router.NewRouter()
	log.Printf("Server started at :%s", cfg.Server.Port)
	if err := http.ListenAndServe(":"+cfg.Server.Port, r); err != nil {
		log.Fatal(err)
	}
}
