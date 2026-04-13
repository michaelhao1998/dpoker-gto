# DPoker GTO - 德州扑克策略计算器

[![Deploy to GitHub Pages](https://github.com/你的用户名/dpoker-gto/actions/workflows/deploy.yml/badge.svg)](https://github.com/你的用户名/dpoker-gto/actions/workflows/deploy.yml)

🔗 **在线访问**: https://你的用户名.github.io/dpoker-gto/

## 功能特性

- 🧠 **MCCFR 实时求解** - Monte Carlo Counterfactual Regret Minimization 算法
- 📊 **GTO 范围数据库** - 基于位置的 169 手牌完整策略
- 🎯 **多人底池支持** - 支持 3+ 玩家场景计算
- 📱 **PWA 离线可用** - 可安装为桌面/移动应用
- 💾 **历史记录** - 本地保存计算历史
- ⚡ **性能优化** - 设备自适应迭代次数

## 技术栈

- 纯前端实现 (HTML + CSS + JavaScript)
- Tailwind CSS 样式框架
- GitHub Pages 托管
- Service Worker 离线缓存

## 本地开发

```bash
# 克隆仓库
git clone https://github.com/你的用户名/dpoker-gto.git
cd dpoker-gto

# 本地预览
# 直接用浏览器打开 prototype/index.html
# 或使用本地服务器:
npx serve prototype
```

## 部署

本项目使用 GitHub Actions 自动部署到 GitHub Pages：

1. 推送代码到 `main` 分支
2. GitHub Actions 自动构建并部署
3. 访问 `https://你的用户名.github.io/dpoker-gto/`

## 使用说明

1. 选择你的手牌（点击牌面）
2. 选择你的位置（BTN/CO/HJ/UTG/SB/BB）
3. 设置筹码深度和底池大小
4. 选择面对的行动
5. 点击计算获取 GTO 策略建议

## 浏览器支持

- Chrome 90+
- Firefox 88+
- Safari 14+
- Edge 90+

## 许可证

MIT License
