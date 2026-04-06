# DevTools

一款面向开发团队的命令行效率工具，基于 Shell/Bash 实现，适用于 K8s + Docker 容器化部署的多节点集群环境。

## 功能特性

| 编号 | 功能 | 说明 |
|------|------|------|
| 1 | 搜索跳转 | 通过关键词模糊搜索节点/容器，选中后一键 SSH 跳转 |
| 2 | Jar 包替换 | 扫描本地 jar 包，一键替换到容器内并重启服务 |
| 3 | 远程 Debug | 自动配置 JVM 参数、禁用健康检查、建立两级端口转发 |
| 4 | 数据库连接 | 选择数据库类型后自动跳转并执行连接命令 |
| 5 | 日志查询 | 搜索 DAC 节点并查看 spark.log，支持实时跟踪和关键词过滤 |
| c | 配置管理 | 管理 SSH 凭据、数据库连接命令、健康检查脚本等 |
| h | 帮助 | 中英文双语帮助信息 |

## 环境要求

- **操作系统**: EulerOS (x86 / ARM)
- **依赖**: Bash 4+, kubectl, docker, sshpass, socat
- **网络**: 跳板机可通过 SSH 访问所有集群节点

## 快速开始

### 1. 打包

```bash
bash make_package.sh
```

生成 `dist/devtools-1.0.0.tar.gz`。

### 2. 上传到跳板机

```bash
scp dist/devtools-1.0.0.tar.gz <跳板机>:/home/paas/
```

### 3. 安装

```bash
cd /home/paas
tar xzf devtools-1.0.0.tar.gz
cd devtools-1.0.0
bash install.sh
```

`install.sh` 会自动：
- 检测集群节点列表
- 将工具分发到所有节点
- 生成配置文件 `~/.devtools/config`

### 4. 使用

```bash
devtools
```

## 功能详解

### 搜索节点/容器并跳转

输入节点名或容器名关键词，工具通过 `kubectl` 动态获取集群信息并模糊匹配，展示列表后选择编号即可 SSH 跳转。

```
  序号  节点名称          容器名称                    节点IP
  ----  ----------------  ----------------------------  ----------------
  1     master           api-server-6d8f9b           10.0.0.1
  2     worker1          api-gateway-3a2c1           10.0.0.2
```

### 一键更换 Jar 包

1. 搜索选择目标容器
2. 自动扫描 `/home/paas` 下的 jar 包供选择
3. 自动完成：备份原 jar → 处理 com 目录 → SCP 传输 → 修改属组 → docker cp 替换 → 重启容器

### 远程 Debug

适配 JDK 8 / JDK 21，支持自定义端口防止冲突，完整流程：

1. 搜索选择目标容器
2. 配置三个端口（跳板机 / 节点 / 容器内）
3. 自动检测 JDK 版本并生成对应 Debug 参数
4. 防重复检查（已存在参数时可复用或替换）
5. 禁用健康检查（防止断点期间容器被重拉）
6. 建立两级端口转发：`本地IDE ←→ 跳板机 ←(SSH)→ 节点 ←(socat)→ 容器`
7. 退出时自动清理所有配置并恢复容器

### 数据库连接

支持 GaussDB V1/V3、Carbon、Hudi 等，连接命令完全可配置，支持多行命令：

```ini
[gaussv1]
KEYWORD=gaussdb-v1
CONNECT_CMD<<EOF
source /home/paas/gauss_env.sh
gsql -d mydb -p 5432 -U myuser
EOF
```

新增数据库类型只需在配置文件中添加段即可。

## 配置文件

配置文件路径：`~/.devtools/config`

```ini
# 语言设置: zh_CN | en_US
LANG=zh_CN

# SSH 凭据
SSH_USER_PAAS=paas
SSH_PASS_PAAS=your_password
SSH_USER_ROOT=root
SSH_PASS_ROOT=your_password

# 健康检查脚本名称（逗号分隔）
HEALTH_CHECK_SCRIPTS=health_check.sh,healthcheck.sh,check_health.sh

# DAC Spark 日志路径
DAC_SPARK_LOG_PATH=/var/log/dac/spark.log

# 数据库配置（支持多行 CONNECT_CMD）
[gaussv1]
KEYWORD=gaussdb-v1
CONNECT_CMD=gsql -d mydb -p 5432
```

## 项目结构

```
devtools/
├── install.sh              # 一键安装
├── uninstall.sh            # 卸载
├── make_package.sh         # 打包脚本
├── bin/
│   └── devtools            # 主入口
├── lib/
│   ├── common.sh           # 公共函数（颜色/SSH/kubectl）
│   ├── i18n.sh             # 国际化（中/英）
│   ├── config.sh           # 配置管理
│   ├── search.sh           # 搜索跳转
│   ├── replace.sh          # Jar 包替换
│   ├── debug.sh            # 远程 Debug
│   ├── database.sh         # 数据库连接
│   └── log.sh              # 日志查询
├── conf/
│   └── config.template     # 配置模板
└── tests/                  # 单元测试
```

## 卸载

```bash
bash uninstall.sh
```

## 扩展

工具采用模块化设计，新增功能只需：
1. 在 `lib/` 下新增功能脚本
2. 在 `bin/devtools` 主菜单中注册入口
3. 在 `lib/i18n.sh` 中添加中英文字符串
