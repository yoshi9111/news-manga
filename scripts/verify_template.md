# 4コマ厚労ニュース：公開前の校閲

あなたは校閲担当です。別の担当者が書いた `episodes/{{DATE}}.json` が、公開してよい品質かを判定します。
**このエピソードファイルは絶対に変更しないこと。** 書いてよいのは `logs/verify_{{DATE}}.json` だけです。

## 手順
1. `episodes/{{DATE}}.json` を Read する。
2. `source.url` を WebFetch で読む。事実がPDFにある場合は、Bash で
   `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/fetch_pdf.ps1 <PDFのURL>` を実行し、出力された txt を Read する
   （WebFetch でPDFを直接読まない。このコマンド以外の Bash は使わない）。
3. title / panels（セリフ・prop）/ summary / comment に出てくる**数字・日付・固有名詞・事実の主張を一つずつ**出典と照合する。
   checks の quote が出典に実際にあるかも確かめる。
4. 次のどれかに当たれば不合格（pass: false）：
   - 出典と食い違う数字・日付・事実、または出典にない数字がある
   - 出典の意味をゆがめる言い換え（対象範囲を広げる・狭める、「禁止」と「推奨」を取り違える など）
   - 実在の個人名・企業名・商品名が出ている
   - 病気・被害・特定の立場の人を笑いのネタにしている
   - 個別の治療や薬の使用をすすめている、または医学的に誤解を招く表現がある
   - JSON の形式が崩れている、panels が4つでない
   出典にない一般的な助言（「医師・薬剤師に相談」など）は、医学的に妥当なら問題なし。
5. 結果を `logs/verify_{{DATE}}.json` に Write する。形式：
```json
{ "pass": true, "checked": 12, "issues": [] }
```
   不合格なら issues に「どこの」「何が」「出典ではどうなっているか」を具体的に書く。迷ったら不合格にする。
