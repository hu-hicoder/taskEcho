package model

// Gemini APIリクエスト用構造体
type GeminiRequest struct {
	Contents []Contents `json:"contents"`
}

type Contents struct {
	Parts []Parts `json:"parts"`
}

type Parts struct {
	Text string `json:"text"`
}

// Gemini APIレスポンス用構造体
type GeminiResponse struct {
	Candidates []Candidate `json:"candidates"`
}

type Candidate struct {
	Content Content `json:"content"`
}

type Content struct {
	Parts []ResponsePart `json:"parts"`
}

type ResponsePart struct {
	Text    string `json:"text"`
	Keyword string `json:"keyword"`
}
