#!/bin/bash
set -e

BASE_DIR="/app"
WORK_DIR="$BASE_DIR/build_work"
SYS_DIC_SRC="$WORK_DIR/sys_dic_src"
SYS_DIC_BIN="$WORK_DIR/sys_dic_bin"
USER_CSV="$WORK_DIR/user_dict.csv"
FINAL_DIC_DIR="$BASE_DIR/crates/sbv2_core/src/dic"

echo "=== Lindera 1.4.1 準拠: 2段階ビルドプロセス開始 ==="

# 1. ストレージの完全清掃
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR" "$SYS_DIC_SRC" "$SYS_DIC_BIN" "$FINAL_DIC_DIR"

# 2. Aivis ユーザー辞書 CSV の取得
echo "Step 1: Fetching Aivis dictionaries..."
TMP_GIT="$WORK_DIR/aivis_tmp"
git clone https://github.com/Aivis-Project/AivisSpeech-Engine "$TMP_GIT" --filter=blob:none -n
cd "$TMP_GIT"
git checkout 168b2a1144afe300b0490d9a6dd773ec6e927667 -- resources/dictionaries/*.csv
cd "$BASE_DIR"

# CSV 結合 (BOM/CRLF除去)
cat "$TMP_GIT/resources/dictionaries/"*.csv | sed '1s/^\xEF\xBB\xBF//' | tr -d '\r' | sed '/^$/d' > "$USER_CSV"
rm -rf "$TMP_GIT" # CSVを抽出したらGitディレクトリは即削除

# 3. システム辞書 (IPADIC) ソースの取得
# Gitが認証で止まるのを防ぐため、curlでアーカイブを直接取得 (タグ 0.3.0)
echo "Step 2: Downloading IPADIC source via curl..."
curl -L https://github.com/lindera-morphology/lindera-ipadic/archive/refs/tags/0.3.0.tar.gz | tar -xz -C "$SYS_DIC_SRC" --strip-components=1

# 4. システム辞書のビルド
# --user ビルドには「ビルド済みのシステム辞書」が不可欠です
echo "Step 3: Building system dictionary base..."
lindera build --src "$SYS_DIC_SRC" --dest "$SYS_DIC_BIN" --metadata ipadic

# 5. ユーザー辞書のビルド
# --src はビルド済みシステム辞書ディレクトリ、--user-dict は CSV を指定
echo "Step 4: Building user dictionary binary..."
lindera build \
  --src "$SYS_DIC_BIN" \
  --dest "$WORK_DIR/out" \
  --metadata ipadic \
  --user \
  --user-dict "$USER_CSV"

# 6. 成果物の配置
# 1.4.1 は all.bin または user_dict.bin という名前で生成します
echo "Step 5: Finalizing..."
TARGET_BIN=$(find "$WORK_DIR/out" -name "*.bin" | head -n 1)
if [ -f "$TARGET_BIN" ]; then
    mv "$TARGET_BIN" "$FINAL_DIC_DIR/all.dic"
    echo "Success: all.dic has been created."
else
    echo "Error: Failed to generate binary dictionary."
    exit 1
fi

# 7. 徹底清掃 (110GB 対策)
rm -rf "$WORK_DIR"

echo "=== 辞書作成完了 ==="