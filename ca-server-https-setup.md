# 自建 CA 搭建 HTTPS 与域名配置（整理版）

本文档对原流程进行了语法修正与结构整理，目标是让你可以按步骤直接执行。

## 0. 占位符说明
请先理解并替换以下占位符：
- `SERVER_DOMAIN_PLACEHOLDER`：服务器域名
- `ALT_SERVER_DOMAIN_PLACEHOLDER`：备用域名（可选）
- `SERVER_IP_PLACEHOLDER`：服务器 IPv4 地址
- `HOST_IP_PLACEHOLDER`：主机地址占位
- `ROOT_CA_CN`：根 CA 的 Common Name
- `ORG_PLACEHOLDER` / `ORG_UNIT_PLACEHOLDER` / `STATE_PLACEHOLDER` / `CITY_PLACEHOLDER`

建议以下工作目录作为示例：`~/myCA`

---

## 1. 初始化 CA 工作目录
```bash
cd ~
mkdir -p myCA/signedcerts myCA/private
cd myCA

echo '01' > serial
touch index.txt
```

目录用途：
- `~/myCA`：CA 主目录（证书、数据库、请求等）
- `~/myCA/signedcerts`：已签发证书副本
- `~/myCA/private`：CA 私钥

---

## 2. 创建 CA 配置文件 `caconfig.cnf`
在 `~/myCA/caconfig.cnf` 写入：

```ini
[ ca ]
default_ca = local_ca

[ local_ca ]
dir = /home/<username>/myCA
certificate = $dir/cacert.pem
database = $dir/index.txt
new_certs_dir = $dir/signedcerts
private_key = $dir/private/cakey.pem
serial = $dir/serial

default_crl_days = 365
default_days = 1825
default_md = SHA256
policy = local_ca_policy
x509_extensions = local_ca_extensions
copy_extensions = copy

[ local_ca_policy ]
commonName = supplied
stateOrProvinceName = supplied
countryName = supplied
emailAddress = supplied
organizationName = supplied
organizationalUnitName = supplied

[ local_ca_extensions ]
basicConstraints = CA:false
subjectAltName = DNS:SERVER_DOMAIN_PLACEHOLDER
nsCertType = server

[ req ]
default_bits = 2048
default_keyfile = /home/<username>/myCA/private/cakey.pem
default_md = SHA256
prompt = no
distinguished_name = root_ca_distinguished_name
x509_extensions = root_ca_extensions

[ root_ca_distinguished_name ]
commonName = ROOT_CA_CN
stateOrProvinceName = STATE_PLACEHOLDER
countryName = XX
emailAddress = admin@example.invalid
organizationName = ORG_PLACEHOLDER
organizationalUnitName = ORG_UNIT_PLACEHOLDER

[ root_ca_extensions ]
basicConstraints = CA:true
```

注意：将 `/home/<username>/myCA` 中的 `<username>` 改为真实用户名。

---

## 3. 生成根 CA 证书与私钥
```bash
export OPENSSL_CONF=~/myCA/caconfig.cnf

openssl req -x509 -newkey rsa:2048 -out cacert.pem -outform PEM -days 1825
```

可选：导出 `.crt` 格式
```bash
openssl x509 -in cacert.pem -out cacert.crt
```

生成结果：
- `~/myCA/cacert.pem`：根 CA 证书
- `~/myCA/private/cakey.pem`：根 CA 私钥

---

## 4. 创建服务器证书请求配置 `exampleserver.cnf`
在 `~/myCA/exampleserver.cnf` 写入：

```ini
[ req ]
prompt = no
distinguished_name = server_distinguished_name

[ server_distinguished_name ]
commonName = SERVER_DOMAIN_PLACEHOLDER
stateOrProvinceName = STATE_PLACEHOLDER
countryName = XX
emailAddress = admin@example.invalid
organizationName = ORG_PLACEHOLDER
organizationalUnitName = ORG_UNIT_PLACEHOLDER

[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment

# [ alt_names ]
# DNS.1 = SERVER_DOMAIN_PLACEHOLDER
# DNS.2 = ALT_SERVER_DOMAIN_PLACEHOLDER
```

`commonName` 必须与目标域名一致，否则会出现主机名不匹配。

---

## 5. 生成并签发服务器证书
### 5.1 使用服务器配置生成临时请求和临时私钥
```bash
export OPENSSL_CONF=~/myCA/exampleserver.cnf
openssl req -newkey rsa:1024 -keyout tempkey.pem -keyform PEM -out tempreq.pem -outform PEM
```

### 5.2 临时私钥转正式私钥（两种方式）
方式 A（去掉私钥密码，常见于自动化启动）：
```bash
openssl rsa < tempkey.pem > server_key.pem
```

方式 B（保留私钥密码）：
```bash
mv tempkey.pem server_key.pem
```

### 5.3 使用 CA 签发服务器证书
```bash
export OPENSSL_CONF=~/myCA/caconfig.cnf
openssl ca -in tempreq.pem -out server_crt.pem
```

### 5.4 清理临时文件
```bash
rm -f tempkey.pem tempreq.pem
```

最终文件：
- `server_crt.pem`：服务器证书
- `server_key.pem`：服务器私钥

---

## 6. Apache HTTPS 配置示例
以下示例以 Debian/Ubuntu 的 Apache 路径为参考。

### 6.1 准备站点目录
```bash
sudo mkdir -p /var/www/lab
sudo touch /var/www/lab/index.html
```

### 6.2 启用 SSL 模块并创建站点配置
创建 `/etc/apache2/sites-available/lab-ssl.conf`：

```apache
<IfModule mod_ssl.c>
<VirtualHost _default_:443>
    ServerAdmin admin@example.invalid
    DocumentRoot /var/www/lab

    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined

    SSLEngine on

    SSLCertificateFile /home/<username>/myCA/server_crt.pem
    SSLCertificateKeyFile /home/<username>/myCA/server_key.pem

    <FilesMatch "\.(cgi|shtml|phtml|php)$">
        SSLOptions +StdEnvVars
    </FilesMatch>
    <Directory /usr/lib/cgi-bin>
        SSLOptions +StdEnvVars
    </Directory>
</VirtualHost>
</IfModule>
```

### 6.3 启用站点并重启
```bash
sudo a2enmod ssl
sudo a2ensite lab-ssl.conf
sudo systemctl restart apache2
```

浏览器访问：
```text
https://SERVER_DOMAIN_PLACEHOLDER
```

如果浏览器提示不受信任，需要导入根 CA 证书（`cacert.pem` 或 `cacert.crt`）。

---

## 7. 域名映射（hosts）
在 `/etc/hosts` 中加入映射：

```text
SERVER_IP_PLACEHOLDER   SERVER_DOMAIN_PLACEHOLDER
SERVER_IP_PLACEHOLDER   ALT_SERVER_DOMAIN_PLACEHOLDER
HOST_IP_PLACEHOLDER     HOST_PLACEHOLDER

# IPv6 placeholders
IPV6_LOOPBACK_PLACEHOLDER ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
```

---

## 8. 如果修改了域名，需要同步修改的位置
1. `caconfig.cnf` 中的 SAN（若你启用了域名限制）
```ini
subjectAltName = DNS:SERVER_DOMAIN_PLACEHOLDER
```

2. `exampleserver.cnf` 中的 `commonName`
```ini
commonName = SERVER_DOMAIN_PLACEHOLDER
```

3. Apache 配置中的访问域名与证书路径。

修改后，按第 5 节重新生成并签发服务器证书。

---

## 9. 常见问题
- `commonName` 与访问域名不一致：浏览器会报证书名称错误。
- 根 CA 未导入系统/浏览器信任库：浏览器会提示证书不受信任。
- 使用加密私钥启动服务：每次重启服务可能需要输入私钥密码。
- 证书路径错误：Apache 启动失败，先检查 `SSLCertificateFile` 与 `SSLCertificateKeyFile`。
