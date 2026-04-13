# DPoker GTO 部署到 GitHub Pages 完整指南

## 前置条件

1. GitHub 账号 (https://github.com/signup)
2. Git 已安装 (https://git-scm.com/download/win)
3. 本地项目代码已准备好

---

## 步骤 1: 创建 GitHub 仓库

### 1.1 在 GitHub 上创建新仓库

1. 访问 https://github.com/new
2. 填写仓库信息:
   - **Repository name**: `dpoker-gto` (或你喜欢的名字)
   - **Description**: 德州扑克 GTO 策略计算器
   - **Visibility**: Public (免费用户必须选 Public)
   - ✅ 勾选 "Add a README file"
3. 点击 **Create repository**

### 1.2 记录仓库地址

创建后会得到类似这样的地址:
```
https://github.com/你的用户名/dpoker-gto.git
```

---

## 步骤 2: 初始化本地 Git 仓库并推送

### 2.1 打开 PowerShell，进入项目目录

```powershell
cd C:\Users\michaellhao\CodeBuddy\DPoker
```

### 2.2 初始化 Git 仓库

```powershell
git init
```

### 2.3 添加所有文件

```powershell
git add .
```

### 2.4 提交代码

```powershell
git commit -m "Initial commit: DPoker GTO v1.1"
```

### 2.5 连接远程仓库

将 `你的用户名` 替换为你的 GitHub 用户名:

```powershell
git remote add origin https://github.com/你的用户名/dpoker-gto.git
```

### 2.6 推送代码

```powershell
git branch -M main
git push -u origin main
```

---

## 步骤 3: 配置 GitHub Pages

### 3.1 进入仓库设置

1. 打开 https://github.com/你的用户名/dpoker-gto
2. 点击顶部 **Settings** 标签

### 3.2 启用 Pages

1. 左侧菜单点击 **Pages**
2. **Source** 部分选择 **GitHub Actions**
3. 系统会自动检测 `.github/workflows/deploy.yml`

---

## 步骤 4: 触发部署

### 4.1 手动触发

推送任意更新到 main 分支即可触发部署:

```powershell
# 修改任意文件后
git add .
git commit -m "Trigger deployment"
git push
```

### 4.2 查看部署状态

1. 访问 https://github.com/你的用户名/dpoker-gto/actions
2. 等待 workflow 变绿 ✅

---

## 步骤 5: 访问公网链接

部署成功后，你的应用将可以通过以下地址访问:

```
https://你的用户名.github.io/dpoker-gto/
```

例如:
```
https://michaellhao.github.io/dpoker-gto/
```

---

## 常见问题

### Q1: 页面显示 404

**原因**: GitHub Pages 需要几分钟才能生效

**解决**: 等待 2-5 分钟后刷新，或检查 Actions 是否成功

### Q2: CSS/JS 加载失败

**原因**: 路径问题

**解决**: 确保 `index.html` 中引用资源使用相对路径 `./` 而非绝对路径 `/`

### Q3: 推送失败 (Authentication failed)

**原因**: GitHub 已停止支持密码验证

**解决**: 
1. 创建 Personal Access Token: https://github.com/settings/tokens
2. 使用 Token 代替密码，或配置 SSH:
   ```powershell
   git remote set-url origin git@github.com:你的用户名/dpoker-gto.git
   ```

### Q4: 如何更新已部署的网站

```powershell
git add .
git commit -m "Update: 描述你的修改"
git push
```

GitHub Actions 会自动重新部署。

---

## 自定义域名 (可选)

如果你想使用自己的域名而非 github.io:

1. 在 `prototype` 目录创建 `CNAME` 文件:
   ```
   poker.yourdomain.com
   ```

2. 在你的域名 DNS 设置中添加:
   ```
   CNAME poker.yourdomain.com 你的用户名.github.io
   ```

3. 在 GitHub Pages 设置中启用 "Enforce HTTPS"

---

## 完整命令速查

```powershell
# 1. 进入目录
cd C:\Users\michaellhao\CodeBuddy\DPoker

# 2. 初始化
git init

# 3. 添加文件
git add .

# 4. 提交
git commit -m "Initial commit"

# 5. 连接远程
git remote add origin https://github.com/你的用户名/dpoker-gto.git

# 6. 推送
git branch -M main
git push -u origin main

# 后续更新
git add .
git commit -m "Update description"
git push
```

---

## 部署后检查清单

- [ ] 仓库已创建且为 Public
- [ ] 代码已推送到 main 分支
- [ ] GitHub Actions workflow 执行成功
- [ ] 访问 `https://你的用户名.github.io/dpoker-gto/` 正常
- [ ] 牌面选择功能正常
- [ ] 计算功能正常
- [ ] PWA 安装提示出现

---

**预计部署时间**: 5-10 分钟
