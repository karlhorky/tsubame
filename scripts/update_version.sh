#!/bin/bash

# update_version.sh
# Xcodeビルドフェーズで実行するスクリプト
# VERSIONファイルからバージョン、gitコミット数からビルド番号を取得してInfo.plistに設定

# エラー時に停止
set -e

# Info.plistのパス
PLIST="${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"
PLIST_SOURCE="${SRCROOT}/WindowSmartMover/Info.plist"

# VERSIONファイルのパス
VERSION_FILE="${SRCROOT}/VERSION"

# バージョン番号を取得
if [ -f "$VERSION_FILE" ]; then
    VERSION=$(cat "$VERSION_FILE" | tr -d '[:space:]')
    echo "📦 Version: $VERSION (from VERSION file)"
else
    VERSION="1.0.0"
    echo "⚠️ VERSION file not found, using default: $VERSION"
fi

# ビルド番号をgitコミット数から取得
if [ -d "${SRCROOT}/.git" ]; then
    BUILD_NUMBER=$(git -C "$SRCROOT" rev-list --count HEAD)
    echo "🔢 Build: $BUILD_NUMBER (git commit count)"
else
    BUILD_NUMBER="1"
    echo "⚠️ Not a git repository, using default build: $BUILD_NUMBER"
fi

# Info.plistを更新（ビルド後のバンドル内）
if [ -f "$PLIST" ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$PLIST"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$PLIST"
    echo "✅ Updated: $PLIST"
fi

echo "📱 App Version: $VERSION ($BUILD_NUMBER)"
