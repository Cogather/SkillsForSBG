# Mock External Dependency - 外部依赖本地打桩技能

## 适用场景

当Go项目依赖外部模块但无法获取时，通过本地stub实现编译和测试：
- 内部私服依赖（需要VPN/权限）
- 第三方私有仓库（无法公开访问）
- 企业内部SDK（本地开发环境无权限）
- 版本锁定依赖（需要固定版本但无法获取）
- 快速原型开发（暂时不需要真实实现）

---

## 核心机制

**Go Modules Replace指令**：将外部依赖映射到本地stub模块

```go
replace <external-module> => ./stubs/<module-name>
```

---

## 目录结构模板

```
<project-root>/src/
├── go.mod                          # 主模块
├── stubs/                          # 本地stub目录（可命名为mocks/local等）
│   ├── <module-A>/                 # stub模块A
│   │   ├── go.mod                  # stub模块定义
│   │   └── api/                    # 包结构（保持与原模块一致）
│   │       ├── package1/
│   │       │   └ package1.go       # 接口 + mock实现
│   │       └ package2/
│   │       └ base/
│   │           └ base.go           # 公共接口定义
│   ├── <module-B>/                 # stub模块B（可包含多个子包）
│   │   ├── go.mod
│   │   ├── submodule1/
│   │   └ submodule2/
│   └── <domain>/<path>/            # 带域名的模块（如 code.company.com/xxx）
│       ├── go.mod
│       └ api/
```

---

## 实现步骤（5步法）

### 步骤1：创建stub模块目录

```bash
# 基础模块
mkdir -p src/stubs/<module-name>/<package-path>

# 带域名模块
mkdir -p src/stubs/<domain>/<path>/<package-path>

# 示例1：基础模块
mkdir -p src/stubs/AlarmSDK/api/alarmapi
mkdir -p src/stubs/AlarmSDK/api/base

# 示例2：带域名模块
mkdir -p src/stubs/code.company.com/fusionstage/auditlog
```

---

### 步骤2：定义stub模块go.mod

**文件**：`src/stubs/<module-name>/go.mod`

```go
module <module-name>  // 必须与外部依赖名一致

go 1.21  // 使用项目统一的Go版本
```

**示例**：
```go
// 基础模块
module AlarmSDK
go 1.21

// 带域名模块
module code.company.com/fusionstage/auditlog
go 1.21

// 多子包模块
module EnterpriseSDK
go 1.21
```

---

### 步骤3：定义接口（接口层）

**文件**：`stubs/<module-name>/base/base.go`

**原则**：
- 只定义实际使用的接口和类型
- 保持接口签名与真实SDK一致
- 类型、常量、枚举完整定义

```go
package base

// 接口定义
type ServiceManager interface {
    Init(config string) error           // 只定义实际调用的方法
    Execute(action string) bool         // 不需要定义未使用的方法
}

type ServiceObject interface {
    SetParameter(key, value string)
    GetParameter(key string) string
}

// 类型定义
type ActionType int

const (
    ActionCreate ActionType = 0
    ActionUpdate ActionType = 1
    ActionDelete ActionType = 2
)

// 常量定义
const (
    DefaultTimeout = 30
    MaxRetryTimes  = 3
)
```

---

### 步骤4：实现mock（实现层）

**文件**：`stubs/<module-name>/api/service/service.go`

**Mock策略**：

| 函数类型 | Mock方式 | 适用场景 |
| --- | --- | --- |
| **初始化函数** | 返回mock实例 | `NewService() → return &mockService{}` |
| **查询函数** | 返回固定值/环境变量 | `GetConfig() → return os.Getenv("CONFIG")` |
| **操作函数** | 返回成功/nil | `Execute() → return true` 或 `return nil` |
| **回调注册** | 空实现 | `RegisterCallback(cb) {}` |
| **判断函数** | 返回固定布尔值 | `IsReady() → return true` |

**示例1：基础mock实现**
```go
package service

import (
    "os"
    "<module-name>/base"
)

// NewService 初始化函数，返回mock实例
func NewService(config string) base.ServiceManager {
    return &mockServiceManager{config: config}
}

// GetConfig 查询函数，从环境变量读取
func GetConfig() string {
    return os.Getenv("SERVICE_CONFIG")  // 支持环境变量注入
}

// mockServiceManager mock实现
type mockServiceManager struct {
    config string
}

func (m *mockServiceManager) Init(config string) error {
    m.config = config
    return nil  // 假装初始化成功
}

func (m *mockServiceManager) Execute(action string) bool {
    return true  // 假装执行成功
}

// mockServiceObject mock实现
type mockServiceObject struct {
    params map[string]string
}

func (o *mockServiceObject) SetParameter(key, value string) {
    if o.params == nil {
        o.params = make(map[string]string)
    }
    o.params[key] = value  // 记录参数，便于测试验证
}

func (o *mockServiceObject) GetParameter(key string) string {
    return o.params[key]  // 返回记录的参数
}
```

**示例2：单例mock**
```go
package monitor

type MonitorSdk struct{}

func (m *MonitorSdk) Init(appID string) error {
    return nil
}

func (m *MonitorSdk) Report(metricID int, value float64) error {
    return nil
}

// 导出单例实例
var MonitorSdkInstance = &MonitorSdk{}
```

**示例3：空实现**
```go
package ntp

func Init() {}  // 完全空实现

func SyncTime() error {
    return nil  // 假装同步成功
}
```

---

### 步骤5：主go.mod添加replace

**文件**：`src/go.mod`

```go
module <your-project>

go 1.21

require (
    <module-A> v0.0.0-00010101000000-000000000000  // 版本号不重要
    <module-B> v1.2.3                              // 或使用真实版本
    <domain>/<path> v1.0.0
)

// replace指令：映射到本地stubs
replace (
    <module-A> => ./stubs/<module-A>
    <module-B> => ./stubs/<module-B>
    <domain>/<path> => ./stubs/<domain>/<path>
)
```

**示例**：
```go
module MyApp

go 1.21

require (
    AlarmSDK v0.0.0-00010101000000-000000000000
    EnterpriseSDK v1.2.3
    code.company.com/fusionstage/auditlog v1.0.0
    github.com/private-org/internal-lib v0.1.0
)

replace (
    AlarmSDK => ./stubs/AlarmSDK
    EnterpriseSDK => ./stubs/EnterpriseSDK
    code.company.com/fusionstage/auditlog => ./stubs/code.company.com/fusionstage/auditlog
    github.com/private-org/internal-lib => ./stubs/github.com/private-org/internal-lib
)
```

---

## 最佳实践

### 1. 接口定义原则

**只定义实际使用的接口**：

```go
// ❌ 错误：定义所有接口（过度实现）
type FullSDK interface {
    Init() error
    Start() error
    Stop() error
    Restart() error
    Pause() error
    Resume() error
    GetStatus() string
    SetConfig(config string) error
    // ... 20个方法
}

// ✅ 正确：只定义实际调用的2个方法
type SDK interface {
    Init() error        // main.go调用了
    GetStatus() string  // service.go调用了
}
```

---

### 2. 环境变量支持

**适用场景**：查询函数需要返回动态值（如节点IP、配置参数）

```go
// ❌ 硬编码固定值
func GetNodeIP() string {
    return "192.168.1.100"  // 测试环境IP可能不同
}

// ✅ 支持环境变量
func GetNodeIP() string {
    ip := os.Getenv("NODE_IP")
    if ip == "" {
        ip = "127.0.0.1"  // 默认值
    }
    return ip
}
```

---

### 3. 多子包模块处理

**场景**：一个模块包含多个子包（如EnterpriseSDK包含LogSDK、AuthSDK、MonitorSDK）

**方案1：单一stub模块（推荐）**
```
stubs/EnterpriseSDK/
├── go.mod               # module EnterpriseSDK
├── LogSDK/
│   └ logger.go
├── AuthSDK/
│   └ auth.go
└── MonitorSDK/
    └ monitor.go
```

**引用路径**：`EnterpriseSDK/LogSDK`

**方案2：拆分stub模块**
```
stubs/LogSDK/
├── go.mod               # module LogSDK
└── logger.go

stubs/AuthSDK/
├── go.mod               # module AuthSDK
└── auth.go
```

**引用路径**：独立模块

---

### 4. 参数记录（测试友好）

**适用场景**：测试需要验证调用参数

```go
type mockAlarm struct {
    params map[string]string  // 记录设置参数
}

func (a *mockAlarm) SetParameter(key, value string) {
    if a.params == nil {
        a.params = make(map[string]string)
    }
    a.params[key] = value
}

// 测试时可访问mock实例验证参数
func TestAlarmParameters(t *testing.T) {
    alarm := &mockAlarm{}
    alarm.SetParameter("level", "critical")
    alarm.SetParameter("source", "system")
    
    assert.Equal(t, "critical", alarm.params["level"])
    assert.Equal(t, "system", alarm.params["source"])
}
```

---

### 5. 日志记录（调试友好）

**适用场景**：需要观察调用流程

```go
import "log"

func (m *mockService) Execute(action string) bool {
    log.Printf("[Mock] Execute called: action=%s", action)  // 记录调用
    return true
}

func (m *mockService) Init(config string) error {
    log.Printf("[Mock] Init called: config=%s", config)
    return nil
}
```

---

## Mock策略决策表

| 场景 | 函数类型 | Mock实现 | 示例 |
| --- | --- | --- | --- |
| **初始化** | `NewXxx()` | 返回mock实例 | `return &mockManager{}` |
| **配置查询** | `GetXxx()` | 环境变量/固定值 | `os.Getenv("XXX")` 或 `"fixed-value"` |
| **状态判断** | `IsXxx()` | 固定布尔值 | `return true` |
| **操作执行** | `DoXxx()` | 返回成功 | `return nil` 或 `return true` |
| **计数统计** | `Count()` | 固定数值 | `return 0` |
| **列表查询** | `List()` | 空列表 | `return []Item{}` |
| **回调注册** | `Register()` | 空实现 | `func Register(cb Callback) {}` |
| **时间查询** | `GetTime()` | 当前时间 | `return time.Now()` |

---

## 版本号处理

### 场景1：不知道真实版本

使用零版本：
```go
require <module-name> v0.0.0-00010101000000-000000000000
```

### 场景2：知道真实版本

使用真实版本（保持一致性）：
```go
require <module-name> v1.2.3
```

### 场景3：版本冲突

使用replace强制版本：
```go
replace <module-name> v1.2.3 => ./stubs/<module-name>
```

---

## 验证与调试

### 验证stub生效

```bash
# 1. 查看模块映射
go list -m <module-name>
# 输出：<module-name> => ./stubs/<module-name>

# 2. 清理并重新加载
go mod tidy
go clean -modcache
go mod download

# 3. 验证编译
go build ./...

# 4. 运行测试
go test ./...
```

### 调试replace问题

```bash
# 查看依赖图
go mod graph | grep <module-name>

# 查看why依赖
go mod why <module-name>

# 验证路径
ls -la src/stubs/<module-name>/go.mod
```

---

## 常见错误与解决

### 错误1：module名不一致

```
错误：module name mismatch
原因：stub go.mod的module名与外部依赖名不同
解决：确保module名完全一致（包括域名）
```

**示例**：
```go
// 外部依赖：github.com/private-org/internal-lib
// stub go.mod：
module github.com/private-org/internal-lib  // ✅ 完全一致
go 1.21
```

---

### 错误2：包路径不匹配

```
错误：cannot find package
原因：stub包路径与引用路径不一致
解决：stub内部包路径必须与真实SDK包结构一致
```

**示例**：
```go
// 引用：import "EnterpriseSDK/logger/api"
// stub目录结构：
stubs/EnterpriseSDK/logger/api/logger.go  // ✅ 路径一致
```

---

### 错误3：接口签名不匹配

```
错误：cannot use mock (type) as type (missing method)
原因：stub接口方法与实际调用不一致
解决：根据编译错误补充缺失方法
```

**示例**：
```go
// 编译错误：missing method Close()
// 补充方法：
func (m *mockService) Close() error {
    return nil
}
```

---

### 错误4：缺少类型定义

```
错误：undefined: ActionType
原因：stub缺少类型/常量/枚举定义
解决：在base包补充类型定义
```

**示例**：
```go
// base/base.go
type ActionType int

const (
    ActionCreate ActionType = 0
)
```

---

## 完整示例：创建第三方SDK stub

### 场景：依赖`github.com/enterprise/logger-sdk`

**项目实际调用**：
```go
import "github.com/enterprise/logger-sdk/api"

func main() {
    manager := api.NewLoggerManager("app-name")
    manager.Init()
    
    logger := api.CreateLogger("service-1")
    logger.SetLevel("INFO")
    logger.Log("message")
}
```

---

### 步骤1：创建stub目录

```bash
mkdir -p src/stubs/github.com/enterprise/logger-sdk/api
```

---

### 步骤2：定义stub模块

**文件**：`src/stubs/github.com/enterprise/logger-sdk/go.mod`
```go
module github.com/enterprise/logger-sdk

go 1.21
```

---

### 步骤3：实现mock

**文件**：`src/stubs/github.com/enterprise/logger-sdk/api/logger.go`
```go
package api

import "log"

// NewLoggerManager 初始化函数
func NewLoggerManager(appName string) LoggerManager {
    log.Printf("[Mock] NewLoggerManager called: appName=%s", appName)
    return &mockLoggerManager{appName: appName}
}

// CreateLogger 创建logger实例
func CreateLogger(serviceName string) Logger {
    log.Printf("[Mock] CreateLogger called: serviceName=%s", serviceName)
    return &mockLogger{service: serviceName, level: "INFO"}
}

// LoggerManager 接口
type LoggerManager interface {
    Init() error
}

// Logger 接口
type Logger interface {
    SetLevel(level string)
    Log(message string)
}

// mock实现
type mockLoggerManager struct {
    appName string
}

func (m *mockLoggerManager) Init() error {
    log.Printf("[Mock] LoggerManager.Init called")
    return nil
}

type mockLogger struct {
    service string
    level   string
}

func (l *mockLogger) SetLevel(level string) {
    l.level = level
    log.Printf("[Mock] Logger.SetLevel: service=%s, level=%s", l.service, level)
}

func (l *mockLogger) Log(message string) {
    log.Printf("[Mock] Logger.Log: service=%s, level=%s, message=%s", 
        l.service, l.level, message)
}
```

---

### 步骤4：主go.mod配置

**文件**：`src/go.mod`
```go
module MyApp

go 1.21

require github.com/enterprise/logger-sdk v1.0.0

replace github.com/enterprise/logger-sdk => ./stubs/github.com/enterprise/logger-sdk
```

---

### 步骤5：验证

```bash
go mod tidy
go build ./...
go run main.go

# 输出：
# [Mock] NewLoggerManager called: appName=app-name
# [Mock] LoggerManager.Init called
# [Mock] CreateLogger called: serviceName=service-1
# [Mock] Logger.SetLevel: service=service-1, level=INFO
# [Mock] Logger.Log: service=service-1, level=INFO, message=message
```

---

## 进阶场景

### 场景1：Stub支持配置注入

**需求**：测试时需要控制mock行为

**实现**：
```go
package api

import "os"

// GetTimeout 从环境变量读取超时时间
func GetTimeout() int {
    timeout := os.Getenv("SDK_TIMEOUT")
    if timeout == "" {
        return 30  // 默认30秒
    }
    // 解析环境变量
    t, _ := strconv.Atoi(timeout)
    return t
}

// 测试时设置环境变量
func TestTimeout(t *testing.T) {
    os.Setenv("SDK_TIMEOUT", "60")
    timeout := GetTimeout()
    assert.Equal(t, 60, timeout)
}
```

---

### 场景2：Stub支持状态记录

**需求**：测试验证调用顺序和次数

**实现**：
```go
package api

type mockService struct {
    callCount int
    callOrder []string
}

func (m *mockService) Init() error {
    m.callCount++
    m.callOrder = append(m.callOrder, "Init")
    return nil
}

func (m *mockService) Start() error {
    m.callCount++
    m.callOrder = append(m.callOrder, "Start")
    return nil
}

// 提供查询方法
func (m *mockService) GetCallCount() int {
    return m.callCount
}

func (m *mockService) GetCallOrder() []string {
    return m.callOrder
}

// 测试验证
func TestCallSequence(t *testing.T) {
    svc := &mockService{}
    svc.Init()
    svc.Start()
    
    assert.Equal(t, 2, svc.GetCallCount())
    assert.Equal(t, []string{"Init", "Start"}, svc.GetCallOrder())
}
```

---

### 场景3：Stub支持错误模拟

**需求**：测试错误处理逻辑

**实现**：
```go
package api

import "os"

// Init 支持错误模拟
func Init() error {
    simulateError := os.Getenv("SDK_SIMULATE_ERROR")
    if simulateError == "true" {
        return errors.New("simulated init error")
    }
    return nil
}

// 测试错误处理
func TestErrorHandling(t *testing.T) {
    os.Setenv("SDK_SIMULATE_ERROR", "true")
    err := Init()
    assert.Error(t, err)
}
```

---

## 项目适配指南

### 适配步骤

1. **识别依赖**：列出项目所有无法获取的外部依赖
2. **分析调用**：确定每个依赖实际调用的接口和方法
3. **创建stub**：按照5步法逐个创建
4. **验证编译**：`go build ./...`
5. **运行测试**：`go test ./...`

### 依赖清单模板

| 模块名 | 类型 | Stub路径 | 状态 |
| --- | --- | --- | --- |
| `<module-A>` | CSP SDK | `stubs/<module-A>` | ✅ 已创建 |
| `<module-B>` | 企业SDK | `stubs/<module-B>` | ⏳ 待创建 |
| `<domain>/<path>` | 内部库 | `stubs/<domain>/<path>` | ⏳ 待创建 |

---

## 参考资料

- **Go Modules官方文档**：https://go.dev/ref/mod#go-mod-file-replace
- **Replace指令详解**：https://go.dev/blog/versioning-proposal
- **项目示例**：
  - GIDS项目：`GlobalInstanceDeliverService/src/stubs/`
  - BrowserGateway项目：`BrowserGateway/src/mocks/`（Java项目）

---

## 总结

**核心要点**：
1. ✅ 使用`replace`指令映射外部依赖到本地
2. ✅ stub模块名必须与外部依赖名完全一致
3. ✅ 只定义实际使用的接口和方法
4. ✅ mock返回固定值/环境变量/空实现
5. ✅ 保持包路径结构一致

**适用项目**：
- ✅ Go项目（使用Go Modules）
- ✅ 任何无法获取外部依赖的场景
- ✅ 本地开发/测试/原型验证
