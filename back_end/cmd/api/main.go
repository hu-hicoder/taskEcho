package main

import (
	"log"
	"net/http"

	"github.com/joho/godotenv"
	"taskEcho/back_end/router"
)

func main() {
	// .envファイルの読み込み
	err := godotenv.Load("assets/.env")
	if err != nil {
		log.Println("No .env file found or failed to load")
	}

	r := router.NewRouter()
	log.Println("Server started at :5000")
	if err := http.ListenAndServe(":5000", r); err != nil {
		log.Fatal(err)
	}
}