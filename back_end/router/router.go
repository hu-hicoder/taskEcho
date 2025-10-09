package router

import (
	"net/http"
	"taskEcho/back_end/internal/handler"
	"taskEcho/back_end/internal/middleware"

	"github.com/gorilla/mux"
)

func NewRouter() *mux.Router {
	r := mux.NewRouter()

	// CORSミドルウェアを全体に適用
	r.Use(middleware.CORSHandler)

	// 要約エンドポイント
	r.HandleFunc("/summarize", middleware.Authenticate(handler.SummarizeHandler)).Methods(http.MethodPost)

	return r
}
