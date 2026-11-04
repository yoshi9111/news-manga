# 4コマ厚労ニュース（試作）

厚生労働省の新着情報から毎日1本を選び、薬剤師キャラ「ヤク先生」と「ミナ」の4コマ漫画にするサイト。
作画は画像生成AIを使わず、SVGキャラ（表情6種）＋吹き出し＋看板で組み立てる。

## 毎日の流れ
1. `scripts\run_daily.ps1` … 厚労省RSS取得 → Claude が1本選んで `episodes\YYYY-MM-DD.json`（下書き）を作成 → `site\data.js` を再生成 → ブラウザで表示
2. 人が確認：下書きには「根拠チェック」表（主張と出典の該当箇所）が出るので、出典と照合
3. `scripts\approve.ps1 YYYY-MM-DD` … 公開扱いにする
4. 「画像で保存」でPNG化 → Xなどに投稿

## フォルダ
- `site\` … サイト本体（index.html / style.css / app.js / data.js）。このフォルダをそのまま静的ホスティングすれば公開できる
- `episodes\` … 1日1ファイルの脚本JSON。手で直してから `scripts\build.ps1` でも反映できる
- `scripts\prompt_template.md` … Claude への脚本指示（キャラ・ルール・書式）
- `scripts\exclude_words.txt` … 候補から外すタイトルのキーワード
- `seen.txt` … 使用済みの出典URL（重複防止）
- `logs\` … 実行ログと当日のプロンプト

## 公開時の表示
- `file://` で開いたとき、または `?preview` を付けたときは下書きも表示
- サーバー上では `status: "approved"` の回だけ表示

## 自動実行
`scripts\register_task.ps1` を一度実行すると毎朝8:00に `run_daily.ps1` が動く。
