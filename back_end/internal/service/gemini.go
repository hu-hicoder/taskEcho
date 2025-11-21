package service

import (
	"context"
	"fmt"

	"google.golang.org/genai"
)

// GeminiService 構造体を定義（これが不足していました）
type GeminiService struct {
    client *genai.Client
}

// NewGeminiService コンストラクタ（サービスの初期化）
func NewGeminiService(apiKey string) (*GeminiService, error) {
    if apiKey == "" {
        return nil, fmt.Errorf("GEMINI_API_KEY is not set")
    }

    ctx := context.Background()
    // クライアントを作成
    client, err := genai.NewClient(ctx, &genai.ClientConfig{
        APIKey:  apiKey,
        Backend: genai.BackendGeminiAPI,
    })
    if err != nil {
        return nil, fmt.Errorf("failed to create Gemini client: %v", err)
    }

    return &GeminiService{client: client}, nil
}

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

// GenerateEmbedding はテキストを受け取り、ベクトル(float32の配列)を返します
func (s *GeminiService) GenerateEmbedding(ctx context.Context, text string) ([]float32, error) {
    if s.client == nil {
        return nil, fmt.Errorf("gemini client is not initialized")
    }

    // モデル名は埋め込み専用の 'text-embedding-004' を使用します
    res, err := s.client.Models.EmbedContent(ctx, "text-embedding-004", genai.Text(text), nil)
    if err != nil {
        return nil, err
    }

    if len(res.Embeddings) == 0 {
        return nil, fmt.Errorf("embedding result is empty")
    }

    // 最初の埋め込み結果の Values を返す
    return res.Embeddings[0].Values, nil
}