#!/bin/bash
#
# Git 提交脚本 - 提交 v2.0.1 版本到 GitHub
#

set -e

echo "═══════════════════════════════════════════════════════════════"
echo "          📤 准备提交到 GitHub"
echo "═══════════════════════════════════════════════════════════════"
echo

# 1. 检查当前分支
echo "📍 当前分支: $(git branch --show-current)"
echo

# 2. 显示待提交的文件
echo "📝 待提交的文件:"
git status --short
echo

# 3. 添加所有文件
read -p "是否添加所有文件到暂存区？[Y/n]: " add_confirm
if [[ ! "$add_confirm" =~ ^[nN]$ ]]; then
    git add .
    echo "✅ 所有文件已添加到暂存区"
    echo
fi

# 4. 显示将要提交的内容
echo "📋 暂存区内容:"
git status --short
echo

# 5. 提交
read -p "是否现在提交？[Y/n]: " commit_confirm
if [[ ! "$commit_confirm" =~ ^[nN]$ ]]; then
    git commit -m "Release v2.0.1 - Bug fixes and deployment system

🐛 Bug Fixes:
- Fix whitelist routing rule (ip -> source field)
- Fix add_essential_ips_to_whitelist log pollution
- Fix config validation empty item filtering

✨ New Features:
- Add Playwright test sites (sehuatang.org/net)
- Add deployment guide (DEPLOYMENT.md)
- Add one-click update script (update.sh)

📚 Documentation:
- Update README.md with deployment section
- Add complete documentation index
- Update CHANGELOG.md with v2.0.1 release
- Update all statistics (2533 lines)

🧪 Testing:
- All 5 Playwright test sites pass
- Whitelist routing works correctly
- Configuration validation passes all scenarios
- Update script verified

See DEPLOYMENT.md for deployment and update guide."

    echo "✅ 提交成功！"
    echo
fi

# 6. 显示提交信息
echo "📜 最新提交:"
git log -1 --oneline
echo

# 7. 推送到远程
read -p "是否推送到 GitHub？[Y/n]: " push_confirm
if [[ ! "$push_confirm" =~ ^[nN]$ ]]; then
    echo "🚀 正在推送到 origin/main..."
    if git push origin main; then
        echo "✅ 推送成功！"
    else
        echo "❌ 推送失败，请检查网络或权限"
        exit 1
    fi
    echo
fi

# 8. 创建标签（可选）
read -p "是否创建 v2.0.1 标签？[y/N]: " tag_confirm
if [[ "$tag_confirm" =~ ^[yY]$ ]]; then
    git tag -a v2.0.1 -m "Version 2.0.1 - Bug fixes and deployment system

Key Changes:
- Fix critical whitelist routing bug
- Add deployment and update system
- Add configuration validation
- Complete documentation

Full changelog: See CHANGELOG.md"

    echo "✅ 标签 v2.0.1 已创建"

    read -p "是否推送标签到 GitHub？[Y/n]: " push_tag_confirm
    if [[ ! "$push_tag_confirm" =~ ^[nN]$ ]]; then
        git push origin v2.0.1
        echo "✅ 标签已推送"
    fi
    echo
fi

echo "═══════════════════════════════════════════════════════════════"
echo "          🎉 提交完成！"
echo "═══════════════════════════════════════════════════════════════"
echo
echo "📦 GitHub 仓库地址:"
echo "   https://github.com/your-username/xray-http-proxy"
echo
echo "📋 后续步骤:"
echo "   1. 访问 GitHub 仓库查看更新"
echo "   2. 在其他服务器上运行: ./update.sh"
echo "   3. 或者重新克隆: git clone <仓库地址>"
echo
echo "📚 查看完整文档: DEPLOYMENT.md"
echo

exit 0
