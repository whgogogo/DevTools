# DevTools - 开发环境效率工具设计文档

> 日期: 2026-04-04
> 状态: 设计确认

## 1. 概述

DevTools 是一款面向开发团队的命令行工具，安装在开发环境的跳板机上，通过一键安装分发到集群各节点。目标是简化日常开发过程中的节点搜索、容器跳转、Jar包替换、远程Debug、数据库连接、日志查询等高频操作。

### 1.1 核心约束

- **实现语言**: Shell/Bash
- **交互方式**: 交互式菜单（编号选择）
- **支持架构**: euler x86、euler arm
- **安装方式**: 跳板机执行 install.sh，自动通过 SCP（paas用户）分发到各节点
- **国际化**: 支持中英文双语，通过配置文件切换

## 2. 项目结构

```
devtools/
├── install.sh              # 一键安装入口
├── uninstall.sh            # 卸载脚本
├── bin/
│   └── devtools            # 主入口脚本（source各lib模块）
├── lib/
│   ├── common.sh           # 公共函数：颜色输出、菜单渲染、SSH封装、kubectl封装
│   ├── i18n.sh             # 国际化：根据配置加载中/英文字符串
│   ├── config.sh           # 配置管理：读写 ~/.devtools/config
│   ├── search.sh           # 功能1：节点/容器搜索与跳转（核心能力，其他功能依赖此）
│   ├── replace.sh          # 功能2：一键更换Jar包
│   ├── debug.sh            # 功能3：一键开启远程Debug
│   ├── database.sh         # 功能4：数据库连接
│   └── log.sh              # 功能5：DAC Spark日志查询
├── conf/
│   └── config.template     # 配置模板（含注释说明）
└── README.md
```

## 3. 配置文件设计

配置文件路径: `~/.devtools/config`，权限 `chmod 600`

### 设计原则

- **极简化**: 不预先配置节点/容器信息，全部通过 kubectl 动态获取
- **可扩展**: 新增数据库类型、健康检查脚本等只需修改配置文件

### 配置文件模板

```ini
# ============================================
# DevTools 配置文件
# ============================================

# 语言设置: zh_CN | en_US
LANG=zh_CN

# --------------------------------------------
# SSH凭据（各节点通用）
# --------------------------------------------
SSH_USER_PAAS=paas
SSH_PASS_PAAS=xxx
SSH_USER_ROOT=root
SSH_PASS_ROOT=xxx

# --------------------------------------------
# 健康检查脚本名称列表（逗号分隔）
# 用于功能3开启Debug时禁用健康检查
# --------------------------------------------
HEALTH_CHECK_SCRIPTS=health_check.sh,healthcheck.sh,check_health.sh

# --------------------------------------------
# DAC Spark日志路径
# --------------------------------------------
DAC_SPARK_LOG_PATH=/var/log/dac/spark.log

# --------------------------------------------
# 数据库配置
# KEYWORD: 用于搜索定位对应节点/容器的关键词
# CONNECT_CMD: 跳转到对应节点后执行的连接命令
#   单行命令: CONNECT_CMD=gsql -d mydb -p 5432
#   多行命令: 使用 <<EOF ... EOF 包裹
# --------------------------------------------

[gaussv1]
KEYWORD=gaussdb-v1
CONNECT_CMD<<EOF
source /home/paas/gauss_env.sh
gsql -d mydb -p 5432 -U myuser
EOF

[gaussv3]
KEYWORD=gaussdb-v3
CONNECT_CMD<<EOF
source /home/paas/gauss_env.sh
gsql -d mydb -p 5432 -U myuser
EOF

[carbon]
KEYWORD=carbon
CONNECT_CMD<<EOF
export JAVA_HOME=/opt/java
beeline -u "jdbc:hive2://localhost:10000/mydb"
EOF

[hudi]
KEYWORD=hudi
CONNECT_CMD<<EOF
cd /opt/hudi
./connect.sh
EOF
```

## 4. 核心功能设计

### 功能依赖关系

```
功能1（搜索跳转）  <-- 其他所有功能的基础
    ├── 功能2（替换jar）：搜索定位容器 → SSH跳转 → 替换jar → 重启容器
    ├── 功能3（远程debug）：搜索定位容器 → 配置debug参数 → 禁用健康检查 → 两级端口映射
    ├── 功能4（数据库）：按关键词搜索 → 跳转到对应节点 → 执行连接命令
    └── 功能5（日志）：搜索定位dac节点 → SSH跳转 → 查看日志
```

### 4.0 主菜单

执行 `devtools` 后展示:

```
╔══════════════════════════════════════╗
║       DevTools v1.0                 ║
╠══════════════════════════════════════╣
║  [1] 搜索节点/容器并跳转            ║
║  [2] 一键更换Jar包                  ║
║  [3] 一键开启远程Debug              ║
║  [4] 连接数据库                     ║
║  [5] 查询DAC Spark日志              ║
║  [c] 配置管理                       ║
║  [h] 帮助                           ║
║  [q] 退出                           ║
╚══════════════════════════════════════╝
请选择:
```

### 4.1 功能1：搜索节点/容器并跳转

**核心能力**: 通过 kubectl 动态获取节点和容器信息，支持关键词模糊搜索，选中后一键SSH跳转。

**流程**:

1. 提示用户输入搜索关键词（节点名或容器名）
2. 执行 `kubectl get nodes` 和 `kubectl get pods -A` 动态获取集群信息
3. 按关键词模糊匹配，展示结果列表:

```
  序号  节点名称          容器名称                    节点IP
  ────  ────────────────  ──────────────────────────  ──────────
  1     master           api-server-6d8f9b           10.0.0.1
  2     worker1          api-gateway-3a2c1           10.0.0.2
  3     worker1          data-service-7e4b2          10.0.0.2
  4     worker2          data-service-9f1a3          10.0.0.3
```

4. 用户输入序号，工具自动 SSH 跳转到对应节点；若选择的是容器，则进一步 `docker exec` 进入容器
5. 空结果时提示并允许重新搜索
6. 输入 0 返回主菜单

**搜索逻辑**:
- 关键词同时匹配节点名和容器名
- 模糊匹配（关键词为子串即可）
- 结果去重，同一节点+容器组合只出现一次

### 4.2 功能2：一键更换Jar包

**流程**:

1. **选择目标容器** -- 调用功能1搜索，用户选择要替换的容器

2. **选择Jar包** -- 自动扫描 `/home/paas` 及其一级子目录下的 `*.jar` 文件:

```
  在 /home/paas 下发现以下jar包：
  序号  文件名                                          大小
  ────  ──────────────────────────────────────────────  ──────
  1     my-service-1.0.0.jar                            45MB
  2     zhangsan/api-gateway-2.0.1.jar                  38MB
  3     lisi/data-service-3.0.0.jar                     52MB
  (0 返回上级)
  请选择要替换的jar包:
```

3. **备份** -- 在容器内备份原jar包（加时间戳）: `app.jar → app.jar.bak.20260404_153000`

4. **处理com目录** -- 检查容器内是否存在 `com` 目录，若存在则自动改名: `com → com.bak.20260404_153000`

5. **文件传输（全程使用paas用户，保持原始文件名）**:
```
跳板机(paas) --SCP(paas用户)--> 节点(paas):/home/paas/<原始jar文件名>
```

6. **修改属组** -- 在节点上修改文件属组:
```bash
chown <正确属组> /home/paas/<原始jar文件名>
docker cp /home/paas/<原始jar文件名> <容器ID>:<目标路径>/app.jar
```

7. **清理** -- 删除节点 `/home/paas/` 下的临时jar文件

8. **重启容器** -- 自动执行 `docker restart <容器ID>`，使新jar包生效。提示用户容器已重启

**关键约束**:
- SCP 传输全程使用 paas 用户
- 文件名保持原始名称不变
- `docker cp` 前必须修改文件属组
- 容器内若存在 com 目录必须先改名
- 备份文件保留，不自动删除

### 4.3 功能3：一键开启远程Debug

**网络拓扑**:
```
本地IDE <---> 跳板机:PORT_A <--(SSH转发)---> 节点:PORT_B <--(端口映射)---> 容器:PORT_C
```

**完整流程**:

1. **选择目标容器** -- 调用功能1搜索，用户选择容器

2. **配置三个端口** -- 每次执行时依次询问:
```
请配置Debug端口：
  跳板机端口    [默认: 5005]:
  节点端口      [默认: 5006]:
  容器内端口    [默认: 5007]:
```
- 三个端口独立，各有不同默认值
- 支持自定义，防止多人同时debug时端口冲突

3. **检测JDK版本** -- 自动在容器内执行 `java -version`，判断 JDK8 还是 JDK21

4. **生成对应的Debug JVM参数**:
   - JDK8: `-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=5007`
   - JDK21: `-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5007`

5. **防重复添加逻辑** -- 检查容器内 `start.sh` 中是否已包含 `agentlib:jdwp`:
   - **不存在**: 在 `start.sh` 的 Java 启动命令中追加 debug 参数
   - **已存在**:
```
  检测到start.sh中已有Debug参数:
    -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=5009
  [1] 使用已有端口 5009 继续后续操作
  [2] 替换为新的Debug参数（端口: 用户指定的端口）
  [0] 取消操作
  请选择:
```
   - 选1时自动将容器内端口调整为已有参数中的端口值，继续执行后续端口映射
   - 选2时替换为新参数

6. **禁用健康检查** -- 防止 debug 断点期间触发健康检查导致容器被重拉:
   - 从配置文件读取 `HEALTH_CHECK_SCRIPTS` 列表
   - 依次在容器内查找匹配的脚本
   - 在脚本开头插入 `exit 0`

7. **建立端口映射（两级）** -- 根据架构选择方式:
   - **x86**: 使用 iptables 或 socat
   - **ARM**: 使用 socat
   - 第一级: 容器 `PORT_C` → 节点 `PORT_B`
   - 第二级: 节点 `PORT_B` → 跳板机 `PORT_A`（SSH -L 端口转发）

8. **输出连接信息**:
```
远程Debug已就绪！
  跳板机IP: x.x.x.x
  跳板机端口: PORT_A
  请在IDEA中配置: Run -> Edit Configurations -> Remote JVM Debug
  退出时将自动清理端口转发并恢复健康检查脚本
```

9. **退出清理** -- 用户退出 debug 模式时自动:
   - 关闭两级端口转发进程
   - 移除健康检查脚本中的 `exit 0`
   - 移除 `start.sh` 中的 debug JVM 参数
   - 重启容器恢复正常运行

### 4.4 功能4：连接数据库

**流程**:

1. 展示数据库选项列表（从配置文件动态读取）:
```
  [1] GaussDB V1
  [2] GaussDB V3
  [3] Carbon
  [4] Hudi
```

2. 用户选择后，工具根据配置的 `KEYWORD` 调用功能1搜索定位对应节点/容器

3. 自动 SSH 跳转到对应节点（或进入对应容器）

4. 自动执行配置的 `CONNECT_CMD`（支持单行和多行命令）

5. 用户进入交互式 SQL 执行环境

**关键约束**:
- 数据库类型和连接命令完全可配置
- 支持 `<<EOF ... EOF` 格式的多行命令
- 后续新增数据库类型只需在配置文件中添加段即可

### 4.5 功能5：查询DAC Spark日志

**流程**:

1. 工具根据预设关键词（如 `dac`）调用功能1搜索定位 DAC 节点

2. SSH 跳转到对应节点

3. 自动执行 `tail -f` 或 `tail -n 500` 查看 spark 日志（路径从配置文件读取）

4. 支持输入关键词进行日志过滤

### 4.6 配置管理（功能C）

提供子菜单:
```
  [1] 查看当前配置
  [2] 修改语言设置
  [3] 修改SSH凭据
  [4] 修改健康检查脚本列表
  [5] 修改数据库关键词与连接命令
  [6] 修改日志路径
```

### 4.7 帮助（功能H）

显示各功能的简要说明（中英文双语）。

## 5. 国际化设计

- `i18n.sh` 中定义两组字符串数组: `MSG_ZH` 和 `MSG_EN`
- 所有输出文本通过 `msg "key"` 函数获取，根据配置的 `LANG` 返回对应语言
- 新增功能时只需在两组数组中添加对应的键值对
- 通过配置文件 `LANG=zh_CN` 或 `LANG=en_US` 切换，重启工具生效

## 6. 安装机制

### install.sh 流程

1. 检测当前系统架构（x86 / arm）
2. 通过 `kubectl get nodes` 动态获取集群节点列表
3. 使用 paas 用户通过 SCP 将 `devtools/` 目录分发到所有节点的 `/opt/devtools/`
4. 在各节点（包括跳板机）创建软链接: `/usr/local/bin/devtools -> /opt/devtools/bin/devtools`
5. 从模板生成初始配置文件: `~/.devtools/config`
6. 设置配置文件权限: `chmod 600`
7. 输出安装结果摘要

### uninstall.sh 流程

1. 在各节点删除 `/opt/devtools/` 目录
2. 删除软链接 `/usr/local/bin/devtools`
3. 询问是否删除配置文件 `~/.devtools/`

## 7. 后续扩展

工具采用模块化设计，后续新增功能只需:
1. 在 `lib/` 下新增功能脚本
2. 在主菜单中注册入口
3. 在 `i18n.sh` 中添加对应的中英文字符串
