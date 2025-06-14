# Godot移植プロジェクト 開発ノウハウ

## プロジェクト概要
Flask WebアプリケーションをGodot 4.4.1デスクトップアプリケーションに移植する際に得られた知見とノウハウをまとめます。

## 重要な学習事項

### 1. Godotにおける非同期処理

**問題**: HTTPリクエストをThreadで実行すると以下のエラーが発生
```
HTTPRequest can only be used from the main thread or in a thread group with PROCESS_GROUP_SUB_THREAD group order.
```

**解決策**: `await`を使用した非同期処理に変更
```gdscript
# NG: Threadベース
var thread = Thread.new()
thread.start(_convert_thread.bind(params))

# OK: awaitベース
await _convert_async(params)
```

### 2. ConfigFileでのAPIキー管理

**問題**: ConfigFile読み込みでエラー

#### OK(コメントが入っていない)

```ini
[api_keys]
anthropic="sk-ant-api123456"
```

#### NG(コメントが入っている)

```ini
[api_keys]
# Antropic API Key
anthropic="sk-ant-api123456"
```

**ベストプラクティス**: テンプレートファイルからコメントを削除しておく
```text
[api_keys]
openai=""
anthropic=""
google=""
```

### 3. UI更新のタイミング問題

**問題**: 別スレッドやコールバックからUI要素を直接更新すると失敗する

**解決策**: `call_deferred`を使用
```gdscript
# UIの安全な更新
call_deferred("_update_ui_success", data.models)

func _update_ui_success(models: Array):
    status_value.text = "接続OK"
    status_value.modulate = Color(0.3, 1, 0.3, 1)
```

### 4. OptionButtonの動作問題

**問題**: シーンファイルのtheme_overrideやWindow FLAGが干渉

**チェックポイント**:
1. シーンファイルでtheme_override_colorsが設定されていないか確認
2. Window.FLAG_ALWAYS_ON_TOPが設定されていないか確認
3. disabled属性が正しく設定されているか確認

### 5. 正規表現の制限

**問題**: Godotの正規表現では改行を含むパターンのマッチが困難

**解決策**: 文字列操作で実装
```gdscript
# 改行を含む<think>タグの削除
while true:
    var start_pos = result.find("<think>")
    if start_pos == -1:
        break
    var end_pos = result.find("</think>", start_pos)
    if end_pos == -1:
        result = result.substr(0, start_pos)
        break
    var before = result.substr(0, start_pos)
    var after = result.substr(end_pos + end_tag.length())
    result = before + after
```

### 6. 非同期関数の連鎖

**重要**: 非同期関数を呼び出す関数も非同期にする必要がある

```gdscript
func _ready():
    await _check_api_keys_config()
    await _load_ollama_settings()
    _populate_model_select()

func _check_api_keys_config() -> void:
    # 処理
    await _load_ollama_settings()

func _load_ollama_settings() -> void:
    # 処理
```

### 7. モデル固有の処理

**例**: qwen3モデルの思考トークン制御
```gdscript
if current_model.begins_with("ollama-") and current_model.replace("ollama-", "").begins_with("qwen3:"):
    var thinking_setting = _get_thinking_setting()
    prompt = thinking_setting + " " + prompt
```

### 8. デバッグのコツ

**repr()関数がない問題**:
```gdscript
# NG: Godotにrepr()はない
print("Text: ", repr(text))

# OK: 代替方法
print("Text preview: ", text.substr(0, 100).replace("\n", "\\n"))
```

### 9. シグナルの引数変更

**重要**: シグナルの引数を変更する際は、connectしている全ての箇所を更新

```gdscript
# 変更前
signal settings_saved(url: String, model: String)

# 変更後
signal settings_saved(url: String, model: String, thinking: String)

# 呼び出し側も更新
ollama_settings_window.settings_saved.connect(_on_ollama_settings_saved)
func _on_ollama_settings_saved(url: String, model: String, thinking: String):
```

### 10. ファイルパスの扱い

**Godotのファイルシステム**:
- `res://` - プロジェクトリソース（読み取り専用）
- `user://` - ユーザーデータディレクトリ（読み書き可能）

```gdscript
# ユーザーディレクトリの取得
var user_dir = OS.get_user_data_dir()

# グローバルパスへの変換
var global_path = ProjectSettings.globalize_path("user://api_keys.cfg")
```

## 推奨開発フロー

1. **UIファースト**: まずシーンファイル（.tscn）でUIを構築
2. **スクリプト実装**: GDScriptでロジックを実装
3. **非同期処理**: HTTPリクエストは必ずawaitパターンで実装
4. **設定管理**: ConfigFileまたはJSONファイルで永続化
5. **エラーハンドリング**: 各API呼び出しで適切なエラー処理
6. **デバッグログ**: 重要な処理には必ずprint文を入れる

## トラブルシューティング

### Q: UIが更新されない
A: `call_deferred`を使用しているか確認

### Q: HTTPリクエストがエラーになる
A: メインスレッドで実行されているか、awaitを使用しているか確認

### Q: OptionButtonが反応しない
A: シーンファイルのtheme_overrideやWindow設定を確認

### Q: 設定が保存されない
A: ファイルパスが正しいか、FileAccess.WRITEモードか確認

### Q: シグナルが受信されない
A: connectが正しく行われているか、引数の数が一致しているか確認

## 今後の改善案

1. **プログレスバー**: 大量のツイート処理時の進捗表示
2. **キャンセル機能**: 長時間の処理を中断する機能
3. **バッチ処理**: 複数のJSONファイルを一括処理
4. **エクスポート形式の追加**: PDF、HTML等への出力対応
5. **カスタムプロンプト**: ユーザーがAIプロンプトをカスタマイズ可能に