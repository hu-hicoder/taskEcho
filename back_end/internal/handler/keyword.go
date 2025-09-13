package handler

import (
	"net/http"
)

// keywordを
func KeywordHandler(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("Keyword handler"))
}
