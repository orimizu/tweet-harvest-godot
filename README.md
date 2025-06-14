# Twitter Bookmark to Markdown Converter (Godot版)

Chromeの拡張機能「Twitterのブックマークエクスポート」でエクスポートしたjsonを、Markdown形式に変換するGodotデスクトップアプリケーションです。
初期は、python の FLASK + HTML/Javascriptで書いていましたが、Godotに書き直しました。

## 主な機能

- 📝 Twitter/XのブックマークJSONファイルをMarkdown形式に変換
- 🤖 AIを使用したツイートの自動要約生成（50字以内の見出し）
- 🌐 複数のAIモデルに対応
  - OpenAI GPT-4o Mini
  - Anthropic Claude Sonnet 4
  - Google Gemini 2.5 Flash
  - Ollama（ローカルAI）
- 🎯 ドラッグ＆ドロップによる簡単な操作
- 🔧 Ollama設定画面でローカルAIの詳細設定が可能
- 💭 qwen3モデル向け思考トークン制御（think/nothink）
- 🌙 ダークモードUI（1280x800固定サイズ）

## 必要な環境

- Godot 4.4.1以降
- 各AIサービスのAPIキー（使用するサービスのみ）
- Ollama（ローカルAI使用時のみ）

## インストール

### 方法1: ビルド済みバイナリを使用（推奨）

1. [Releases](https://github.com/yourusername/twitter-bookmark-converter-godot/releases)から最新版をダウンロード
2. 実行ファイルを任意の場所に展開
3. アプリケーションを起動

### 方法2: ソースからビルド

1. リポジトリをクローン
```bash
git clone https://github.com/yourusername/twitter-bookmark-converter-godot.git
cd twitter-bookmark-converter-godot/godot_twitter_bookmark_converter
```

2. Godot 4.4.1でプロジェクトを開く
3. プロジェクト > エクスポート から任意のプラットフォーム向けにエクスポート

## セットアップ

### APIキーの設定

1. アプリケーションを初回起動すると、自動的にAPIキー設定ファイルのテンプレートが作成されます
2. 以下の場所にある `api_keys.cfg` を編集します：
   - Windows: `%APPDATA%\Godot\app_userdata\Twitter Bookmark Converter\api_keys.cfg`
   - macOS: `~/Library/Application Support/Godot/app_userdata/Twitter Bookmark Converter/api_keys.cfg`
   - Linux: `~/.local/share/godot/app_userdata/Twitter Bookmark Converter/api_keys.cfg`

3. 使用するAIサービスのAPIキーを設定：
```ini
[api_keys]
openai=""
anthropic=""
google=""
```

### Ollama設定（オプション）

ローカルAIを使用する場合：

1. [Ollama](https://ollama.ai/)をインストール
2. 使用したいモデルをダウンロード（例: `ollama pull qwen3:32b`）
3. アプリケーションの「⚙️ Ollama設定」ボタンをクリック
4. OllamaサーバーのURLを設定（デフォルト: http://localhost:11434）
5. 「接続確認」をクリックしてモデル一覧を取得
6. 使用するモデルを選択
7. qwen3系モデルの場合は思考トークン制御も設定可能
   - "nothink": 思考プロセスを出力しない（推奨）
   - "think": 思考プロセスを出力する

## 使い方

1. **アプリケーションを起動**

2. **JSONファイルをドロップ**
   - TwitterからエクスポートしたJSONファイルをドロップエリアにドラッグ＆ドロップ

3. **設定を選択**
   - AIモデル: 要約生成に使用するAIを選択
   - 埋め込み形式: 
     - "oembed あり": ツイートを埋め込み形式で表示
     - "oembed なし": テキストのみ表示

4. **変換を実行**
   - 「変換を開始」ボタンをクリック
   - 処理状況がステータスに表示されます

5. **結果を確認**
   - 「📁 出力フォルダを開く」で変換結果を確認
   - Markdownファイルは自動的に日付と連番で命名されます

## 出力ファイル

変換されたファイルは以下の構造で保存されます：

```
ユーザーデータディレクトリ/
├── out/
│   ├── bookmark/          # オリジナルのJSONファイル
│   ├── output2/           # 中間処理ファイル
│   └── markdown/          # 最終的なMarkdownファイル
├── tweet_url_dict.json    # 処理済みURL管理ファイル
├── api_keys.cfg          # API設定ファイル
└── ollama_config.json    # Ollama設定ファイル
```

### 出力Markdownの形式

```markdown
# twitter_summary_yyyymmddn

## [AIが生成した要約タイトル]

URL: https://twitter.com/username/status/xxxxx

[oembedまたはツイート本文]

---
```

## トラブルシューティング

### APIキーが認識されない
- api_keys.cfgファイルでキーの前後にクォートを付けていないか確認
- ファイルが正しい場所に保存されているか確認
- アプリケーションを再起動してみる

### Ollamaに接続できない
- Ollamaサービスが起動しているか確認（`ollama serve`）
- ファイアウォールがポート11434をブロックしていないか確認
- 正しいURLを設定しているか確認

### 思考トークンが表示される
- Ollama設定で「nothink」を選択しているか確認
- 最新版のアプリケーションを使用しているか確認

### 変換が遅い
- 処理するツイート数が多い場合は時間がかかります
- ローカルのOllamaモデルの方が高速な場合があります

## 開発者向け情報

詳細な仕様とアーキテクチャについては[Specification.md](Specification.md)を参照してください。

開発時のノウハウとトラブルシューティングは[CLAUDE.md](CLAUDE.md)にまとめています。

### プロジェクト構造

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
```

## ライセンス

MIT License

## 貢献

プルリクエストを歓迎します。大きな変更の場合は、まずissueを開いて変更内容について議論してください。

### 貢献方法

1. このリポジトリをフォーク
2. 機能ブランチを作成 (`git checkout -b feature/amazing-feature`)
3. 変更をコミット (`git commit -m 'Add some amazing feature'`)
4. ブランチにプッシュ (`git push origin feature/amazing-feature`)
5. プルリクエストを作成

## クレジット

- Godot Engine開発チーム
- 各AI APIプロバイダー

## 変更履歴

### v1.0.0 (2025-01-14)
- 初回リリース
- Flask版からGodot版への完全移植
- Ollama統合機能の追加
- 思考トークン制御機能の実装
- ダークモードUIの採用
