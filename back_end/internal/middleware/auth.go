package middleware

import (
	"net/http"
)

// Authenticate は認証ミドルウェア（テスト用に簡単に実装）
func Authenticate(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		// テスト用に認証をスキップ
		next(w, r)
	}
}
