package config

import (
	"os"
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

	return &Config{
		Server: ServerConfig{
			Port: getEnv("SERVER_PORT", "8080"),
		},
		APIKey: APIKeyConfig{
			Gemini: getEnv("GEMINI_API_KEY", ""),
		},
	}
}
