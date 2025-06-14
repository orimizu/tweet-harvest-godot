# Twitter Bookmark to Markdown Converter (Godot版) 仕様書

## 概要

本アプリケーションは、Twitter（X）のブックマークデータ（JSON形式）をMarkdown形式に変換するデスクトップアプリケーションです。元々Flask Webアプリケーションとして実装されていたものを、Godot 4.4.1を使用してデスクトップアプリケーションとして移植しました。

## 主要機能

### 1. ブックマークJSONファイルの処理
- ドラッグ＆ドロップによるJSONファイルの読み込み
- 自動的なファイル名生成（日付＋連番）
- 重複URLのチェックと管理

### 2. AI要約機能
- 複数のAIモデルに対応
  - OpenAI GPT-4o Mini
  - Anthropic Claude Sonnet 4
  - Google Gemini 2.5 Flash
  - Ollama（ローカルAI）
- ツイート内容から50字以内の見出しを自動生成
- 英語ツイートの日本語翻訳

### 3. Markdown出力
- 構造化されたMarkdown形式での出力
- oembedによるツイート埋め込み対応
- ユーザーデータディレクトリへの自動保存

### 4. Ollama統合
- カスタムOllamaサーバーURL設定
- 動的なモデル一覧取得
- 思考トークン制御（think/nothink）
- 思考トークンの自動削除

## アーキテクチャ

### ディレクトリ構造

```
godot_twitter_bookmark_converter/
├── project.godot           # プロジェクト設定
├── scenes/                 # UIシーン
│   ├── Main.tscn          # メイン画面
│   └── OllamaSettings.tscn # Ollama設定画面
├── scripts/                # GDScript
│   ├── Main.gd            # メインコントローラー
│   ├── AIClient.gd        # AI API統合
│   ├── BookmarkConverter.gd # 変換ロジック
│   ├── FileManager.gd     # ファイル管理
│   └── OllamaSettings.gd  # Ollama設定管理
└── resources/             # リソースファイル
    └── dark_theme.tres    # UIテーマ
```

### クラス設計

#### Main.gd（メインコントローラー）
- **責務**: アプリケーション全体の制御とUI管理
- **主要機能**:
  - ファイルドロップの処理
  - AI選択と変換処理の開始
  - 設定画面の表示管理
  - ステータス表示の更新

#### AIClient.gd（AI APIクライアント）
- **責務**: 各種AI APIとの通信
- **主要機能**:
  - APIキーの管理
  - HTTPリクエストの送信
  - レスポンスの解析
  - 思考トークンの削除

#### BookmarkConverter.gd（変換エンジン）
- **責務**: JSONからMarkdownへの変換
- **主要機能**:
  - Twitter JSONの解析
  - Markdown形式への変換
  - URL重複チェック
  - ファイル出力

#### FileManager.gd（ファイル管理）
- **責務**: ファイル操作とディレクトリ管理
- **主要機能**:
  - ファイル名の生成
  - ディレクトリの作成
  - ファイルの読み書き

#### OllamaSettings.gd（Ollama設定）
- **責務**: Ollamaサーバーの設定管理
- **主要機能**:
  - 接続テスト
  - モデル一覧の取得
  - 設定の保存/読み込み
  - 思考トークン制御設定

## データフロー

1. **入力処理**
   ```
   ユーザー → JSONファイルドロップ → Main.gd → FileManager.gd → ファイル保存
   ```

2. **変換処理**
   ```
   Main.gd → BookmarkConverter.gd → JSONパース → 
   → AIClient.gd → AI API呼び出し → 要約生成 →
   → BookmarkConverter.gd → Markdown生成 → ファイル出力
   ```

3. **設定管理**
   ```
   OllamaSettings.gd → user://ollama_config.json → 
   → Main.gd → AIClient.gd
   ```

## 設定ファイル

### api_keys.cfg
```ini
[api_keys]
openai=sk-...
anthropic=sk-ant-api...
google=AIza...
```

### ollama_config.json
```json
{
    "url": "http://localhost:11434",
    "model": "qwq:32b",
    "thinking": "nothink"
}
```

### tweet_url_dict.json
処理済みURLを記録し、重複処理を防ぐ
```json
{
    "https://twitter.com/user/status/123": true,
    ...
}
```

## UI仕様

### メイン画面
- **サイズ**: 1280x800（固定）
- **背景色**: ダークグレー（#262626）
- **フォントサイズ**: 
  - タイトル: 48pt
  - ラベル: 24pt
  - ボタン: 26pt
  - ステータス: 24pt

### カラースキーム
- **プライマリ**: ダークブルー（#335980）
- **成功**: グリーン（#4DCC4D）
- **エラー**: レッド（#CC4D4D）
- **警告**: イエロー（#FFFF00）

### ボタンスタイル
- 角丸: 12px
- ホバーエフェクト: 明度+20%
- 押下エフェクト: 明度-20%

## 特殊処理

### qwen3モデル対応
- モデル名が "qwen3:" で始まる場合
- 思考トークン制御プレフィックスを追加
  - "think" 設定時: "think " + プロンプト
  - "nothink" 設定時: "nothink " + プロンプト

### 思考トークン削除
- `<think>...</think>` タグで囲まれた内容を自動削除
- 改行を含む複数行の思考トークンにも対応
- 全AI APIレスポンスに適用

### エラーハンドリング
- API接続エラー時の適切なメッセージ表示
- ファイル読み込みエラーの検出
- JSONパースエラーの処理

## 出力仕様

### ファイル配置
```
user://
├── out/
│   ├── bookmark/        # 入力JSONファイル
│   ├── output2/         # 中間処理ファイル
│   └── markdown/        # 最終Markdownファイル
└── tweet_url_dict.json  # URL管理ファイル
```

### Markdown形式
```markdown
# タイトル（日付）

## [AI生成タイトル]

URL: https://twitter.com/...

{oembed埋め込みまたはテキスト}

---
```

## パフォーマンス考慮事項

- HTTPリクエストは非同期処理（await）
- UI更新は`call_deferred`で安全に実行
- 大量のツイート処理時は進捗表示
- API呼び出しのタイムアウト設定（30秒）

## セキュリティ

- APIキーはローカルファイルに保存
- APIキーファイルにはコメントで注意事項記載
- ネットワーク通信はHTTPS（Ollama除く）
- ユーザーデータは`user://`に隔離保存
