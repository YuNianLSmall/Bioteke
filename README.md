# 百泰克企业社区 · 固定入口

这是一个**跳转页**，不是网站本体。

- 网站本体跑在本机的 Flask 服务上，通过 Cloudflare 隧道暴露公网；
- 隧道地址（quick Tunnel）每次重启都会变；
- 本仓库的 `index.html` 保存着「当前有效地址」，改动后推到 GitHub Pages，
  就能用一个**永远不变的地址**进到站点。

## 文件说明

| 文件 | 作用 |
| --- | --- |
| `index.html` | 跳转页本体。改的是它里头的 `data-target="..."` |
| `sync.ps1` | 同步脚本：取当前隧道地址 → 改写 `index.html` → 提交推送 |
| `.gitignore` | 忽略本地凭据与配置（`token.txt` / `remote.txt` / `.last_url`） |

## 本机（Windows）使用

1. 启动公网穿透，拿到 `https://xxx.trycloudflare.com`；
2. 在同目录放两个文件：
   - `remote.txt` 第一行写 `你的GitHub名/仓库名`，第二行写 Pages 地址（可选）
   - `token.txt` 写 GitHub Personal Access Token（`repo` 权限）
3. 双击 **同步到GitHub.bat**（或隧道启动器自动调用），固定地址就更新好了。

## 为什么不用自定义域名

quick Tunnel 每次换地址，必须有地方保存「当前这条地址」。
GitHub Pages 是纯静态托管、不能做服务端反向代理，
所以这里的做法是「Pages 存一份地址快照 + 页面自动跳转」，
而不是让 Pages 直接代理到本机。
