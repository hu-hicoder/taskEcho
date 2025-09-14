package service

import (
	"context"
	"fmt"

	"google.golang.org/genai"
)

// Gemini APIで要約を取得する（公式SDKドキュメント準拠）
func GetSummaryFromGeminiWithKey(text, keyword, apiKey string) (string, error) {
	if apiKey == "" {
		return "", fmt.Errorf("GEMINI_API_KEY is not set")
	}

	ctx := context.Background()
	client, err := genai.NewClient(ctx, &genai.ClientConfig{
		APIKey:  apiKey,
		Backend: genai.BackendGeminiAPI,
	})
	if err != nil {
		return "", fmt.Errorf("failed to create Gemini client: %v", err)
	}

	prompt := fmt.Sprintf("以下の文を%sについて要約してください: %s", keyword, text)
	result, err := client.Models.GenerateContent(
		ctx,
		"gemini-2.5-flash",
		genai.Text(prompt),
		nil,
	)
	if err != nil {
		return "", fmt.Errorf("failed to generate content: %v", err)
	}

	return result.Text(), nil
}
