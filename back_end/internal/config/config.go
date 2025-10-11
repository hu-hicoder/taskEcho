package config

import (
	"log"
	"os"

	"github.com/joho/godotenv"
)

// Config はアプリケーション設定を管理する構造体
type Config struct {
	Server ServerConfig
	APIKey APIKeyConfig
}

// ServerConfig はサーバー設定
type ServerConfig struct {
	Port string
}

// APIKeyConfig はAPIキー設定
type APIKeyConfig struct {
	Gemini string
}

// getEnv は環境変数を取得し、存在しない場合はデフォルト値を返す
func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

// New は新しい設定を作成する
func New() *Config {
	// 複数のパスで.envファイルを試行
	envPaths := []string{
		"../../assets/.env", // cmd/api/ から back_end/assets/.env への相対パス
		"./assets/.env",     // back_end/ ディレクトリから実行される場合
		"/Users/mikayu/developing/taskEcho/back_end/assets/.env", // 絶対パス（フォールバック）
	}

	var err error
	var loaded bool

	for _, envPath := range envPaths {
		if err = godotenv.Load(envPath); err == nil {
			log.Printf("Successfully loaded .env from: %s", envPath)
			loaded = true
			break
		}
	}

	if !loaded {
		log.Printf("No .env file found or failed to load")
	}

	apiKey := getEnv("GEMINI_API_KEY", "")
	if apiKey == "" {
		log.Println("Warning: GEMINI_API_KEY is not set")
	} else {
		log.Printf("GEMINI_API_KEY loaded successfully (length: %d)", len(apiKey))
	}

	return &Config{
		Server: ServerConfig{
			Port: getEnv("SERVER_PORT", "8080"),
		},
		APIKey: APIKeyConfig{
			Gemini: apiKey,
		},
	}
}
