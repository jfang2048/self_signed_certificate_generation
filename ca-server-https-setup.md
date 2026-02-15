# 自建 CA 搭建 HTTPS 及域名配置

参考来源：[https://example.invalid/reference](https://example.invalid/reference)

本文档采用仓库根目录扁平化组织，可直接与 `README.md` 互相导航。

说明：以下内容覆盖自建 CA 搭建 HTTPS 服务器与域名相关配置流程。

---
首先，创建原始工作环境，例如在你的家目录下执行以下命令：
```
cd && mkdir -p myCA/signedcerts && mkdir myCA/private && cd myCA
```
上述命令将在你的家目录下创建一个myCA目录，在这个目录下有 signedcerts和private两个子目录。其中:

    ~/myCA : 用来存放 CA 证书, 证书数据库, 产生证书, 秘钥和请求
    ~/myCA/signedcerts : 存放所有签名证书的副本
    ~/myCA/private : 存放CA的私钥

下一步，在~/myCA目录下 创建一个原始证书数据库，serial（证书签名序列号，存放下一个要签名的证书的序号）这里写入01，表示从01开始:
```
echo '01' > serial  && touch index.txt
```
 

创建一个原始的CA配置文件 caconfig.cnf 。 编辑 ~/myCA/caconfig.cnf, 将以下内容写入文件并保存:
```
sudo vim ~/myCA/caconfig.cnf

# My sample caconfig.cnf file.
#
# Default configuration to use when one is not provided on the command line.
#
[ ca ]
default_ca = local_ca
#
#
# Default location of directories and files needed to generate certificates.
#
[ local_ca ]
dir = /home/<username>/myCA
certificate = $dir/cacert.pem
database = $dir/index.txt
new_certs_dir = $dir/signedcerts
private_key = $dir/private/cakey.pem
serial = $dir/serial
# 
#
# Default expiration and encryption policies for certificates.
#
default_crl_days = 365
default_days = 1825
default_md = SHA256 #签名摘要算法
# 
policy = local_ca_policy
x509_extensions = local_ca_extensions
#
#
# Copy extensions specified in the certificate request
#
copy_extensions = copy
# 
#
# Default policy to use when generating server certificates. The following
# fields must be defined in the server certificate.

#match 表示openssl ca要签署的证书请求文件中的项要和CA证书中的项匹配，即要相同，

#supplied表示必须要提供的项，

#optional表示可选项，所以可以留空
#
[ local_ca_policy ]
commonName = supplied 
stateOrProvinceName = supplied
countryName = supplied
emailAddress = supplied
organizationName = supplied
organizationalUnitName = supplied
# 
#
# x509 extensions to use when generating server certificates.
#
[ local_ca_extensions ]
basicConstraints = CA:false
subjectAltName = DNS:SERVER_DOMAIN_PLACEHOLDER
nsCertType = server
# 
#
# The default root certificate generation policy.
#
[ req ]
default_bits = 2048
default_keyfile = /home/<username>/myCA/private/cakey.pem
default_md = SHA256
# 
prompt = no
distinguished_name = root_ca_distinguished_name
x509_extensions = root_ca_extensions
#
#
# Root Certificate Authority distinguished name. Change these fields to match
# your local environment!
#
[ root_ca_distinguished_name ]
commonName = ROOT_CA_CN
stateOrProvinceName = STATE_PLACEHOLDER
countryName = XX
emailAddress = admin@example.invalid
organizationName = ORG_PLACEHOLDER
organizationalUnitName = ORG_UNIT_PLACEHOLDER
# 
[ root_ca_extensions ]
basicConstraints = CA:true
```
* 注意：不要忘记将[ local_ca ] 和 [ req ] 下 /home/<username>/···  <username>修改为自己的主机名 。可以 修改 [ root_ca_distinguished_name ] 下 commonName, stateOrProvinceName countryName 等以针对您的环境进行个性化设置

 

### 生成证书颁发机构根证书和密钥

首先设置一个环境变量OPENSSL_CONF，该变量强制openssl工具在备用位置（本例为〜/ myCA / caconfig.cnf）中查找配置文件：
```
export OPENSSL_CONF=~/myCA/caconfig.cnf
```

### 生成 CA 证书和秘钥：
```
openssl req -x509 -newkey rsa:2048 -out cacert.pem -outform PEM -days 1825
```
你将被提示输入密码, 并且看到如下结果:

Generating a 2048 bit RSA private key
....+++
..................................................................................................+++
writing new private key to '/home/<user>/myCA/private/cakey.pem'
Enter PEM pass phrase:
Verifying - Enter PEM pass phrase:
-----

* 牢记你设置密码！每次生成并签署新的服务器或客户端证书时，都需要用到它！

上述过程使用RSA公/私钥加密创建PEM格式的自签名证书。该证书有效期为1825天。文件的位置和作用如下：
    〜/ myCA / cacert.pem：CA证书
    〜/ myCA / private / cakey.pem：CA私钥

可选步骤：

从证书的所有文本中剥离证书，仅保留-CERTIFICATE-部分以创建crt
```
openssl x509 -in cacert.pem -out cacert.crt
```
### 创建自签名服务器证书

创建服务器配置文件 〜/ myCA / exampleserver.cnf 写入并保存以下内容
```
#
#exampleserver.cnf
#

[ req ]
prompt                  = no
distinguished_name      = server_distinguished_name
#req_extensions          = v3_req

[ server_distinguished_name ]
commonName              = SERVER_DOMAIN_PLACEHOLDER
stateOrProvinceName     = STATE_PLACEHOLDER
countryName             = XX
emailAddress            = admin@example.invalid
organizationName        = ORG_PLACEHOLDER
organizationalUnitName  = ORG_UNIT_PLACEHOLDER

[ v3_req ]
basicConstraints        = CA:FALSE
keyUsage                = nonRepudiation, digitalSignature, keyEncipherment
#subjectAltName          = @alt_names

#[ alt_names ]
#DNS.0                   = SERVER_DOMAIN_PLACEHOLDER
#DNS.1                   = ALT_SERVER_DOMAIN_PLACEHOLDER
```
* 注：确保更改 [server_distinguished_name] 下的值，尤其是commonName值。COMMONNAME值必须与主机名匹配。如果commonName与预期的主机名不匹配，则主机/证书不匹配错误将出现在尝试访问服务器的客户端的客户端应用程序中。这里已经修改为正确的commonName，不用进行修改


更改环境变量：
```
export OPENSSL_CONF=~/myCA/exampleserver.cnf
```
 
生成服务器临时证书和秘钥：
```
openssl req -newkey rsa:1024 -keyout tempkey.pem -keyform PEM -out tempreq.pem -outform PEM
```
你将被提示输入密码, 并且看到如下结果:

Generating a 1024 bit RSA private key
.......................................++++++
............................++++++
writing new private key to 'tempkey.pem'
Enter PEM pass phrase:
Verifying - Enter PEM pass phrase:
-----

* 不要忘记密码!

 

以下步骤（1）（2）二选一 （这里使用（1））

接下来，可以使用以下命令将临时私钥转换为未加密的密钥：（1）
```
openssl rsa <tempkey.pem> server_key.pem
```
你将被提示输入密码, 并且看到如下结果:
```
Enter pass phrase:
writing RSA key
```
如果您希望使用密码对密钥进行加密，只需使用以下命令重命名临时密钥，而不要执行步骤（1）：(2)
```
mv tempkey.pem server_key.pem
```
切记：如果您使用用密码加密的服务器密钥，则每次启动使用加密密钥的服务器应用程序时，都必须输入密码。这意味着，除非有人输入密钥，否则服务器应用程序将无法启动。


更改环境变量：
```
export OPENSSL_CONF=~/myCA/caconfig.cnf
```
使用证书颁发机构（CA）密钥对服务器证书进行签名：
```
openssl ca -in tempreq.pem -out server_crt.pem
```
系统将提示您输入CA的密码。输入此密码，将提示您确认exampleserver.cnf中的信息，最后要求确认签名证书。输出应与此类似：
```
Using configuration from /home/<user>/myCA/caconfig.cnf
Enter pass phrase for /home/<user>/myCA/private/cakey.pem:
Check that the request matches the signature
Signature ok
The Subject's Distinguished Name is as follows
commonName            :PRINTABLE:'SERVER_DOMAIN_PLACEHOLDER'
stateOrProvinceName   :PRINTABLE:'STATE_PLACEHOLDER'
countryName           :PRINTABLE:'XX'
emailAddress          :IA5STRING:'admin@example.invalid'
organizationName      :PRINTABLE:'ORG_PLACEHOLDER'
organizationalUnitName:PRINTABLE:'ORG_UNIT_PLACEHOLDER'
Certificate is to be certified until Dec 17 01:17:22 2025 GMT (1825 days)
Sign the certificate? [y/n]:y


1 out of 1 certificate requests certified, commit? [y/n]y
Write out database with 1 new entries
Data Base Updated
```
 

使用以下命令删除临时证书和密钥文件：
```
rm -f tempkey.pem && rm -f tempreq.pem
```
恭喜你！您现在拥有一个自签名服务器应用程序证书和密钥对：

    server_crt.pem：服务器应用程序证书文件
    server_key.pem：服务器应用程序密钥文件


---

##### 使用apache搭建HTTPS服务器
```
在 var/www 目录下创建目录 lab：

sudo cd && mkdir lab

在这个文件夹下创建index.html

sudo touch index.html #这个文件将作为网站的默认页面，你可以在里面随便写个html页面

 

编辑 /etc/apache2 目录 ports.conf 文件

　　Listen 80 后面加上 443 端口

修改后的文件如下：

# If you just change the port or add more ports here, you will likely also
# have to change the VirtualHost statement in
# /etc/apache2/sites-enabled/000-default
# This is also true if you have upgraded from before 2.2.9-3 (i.e. from
# Debian etch). See /usr/share/doc/apache2.2-common/NEWS.Debian.gz and
# README.Debian.gz

NameVirtualHost *:80
Listen 80 443

<IfModule mod_ssl.c>
    # If you add NameVirtualHost *:443 here, you will also have to change
    # the VirtualHost statement in /etc/apache2/sites-available/default-ssl
    # to <VirtualHost *:443>
    # Server Name Indication for SSL named virtual hosts is currently not
    # supported by MSIE on Windows XP.
    Listen 443
</IfModule>

<IfModule mod_gnutls.c>
    Listen 443
</IfModule>

 

 

在  /etc/apache2/sites-available 目录下 创建 lab-ssl.conf 文件，写入并保存以下内容：

<IfModule mod_ssl.c>
<VirtualHost _default_:443>
ServerAdmin admin@example.invalid

DocumentRoot /var/www/lab

ErrorLog ${APACHE_LOG_DIR}/error.log
CustomLog ${APACHE_LOG_DIR}/access.log combined

# SSL Engine Switch:
# Enable/Disable SSL for this virtual host.
SSLEngine on

 

# 网站证书和私钥地址
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

注意：网站证书和私钥地址目录里<username> 要改成你自己的主机名

 

重启 apache2

sudo service apache2 restart

启动ssl服务:

sudo a2ensite /etc/apache2/sites-available/lab-ssl.conf
sudo a2enmod ssl

  查看是否正确配置

在浏览器地址栏输入 https://SERVER_DOMAIN_PLACEHOLDER

浏览器不信任这个网站？这个网站的证书是自建CA签名的，浏览器并不信任这个CA，所以需要手动导入CA证书让浏览器信任我们的CA。


导入步骤如下：
打开 FireFox 浏览器，preference---advanced----certificates----view certificates----import，选择 myCA 目录下的根证书“cacert.pem”, 导入。
（不同版本浏览器可能操作步骤有些不同，请自行百度）

注：这里以占位域名为例，你应该看到页面地址栏是（https://SERVER_DOMAIN_PLACEHOLDER）

```

---

三、修改域名
将 /etc 目录下的 hosts 文件里加入一行 ip 到域名的映射
```
SERVER_IP_PLACEHOLDER   <你的域名>

SERVER_IP_PLACEHOLDER   SERVER_DOMAIN_PLACEHOLDER
SERVER_IP_PLACEHOLDER   <你的域名>
HOST_IP_PLACEHOLDER     HOST_PLACEHOLDER

# The following lines are desirable for IPv6 capable hosts
IPV6_LOOPBACK_PLACEHOLDER     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
```
将caconfig.cnf 文件 下面这一行DNS后面修改为你的域名
```
subjectAltName          = DNS:<你的域名>
```
将exampleserver.cnf 文件 commonName修改为你的域名
```
ommonName              = <你的域名>
```
按照上面 二、自建ca并搭建服务器 的方法重新搭建一遍
