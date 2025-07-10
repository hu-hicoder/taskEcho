package handler

import (
	"net/http"
)

// KeywordHandler は키워드 관련 처리를 담당하는 핸들러
func KeywordHandler(w http.ResponseWriter, r *http.Request) {
	// 키워드 처리 로직 구현 예정
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("Keyword handler"))
}
