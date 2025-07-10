package service

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"

	"google.golang.org/genai"
	"google.golang.org/api/option"

	"taskEcho/back_end/assets"
	"taskEcho/back_end/router"
)

func GetGeminiAPIKey() string {
	return os.Getenv("GEMINI_API_KEY")
}

func GetSummaryFromGemini(prompt string) (string, error) {
	apiKey := GetGeminiAPIKey()
	if apiKey == "" {
		return "", fmt.Errorf("GEMINI_API_KEY is not set")
	}

	ctx := context.Background()
	client, err := genai.NewClient(ctx, option.WithAPIKey(apiKey))
	if err != nil {
		return "", err
	}
	defer client.Close()

	model := client.GenerativeModel("gemini-2.5-flash")
	resp, err := model.GenerateContent(ctx, genai.Text(prompt))
	if err != nil {
		return "", err
	}

	// 結果の取り出し
	if len(resp.Candidates) > 0 && len(resp.Candidates[0].Content.Parts) > 0 {
		if textPart, ok := resp.Candidates[0].Content.Parts[0].(genai.TextPart); ok {
			return textPart.Text, nil
		}
	}

	return "", fmt.Errorf("no summary returned")
}