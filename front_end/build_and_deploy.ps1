# 環境変数を読み込む
$envFile = "web\.env"
if (Test-Path $envFile) {
    $GEMINI_API_KEY = ""
    $GOOGLE_CLIENT_ID = ""
    
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^GEMINI_API_KEY=(.+)$') {
            $GEMINI_API_KEY = $matches[1]
        }
        if ($_ -match '^GOOGLE_CLIENT_ID=(.+)$') {
            $GOOGLE_CLIENT_ID = $matches[1]
        }
    }
} else {
    Write-Host "Error: .env file not found at $envFile" -ForegroundColor Red
    exit 1
}

Write-Host "Building Flutter web with environment variables..." -ForegroundColor Cyan

# ビルド時に環境変数を埋め込む
flutter build web --release `
  --dart-define=GEMINI_API_KEY=$GEMINI_API_KEY `
  --dart-define=GOOGLE_CLIENT_ID=$GOOGLE_CLIENT_ID

# OGP画像をコピー
if (Test-Path "web\og-image.png") {
    Copy-Item "web\og-image.png" "build\web\og-image.png" -Force
    Write-Host "Copied OGP image" -ForegroundColor Green
}

Write-Host "Build complete!" -ForegroundColor Green