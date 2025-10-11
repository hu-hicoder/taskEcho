package middleware

import (
	"net/http"
)

// CORSHandler はCORS（Cross-Origin Resource Sharing）を処理するミドルウェア
func CORSHandler(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// CORSヘッダーを設定
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Requested-With")
		w.Header().Set("Access-Control-Allow-Credentials", "true")

		// プリフライトリクエスト（OPTIONS）の場合は200を返して終了
		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}

		// 次のハンドラーを呼び出し
		next.ServeHTTP(w, r)
	})
}
