package main

import (
	"log"
	"net/http"

	"taskEcho/back_end/router"

	"github.com/joho/godotenv"
)

func main() {
	// .envファイルの読み込み
	err := godotenv.Load("assets/.env")
	if err != nil {
		log.Println("No .env file found or failed to load")
	}

	r := router.NewRouter()
	log.Println("Server started at :8080")
	if err := http.ListenAndServe(":8080", r); err != nil {
		log.Fatal(err)
	}
}
