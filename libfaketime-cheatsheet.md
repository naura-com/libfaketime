# libfaketime 配置速查表 (v0.9.12)

## 一、加载方式

### Linux

| 方式 | 命令 |
|------|------|
| 单次运行 | `LD_PRELOAD=/path/to/libfaketime.so.1 FAKETIME="..." <命令>` |
| 全局导出 | `export LD_PRELOAD=/path/to/libfaketime.so.1` |
| 多线程版 | 使用 `libfaketimeMT.so.1` 替代 `libfaketime.so.1` |
| 系统级 | 将库路径写入 `/etc/ld.so.preload` |

### macOS

| 方式 | 命令 |
|------|------|
| 单次运行 | `DYLD_FORCE_FLAT_NAMESPACE=1 DYLD_INSERT_LIBRARIES=/path/to/libfaketime.1.dylib FAKETIME="..." <命令>` |
| 全局导出 | `export DYLD_FORCE_FLAT_NAMESPACE=1` + `export DYLD_INSERT_LIBRARIES=/path/to/libfaketime.1.dylib` |

> **注意**：macOS SIP 会阻止对 `/bin/date` 等系统程序的注入。可复制到非 SIP 保护路径（如 `~/bin/`）使用，或在 recovery 模式下禁用 SIP。

---

## 二、时间格式 (`FAKETIME`)

### 基本格式

| 类型 | 格式 | 示例 | 说明 |
|------|------|------|------|
| 绝对时间（冻结） | `YYYY-MM-DD hh:mm:ss` | `FAKETIME="2020-12-24 20:30:00"` | 时间固定在指定时刻 |
| 起始时间 | `@YYYY-MM-DD hh:mm:ss` | `FAKETIME="@2020-12-24 20:30:00"` | 从该时刻开始走时 |
| 相对偏移 | `[+/-]<数值>[乘数]` | `FAKETIME="-15d"` | 相对真实时间的偏移 |

### 乘数后缀

| 后缀 | 含义 | 示例 |
|------|------|------|
| （无） | 秒 | `FAKETIME="+120"` → +2 分钟 |
| `m` | 分钟 | `FAKETIME="-30m"` → -30 分钟 |
| `h` | 小时 | `FAKETIME="+2h"` → +2 小时 |
| `d` | 天 | `FAKETIME="-15d"` → -15 天 |
| `y` | 年 (365天) | `FAKETIME="+1y"` → +1 年 |

### 高级格式 (`-f` 模式，仅环境变量直接使用)

| 修饰符 | 格式 | 示例 | 说明 |
|--------|------|------|------|
| 小数偏移 | `[+/-]<值>,<小数><乘数>` | `FAKETIME="+1,5h"` | 1.5 小时（分隔符取决于 locale，可能用 `.`） |
| `x` 倍速 | `+<偏移> x<倍速>` | `FAKETIME="+0 x2"` | 时间走速为真实的 2 倍 |
| `x` 慢速 | `+<偏移> x<小数>` | `FAKETIME="+0 x0,5"` | 时间走速为真实的一半 |
| `i` 步进 | `+<偏移> i<步长>` | `FAKETIME="+0 i2,0"` | 每次 `time()` 调用前进 2 秒（不依赖系统时钟） |

> 使用 `x`/`i` 必须有偏移前缀。若不需要偏移，用 `+0 x2`。`faketime` 命令行需加 `-f` 参数。

---

## 三、时间指定方式（优先级从高到低）

| 方式 | 环境变量 / 文件 | 说明 |
|------|-----------------|------|
| 1. 环境变量 | `FAKETIME="..."` | 优先级最高 |
| 2. 自定义文件 | `FAKETIME_TIMESTAMP_FILE=/path/to/file` | 文件内容同 `FAKETIME` 格式 |
| 3. 用户配置 | `$HOME/.faketimerc` | 用户级默认 |
| 4. 系统配置 | `/etc/faketimerc` | 系统级默认（仅在无 `~/.faketimerc` 时生效） |

### 自定义格式 (`FAKETIME_FMT`)

| 值 | 说明 | 示例 |
|----|------|------|
| `%s` | Unix 时间戳 | `FAKETIME_FMT=%s FAKETIME="1608841800"` |
| `%c` | 本地完整时间 | `FAKETIME_FMT=%c FAKETIME="Thu Dec 24 20:30:00 2020"` |

支持 `strptime()` 的所有格式。

---

## 四、环境变量速查表

### 基础控制

| 环境变量 | 值 | 说明 |
|----------|-----|------|
| `FAKETIME` | 时间格式字符串 | 核心变量，指定伪装时间 |
| `FAKETIME_FMT` | `strptime` 格式 | 自定义 `FAKETIME` 解析格式 |
| `FAKETIME_NO_CACHE` | `1` | 禁用配置缓存（每次调用均重新读取） |
| `FAKETIME_CACHE_DURATION` | 秒数（默认 10） | 配置文件缓存时间间隔 |
| `FAKETIME_DONT_RESET` | `1` | 子进程不从起始时间重新开始，继续递增 |
| `FAKETIME_DONT_FAKE_MONOTONIC` | `1` | 不伪装 `CLOCK_MONOTONIC`（**Java/JVM 必备**） |
| `DONT_FAKE_MONOTONIC` | `1` | 同上（旧名，兼容） |

### 时间配置来源

| 环境变量 | 值 | 说明 |
|----------|-----|------|
| `FAKETIME_TIMESTAMP_FILE` | 文件路径 | 从文件读取 `FAKETIME` 格式配置 |
| `FAKETIME_UPDATE_TIMESTAMP_FILE` | `1` | 配合 `-DFAKE_SETTIME`，`date -s` 时同步写回文件 |

### 文件时间戳控制

| 环境变量 | 值 | 说明 |
|----------|-----|------|
| `NO_FAKE_STAT` | 任意非空 | 禁用文件时间戳伪装（stat 类调用透传） |
| `FAKE_UTIME` | `1` | 运行时启用 utime 伪装（需编译时 `-DFAKE_FILE_TIMESTAMPS`） |

### 跟随文件模式

| 环境变量 | 值 | 说明 |
|----------|-----|------|
| `FAKETIME` | `%` | 启用跟随文件模式 |
| `FAKETIME_FOLLOW_FILE` | 文件路径 | 以该文件修改时间作为起始时间 |
| `FAKETIME_FOLLOW_ABSOLUTE` | `1` | 子模式：伪装时间仅在文件时间戳前进时才前进（实现暂停/恢复） |

### 时钟速度控制

| 环境变量 | 值 | 说明 |
|----------|-----|------|
| `FAKETIME_XRESET` | 任意值 | 平滑 `x` 修饰符切换（避免时间跳变） |

### 活动时间限制

| 环境变量 | 值 | 说明 |
|----------|-----|------|
| `FAKETIME_START_AFTER_SECONDS` | 秒数 | 启动后 N 秒才开始伪装（默认 -1，忽略） |
| `FAKETIME_STOP_AFTER_SECONDS` | 秒数 | 启动后 N 秒停止伪装（默认 -1，忽略） |
| `FAKETIME_START_AFTER_NUMCALLS` | 次数 | 第 N 次时间调用后开始伪装 |
| `FAKETIME_STOP_AFTER_NUMCALLS` | 次数 | 第 N 次时间调用后停止伪装 |

> 两对变量可组合使用，同时满足才生效。

### 进程过滤

| 环境变量 | 值 | 说明 |
|----------|-----|------|
| `FAKETIME_ONLY_CMDS` | 逗号分隔的命令名 | 仅对这些进程生效 |
| `FAKETIME_SKIP_CMDS` | 逗号分隔的命令名 | 跳过这些进程，对其余生效 |

> 两者互斥，不能同时设置。

### 生成外部进程

| 环境变量 | 值 | 说明 |
|----------|-----|------|
| `FAKETIME_SPAWN_TARGET` | shell 命令 | 要执行的外部命令 |
| `FAKETIME_SPAWN_SECONDS` | 秒数 | 启动后 N 秒时触发 |
| `FAKETIME_SPAWN_NUMCALLS` | 次数 | 第 N 次时间调用时触发 |

### 时间戳文件

| 环境变量 | 值 | 说明 |
|----------|-----|------|
| `FAKETIME_SAVE_FILE` | 文件路径 | 保存伪装时间戳到文件（二进制流） |
| `FAKETIME_LOAD_FILE` | 文件路径 | 从文件回放时间戳 |

### 伪 PID

| 环境变量 | 值 | 说明 |
|----------|-----|------|
| `FAKETIME_FAKEPID` | 整数 | 伪装 `getpid()` 返回值（需编译时 `-DFAKE_PID`） |

### 随机数（编译时需 `-DFAKE_RANDOM`）

| 环境变量 | 值 | 说明 |
|----------|-----|------|
| `FAKERANDOM_SEED` | 64位种子（如 `0x12345678DEADBEEF`） | 替换 `getrandom()` 为确定性序列 |

### 共享内存相关

| 环境变量 | 值 | 说明 |
|----------|-----|------|
| `FAKETIME_DISABLE_SHM` | `1` | 禁用进程间共享内存 |
| `FAKETIME_FLSHM` | `1` | 强制清除共享内存同步变量 |
| `FAKETIME_SHARED` | （内部自动设置） | 共享内存标识 |

### 调试 & 高级

| 环境变量 | 值 | 说明 |
|----------|-----|------|
| `FAKETIME_DEBUG` | 任意值 | 输出调试信息 |
| `FAKETIME_DEBUG_DLSYM` | `1` | 调试 dlsym 符号解析，输出未找到的符号 |
| `FAKETIME_IGNORE_SYMBOLS` | 逗号分隔的符号名 | 跳过特定 dlsym/dlvsym 符号（防止递归/死锁） |
| `FAKETIME_WAIT_MS` | 毫秒数 | `clock_gettime` 返回前等待，用于竞态测试 |
| `FAKETIME_FORCE_MONOTONIC_FIX` | `1` / `0` | 运行时强制启用/禁用 `CLOCK_MONOTONIC` 修复 |
| `SILENT` | （编译时宏） | 在 libfaketime 环境中抑制 wrapper 警告 |

---

## 五、编译时宏 (`FAKETIME_COMPILE_CFLAGS`)

### 默认启用的宏

| 宏 | 说明 |
|----|------|
| `FAKE_STAT` | 拦截文件时间戳相关系统调用 |
| `FAKE_UTIME` | 拦截 utime 系列函数 |
| `FAKE_SLEEP` | 拦截 sleep / nanosleep / usleep / alarm / poll / ppoll |
| `FAKE_TIMERS` | 拦截 timer_settime / timer_gettime |
| `FAKE_PTHREAD` | 拦截 pthread_cond_timedwait |
| `FAKE_INTERNAL_CALLS` | 拦截 libc 内部 `__` 前缀函数（增强兼容性，如 JVM） |
| `PTHREAD_SINGLETHREADED_TIME` | 仅 `libfaketimeMT.so`：单线程化 `time()` 调用（防竞态） |

### 可选启用的宏

| 宏 | 说明 |
|----|------|
| `FAKE_SETTIME` | 拦截 `clock_settime` / `settimeofday` / `adjtime` |
| `FAKE_RANDOM` | 拦截 `getrandom()`（Linux 专用） |
| `FAKE_PID` | 拦截 `getpid()` |
| `FAKE_FILE_TIMESTAMPS` | 运行时通过 `FAKE_UTIME=1` 选择启用 utime 伪装 |
| `INTERCEPT_SYSCALL` | 拦截 glibc `syscall()`（Linux 专用） |
| `INTERCEPT_FUTEX` | 拦截 FUTEX 系统调用（需配合 `INTERCEPT_SYSCALL`） |
| `FORCE_MONOTONIC_FIX` | 强制 `CLOCK_MONOTONIC` 修复（解决测试挂起问题） |
| `FORCE_PTHREAD_NONVER` | 强制非版本化 pthread（同上） |
| `FAKE_STATELESS` | 禁用所有跨线程/跨进程状态共享 |
| `MULTI_ARCH` | wrapper 使用 `$LIB` 实现多架构自动选择 |
| `NO_ATFILE` | 禁用 `fstatat()` 组函数支持 |
| `SILENT` | 抑制 wrapper 在 libfaketime 环境中的警告 |

### 示例

```bash
# 启用 settime 拦截 + 随机数
FAKETIME_COMPILE_CFLAGS="-DFAKE_SETTIME -DFAKE_RANDOM" make

# 强制 monotonic 修复
FAKETIME_COMPILE_CFLAGS="-DFORCE_MONOTONIC_FIX" make

# 自定义安装路径
make PREFIX=/opt/local LIBDIRNAME='/lib'
```

---

## 六、faketime 命令行

```
faketime [选项] <时间戳> <程序> [参数...]
```

| 选项 | 说明 |
|------|------|
| `-m` | 使用多线程版库 `libfaketimeMT.so.1` |
| `-f` | 启用高级时间格式（支持 `x`、`i` 修饰符） |
| `-p <PID>` | 伪装进程 PID（需编译时 `-DFAKE_PID`） |
| `--exclude-monotonic` | 不伪装 `CLOCK_MONOTONIC` |
| `--disable-shm` | 禁用共享内存 |
| `--date-prog <PATH>` | 指定 GNU date 兼容程序路径 |
| `--help` | 显示帮助 |
| `--version` | 显示版本 |

### 示例

```bash
faketime 'last Friday 5 pm' date
faketime '2008-12-24 08:15:42' date
faketime -f '+2,5y x10,0' bash -c 'while true; do echo $SECONDS; sleep 1; done'
faketime -f '-7d i2,0'   bash -c 'while true; do date; sleep 1; done'
```

---

## 七、常见踩坑

| 问题 | 解决方案 |
|------|----------|
| Java/JVM 挂起 | 设置 `FAKETIME_DONT_FAKE_MONOTONIC=1` |
| `CLOCK_MONOTONIC` 测试挂起 | 编译时加 `-DFORCE_MONOTONIC_FIX` 或运行时设 `FAKETIME_FORCE_MONOTONIC_FIX=1` |
| 静态链接程序无效 | libfaketime 依赖 `LD_PRELOAD`，不支持静态链接 |
| setuid 程序无效 | 链接器不会对 setuid 程序启用 `LD_PRELOAD` |
| macOS `/bin/date` 无效 | SIP 保护，复制到非保护路径使用 |
| macOS `arm64e` 系统二进制不兼容 | 禁用 SIP + 启用实验性 ABI，或只用 `arm64` 用户态程序 |
| 共享内存残留报错 | 清理 `/dev/shm/faketime_shm_*` 和 `/dev/shm/sem.faketime_sem_*` |
| 多进程时间不共享 | 设 `FAKETIME_DONT_RESET=1` 防止子进程重置 |
| 修改配置文件不生效 | 设 `FAKETIME_NO_CACHE=1` 或减小 `FAKETIME_CACHE_DURATION` |
