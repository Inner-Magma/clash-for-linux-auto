# Clash for Linux

Linux 服务器代理方案，基于 [Clash](https://github.com/Dreamacro/clash) 核心 + 脚本自动化管理。

解决服务器访问 GitHub 等境外资源慢的问题。支持 x86_64 / aarch64 / armv7 平台。

## 项目结构

```
clash-for-linux/
├── bin/                    # Clash 二进制（多架构）
├── conf/                   # 运行时配置 & GeoIP 数据库
├── dashboard/              # yacd Web 管理界面
├── temp/                   # 配置模板 & 临时文件
├── tools/                  # subconverter 订阅转换工具
├── scripts/
│   ├── common.sh           # 公共函数库
│   ├── auto_proxy.sh       # 登录自动代理
│   ├── proxy-select.sh     # 终端节点选择器
│   └── profile-convert.sh  # 配置格式转换
├── .env                    # 订阅地址 & Secret（私有，勿提交）
├── .env.example            # 配置模板
├── start.sh                # 首次启动（下载订阅 + 启动服务）
├── restart.sh              # 重启（不重新下载订阅）
├── shutdown.sh             # 停止服务
├── install_service.sh      # 一键安装（systemd + 登录自动代理）
└── uninstall.sh            # 一键卸载
```

## 快速开始

### 1. 配置订阅

```bash
cp .env.example .env
vim .env  # 填写 CLASH_URL 和 CLASH_SECRET
```

### 2. 首次启动

```bash
sudo bash start.sh
```

启动成功后会输出 Dashboard 地址和 Secret。

### 3. 一键安装（推荐）

```bash
bash install_service.sh
```

安装后自动实现：
- **开机自启** — 通过 systemd 管理 Clash 服务
- **登录自动代理** — 打开终端即开启 `http_proxy`
- **节点选择提示** — 登录时可选择是否切换节点

### 4. 手动开启代理

如果不使用 `install_service.sh`，可手动操作：

```bash
source /etc/profile.d/clash.sh
proxy_on
```

## 常用命令

| 操作 | 命令 |
|------|------|
| 查看服务状态 | `sudo systemctl status clash` |
| 重启服务 | `sudo systemctl restart clash` 或 `bash restart.sh` |
| 停止服务 | `sudo systemctl stop clash` 或 `bash shutdown.sh` |
| 开启代理 | `proxy_on` |
| 关闭代理 | `proxy_off` |
| 选择节点 | `bash scripts/proxy-select.sh` |
| 卸载 | `bash uninstall.sh` |

## 在新机器上部署

整个项目目录可直接拷贝到任意机器、任意路径，**零硬编码**。

```bash
scp -r clash-for-linux user@newhost:/path/to/
ssh user@newhost
cd /path/to/clash-for-linux
cp .env.example .env && vim .env
sudo bash start.sh
bash install_service.sh
```

## Dashboard

浏览器访问 `http://<ip>:9090/ui`，输入 API 地址 `http://<ip>:9090` 和 Secret 即可管理。

## 端口说明

| 端口 | 用途 |
|------|------|
| 7890 | HTTP 代理 |
| 7891 | SOCKS5 代理 |
| 7892 | Redir 透明代理 |
| 9090 | Dashboard / RESTful API |

## 注意事项

- 需要 root 或 sudo 权限运行
- `.env` 文件包含订阅地址等敏感信息，请勿提交到公开仓库
- 部分 Linux 默认 shell 为 dash，请使用 `bash xxx.sh` 运行脚本
- Google/Twitter/YouTube 等可能无法 ping 通，属正常现象（ICMP 不走代理）

## 许可证

GPL v3.0
