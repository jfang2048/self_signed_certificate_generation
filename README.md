# 自签名证书工具集（扁平目录）

## 1. 项目目标
本项目用于在本地/内网场景中自动化完成证书相关工作：
- 生成根 CA
- 生成服务器证书（支持 DNS/IP SAN）
- 合并为 PEM
- 安装 CA 到 Debian
- 导入 CA 到 Windows

当前脚本遵循统一风格：
- 默认读取 `cert_config.env`
- 支持命令行参数覆盖（`--help` 可查看）
- 日志输出到 `stderr`
- 结果输出到 `stdout`（`KEY=VALUE`），便于管道组合

## 2. 文件说明
- `cert_config.env`：统一配置入口
- `script_lib.sh`：公共函数（加载配置、路径处理、日志）
- `create_root_ca.sh`：只做一件事，生成根 CA
- `create_server_cert.sh`：只做一件事，生成/签发服务器证书
- `cert2pem.sh`：只做一件事，合并 CRT+KEY 为 PEM
- `install_cert_debian.sh`：只做一件事，安装 CA 到 Debian 信任库
- `win_import_cert_run_as admin.bat`：只做一件事，导入 CA 到 Windows 证书库
- `ca-server-https-setup.md`：扩展参考文档

## 3. 运行前准备
1. 安装 OpenSSL。
2. Linux/macOS 确保可执行权限：
```bash
chmod +x create_root_ca.sh create_server_cert.sh cert2pem.sh install_cert_debian.sh
```
3. 编辑配置文件：`cert_config.env`。

## 4. 配置文件要点
常用配置项（完整项见 `cert_config.env`）：
- 根 CA：`ROOT_CA_*`
- 服务器证书：`SERVER_*`
- 输出目录：`CERT_OUTPUT_DIR`
- Debian 安装：`DEBIAN_*`
- PEM 合并：`PEM_*`
- Windows 导入：`WIN_*`

建议先只改这几项：
- `CERT_OUTPUT_DIR`
- `ROOT_CA_NAME`、`ROOT_CN`
- `SERVER_CERT_NAME`、`SERVER_CN`
- `SERVER_DNS_1`（至少一个 SAN）

## 5. 步骤化使用
### 步骤 1：生成根 CA
```bash
./create_root_ca.sh
```
期望 stdout（示例）：
```text
ROOT_KEY_PATH=/abs/path/ROOT_CA.key
ROOT_CSR_PATH=/abs/path/ROOT_CA.csr
ROOT_CRT_PATH=/abs/path/ROOT_CA.crt
```

### 步骤 2：生成服务器证书
```bash
./create_server_cert.sh
```
期望 stdout（示例）：
```text
SERVER_KEY_PATH=/abs/path/server.example.internal.key
SERVER_CSR_PATH=/abs/path/server.example.internal.csr
SERVER_CRT_PATH=/abs/path/server.example.internal.crt
SERVER_EXT_PATH=/abs/path/server.example.internal.ext
```

### 步骤 3：合并为 PEM
```bash
./cert2pem.sh
```
期望 stdout（示例）：
```text
PEM_PATH=/abs/path/server.example.internal.pem
```

### 步骤 4（可选）：安装 CA 到 Debian
```bash
sudo ./install_cert_debian.sh
```
期望 stdout（示例）：
```text
INSTALLED_CERT_NAME=ROOT_CA.crt
INSTALLED_CERT_PATH=/abs/path/ROOT_CA.crt
```

### 步骤 5（可选）：导入 CA 到 Windows
管理员命令行运行：
```bat
win_import_cert_run_as admin.bat
```
期望 stdout（示例）：
```text
WIN_CERT_PATH=C:\path\ROOT_CA.crt
WIN_CERT_STORE=Root
```

## 6. 常用参数覆盖示例
### 用临时配置文件运行
```bash
./create_root_ca.sh --config /tmp/my_cert_config.env
```

### 临时覆盖输出目录
```bash
./create_server_cert.sh --out-dir /tmp/certs
```

### 临时覆盖服务器 SAN（可重复）
```bash
./create_server_cert.sh \
  --name api.example.internal \
  --cn api.example.internal \
  --dns api.example.internal \
  --dns alt-api.example.internal \
  --ip 203.0.113.20
```

### 不改配置，直接指定 CRT/KEY 合并 PEM
```bash
./cert2pem.sh \
  --crt /tmp/certs/api.example.internal.crt \
  --key /tmp/certs/api.example.internal.key \
  --out /tmp/certs/api.example.internal.pem
```

## 7. 组合与管道示例（UNIX 风格）
### 一次生成并导出 PEM（通过 stdout 变量）
```bash
eval "$(./create_server_cert.sh)"
./cert2pem.sh --crt "$SERVER_CRT_PATH" --key "$SERVER_KEY_PATH"
```

### 仅取 CRT 路径
```bash
./create_server_cert.sh | awk -F= '/^SERVER_CRT_PATH=/{print $2}'
```

## 8. 常见问题与排查
1. `No SAN entries found`
原因：没有提供 `SERVER_DNS_*` 或 `SERVER_IP_*`，且未通过 `--dns/--ip` 传参。

2. `CA files not found`
原因：未先执行 `create_root_ca.sh`，或 `ROOT_CA_*` 文件名/输出目录不一致。

3. Debian 安装失败
原因：需要 root 权限；请使用 `sudo`，并检查 `DEBIAN_*` 路径配置。

4. Windows 导入失败
原因：未以管理员权限运行，或 `WIN_CA_CERT_FILE` 路径错误。

## 9. 安全注意事项
- 当前仓库配置均为占位值，请勿填入真实敏感信息后直接提交。
- 严禁提交真实私钥（`.key`）与生产证书。
- 建议把证书产物目录加入 `.gitignore`。
- 根 CA 私钥应单独受控保存，避免放在共享目录。

---

# Self-Signed Certificate Toolkit

## Overview
Config-driven certificate automation with simple UNIX-style scripts:
- `create_root_ca.sh`
- `create_server_cert.sh`
- `cert2pem.sh`
- `install_cert_debian.sh`
- `win_import_cert_run_as admin.bat`

All scripts:
- read `cert_config.env` by default
- support CLI overrides (`--help`)
- log to `stderr`
- print machine-friendly `KEY=VALUE` to `stdout`

## Quick Start
```bash
./create_root_ca.sh
./create_server_cert.sh
./cert2pem.sh
# optional
sudo ./install_cert_debian.sh
```

## Useful Overrides
```bash
./create_root_ca.sh --config /tmp/my.env
./create_server_cert.sh --out-dir /tmp/certs --dns api.example.internal --ip 203.0.113.20
./cert2pem.sh --crt /tmp/certs/api.example.internal.crt --key /tmp/certs/api.example.internal.key
```

## Composition Example
```bash
eval "$(./create_server_cert.sh)"
./cert2pem.sh --crt "$SERVER_CRT_PATH" --key "$SERVER_KEY_PATH"
```

## Security Notes
- Do not commit real private keys or production certs.
- Keep CA private keys in a protected location.
- Prefer placeholders in shared config/docs.
