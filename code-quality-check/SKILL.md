---
name: code-quality-check
description: Check code quality for common defects in Go/Java/Python code, including unused variables, missing imports, context issues, singleton concurrency safety, error handling, and design inconsistencies.
license: MIT
metadata:
  author: sbg
  version: "1.0"
---

# 代码质量检查 Skill

检查代码中的常见缺陷，确保代码质量符合最佳实践。适用于详设文档中的代码片段检查、实现前的代码预审。

## 何时使用

- **代码生成后质量预检**：AI生成代码后，自动检查常见缺陷（未使用变量、缺失导入、context nil等）
- **完成Story详设文档后**：检查详设文档中的代码片段质量，确保设计正确
- **代码提交前**：进行质量预检，避免提交有缺陷的代码
- **发现代码缺陷**：需要系统性排查时，按清单逐项检查
- **代码评审辅助**：评审他人代码时，快速定位潜在问题

---

## 检查清单

### 0. AI生成代码常见问题（必查项）

AI生成代码时容易出现以下问题，**每次生成代码后必须检查**：

| 检查项 | 问题类型 | 常见场景 | 严重度 |
| --- | --- | --- | --- |
| **臆造导入路径** | 编译错误 | 导入不存在或错误的包路径（如`GIDS/adapter/csp`实际不存在） | 高 |
| **臆造方法/函数** | 编译错误 | 调用不存在的方法（如`csp.GetNodeIP()`实际应为`manager.GetNodeIP()`） | 高 |
| **臆造配置项** | 运行错误 | 使用不存在的环境变量或配置项（应复用现有配置） | 高 |
| **未使用变量** | 编译错误 | 定义变量后忘记在代码中使用 | 高 |
| **缺失import** | 编译错误 | 使用符号但忘记导入对应包 | 高 |
| **context传nil** | 运行风险 | HTTP调用传入nil context而非`context.TODO()` | 中 |
| **单例无锁保护** | 并发风险 | 全局变量初始化无`sync.Once`保护 | 高 |
| **硬编码URL/IP** | 设计问题 | 应通过CSE服务发现或配置读取，而非硬编码 | 中 |
| **新建配置文件** | 设计问题 | 应复用现有环境变量/常量，而非新建配置文件 | 中 |

**检查方法**：
1. 生成代码后，先用`grep`搜索导入路径是否存在
2. 用`grep`搜索方法名是否在代码仓中存在
3. 用`grep`搜索环境变量名是否在其他代码中使用
4. 检查变量是否在后续代码中被引用

### 1. Go代码检查项

#### 1.1 变量与导入

| 检查项 | 问题类型 | 检查方法 | 严重度 |
| --- | --- | --- | --- |
| **未使用的变量** | 编译错误 | 定义变量后未在任何地方引用 | 高 |
| **未使用的import** | 编译错误 | 导入包但未使用其任何符号 | 高 |
| **缺失的import** | 编译错误 | 使用符号但未导入对应包 | 高 |
| **循环导入** | 编译错误 | 包A导入B，B导入A | 高 |

#### 1.2 并发安全

| 检查项 | 问题类型 | 检查方法 | 严重度 |
| --- | --- | --- | --- |
| **全局变量无锁保护** | 并发风险 | 全局单例变量多线程访问无`sync.Once`或锁 | 高 |
| **map并发读写** | 并发风险 | map被多个goroutine读写无`sync.RWMutex` | 高 |
| **channel未关闭** | 资源泄漏 | goroutine中channel未close或close后继续写入 | 中 |

#### 1.3 Context处理

| 检查项 | 问题类型 | 检查方法 | 严重度 |
| --- | --- | --- | --- |
| **context传nil** | 运行风险 | HTTP/DB调用传入nil context，应使用`context.TODO()`或`context.Background()` | 中 |
| **context未传递** | 超时失控 | 内层调用未接收外层context，无法传播超时/取消 | 中 |

#### 1.4 错误处理

| 检查项 | 问题类型 | 检查方法 | 严重度 |
| --- | --- | --- | --- |
| **忽略错误返回** | 运行风险 | 调用返回error但未检查处理 | 高 |
| **error仅打印** | 处理不当 | error仅log.Printf但未返回或处理，业务继续执行 | 中 |
| **panic滥用** | 健壮性问题 | 非初始化场景使用panic recover | 高 |

#### 1.5 资源管理

| 检查项 | 问题类型 | 检查方法 | 严重度 |
| --- | --- | --- | --- |
| **defer位置错误** | 资源泄漏 | defer在错误检查之前，可能导致资源未释放 | 高 |
| **HTTP Body未关闭** | 资源泄漏 | `resp.Body`未`defer resp.Body.Close()` | 高 |
| **文件未关闭** | 资源泄漏 | `os.File`未`defer file.Close()` | 高 |

---

### 2. Java代码检查项

#### 2.1 空值检查

| 检查项 | 问题类型 | 检查方法 | 严重度 |
| --- | --- | --- | --- |
| **NullPointerException风险** | 运行错误 | 调用可能为null的对象方法/属性前未判空 | 高 |
| **Optional滥用** | 设计问题 | Optional用于字段/参数而非返回值 | 中 |
| **空集合返回null** | 设计问题 | 方法返回空集合时返回null而非空List/Set | 中 |

#### 2.2 并发安全

| 检查项 | 问题类型 | 检查方法 | 严重度 |
| --- | --- | --- | --- |
| **静态变量并发访问** | 并发风险 | static变量多线程读写无同步机制 | 高 |
| **@Autowired字段注入** | 注入风险 | 字段注入而非构造器注入，难以测试和空值检查 | 低 |
| **线程池未关闭** | 资源泄漏 | ExecutorService未在`@PreDestroy`中shutdown | 高 |

#### 2.3 Spring规范

| 检查项 | 问题类型 | 检查方法 | 严重度 |
| --- | --- | --- | --- |
| **循环依赖** | 启动失败 | Bean A依赖B，B依赖A | 高 |
| **事务边界错误** | 数据风险 | @Transactional在private方法无效，或嵌套调用同一类方法 | 中 |
| **配置注入硬编码** | 配置风险 | 配置值硬编码而非`@Value`注入 | 中 |

---

### 3. Python代码检查项

#### 3.1 导入与模块

| 检查项 | 问题类型 | 检查方法 | 严重度 |
| --- | --- | --- | --- |
| **未使用的import** | 风格问题 | 导入模块但未使用 | 低 |
| **循环导入** | 运行错误 | 模块A导入B，B导入A（延迟导入可能解决） | 高 |
| **相对导入错误** | 运行错误 | 使用相对导入但包结构不匹配 | 高 |

#### 3.2 异常处理

| 检查项 | 问题类型 | 检查方法 | 严重度 |
| --- | --- | --- | --- |
| **裸except** | 风格问题 | `except:`捕获所有异常包括KeyboardInterrupt | 中 |
| **异常仅打印** | 处理不当 | 异常仅print/log但未raise或处理 | 中 |
| **异常信息丢失** | 调试困难 | `except Exception: pass`丢失异常信息 | 高 |

#### 3.3 类型与空值

| 检查项 | 问题类型 | 检查方法 | 严重度 |
| --- | --- | --- | --- |
| **None未检查** | 运行错误 | 变量可能为None但未if判断直接操作 | 高 |
| **类型不一致** | 类型错误 | 函数期望str但传入int等 | 中 |

---

### 4. 设计一致性检查

| 检查项 | 问题类型 | 检查方法 | 严重度 |
| --- | --- | --- | --- |
| **接口不一致** | 设计问题 | 多种模式（CSP/Custom）实现类字段/方法签名不一致 | 高 |
| **命名不规范** | 可读性问题 | 变量/方法命名不符合项目规范 | 中 |
| **结构体字段冗余** | 设计问题 | 定义字段但未使用，或与接口字段重复 | 中 |
| **注释缺失关键信息** | 文档问题 | 公共API缺少注释或注释不完整 | 低 |

---

## 检查流程

### 第一步：AI生成代码预检（必做）

**每次AI生成代码后，必须执行以下检查**：

1. **验证导入路径存在性**
   ```bash
   # 检查导入路径是否存在
   grep -r "adapter/csp" --include="*.go" src/
   grep -r "manager.GetNodeIP" --include="*.go" src/
   ```

2. **验证方法/函数存在性**
   ```bash
   # 检查调用的方法是否在代码仓中存在
   grep -r "func GetNodeIP" --include="*.go"
   grep -r "def GetNodeIP" --include="*.py"
   ```

3. **验证配置项存在性**
   ```bash
   # 检查环境变量是否在其他代码中使用
   grep -r "os.Getenv.*FM_CALLBACK" --include="*.go"
   grep -r "constants.EnvAppId" --include="*.go"
   ```

4. **检查未使用变量**
   - 人工检查：定义变量后是否有后续引用

5. **检查缺失import**
   - 人工检查：使用的符号是否都在import列表中

### 第二步：逐文件检查

1. **读取代码文件或代码片段**
2. **按检查清单逐项检查**
3. **记录问题：文件名、行号、问题类型、问题描述、修正建议**

### 第三步：汇总问题

按严重度分类输出：

```
## 高严重度问题（必须修正）

| 序号 | 文件 | 行号 | 问题类型 | 描述 | 修正建议 |
| --- | --- | --- | --- | --- | --- |
| 1 | xxx.go | 133 | 未使用变量 | nodeName定义后未使用 | 删除该行 |

## 中严重度问题（建议修正）

| 序号 | 文件 | 行号 | 问题类型 | 描述 | 修正建议 |
| --- | --- | --- | --- | --- | --- |

## 低严重度问题（可选修正）

| 序号 | 文件 | 行号 | 问题类型 | 描述 | 修正建议 |
| --- | --- | --- | --- | --- | --- |
```

### 第四步：提供修正代码

对每个高严重度问题提供修正后的代码片段。

---

## 输出格式

### 检查报告模板

```markdown
# 代码质量检查报告

## 检查范围
- 文件：xxx.go, xxx_test.go
- 语言：Go
- 检查时间：YYYY-MM-DD

## 问题统计
- 高严重度：X个
- 中严重度：Y个
- 低严重度：Z个

## 高严重度问题

### 问题1：未使用变量
- **文件**：fm_subscribe_request.go
- **行号**：133
- **问题描述**：变量`nodeName`定义后未在任何地方使用
- **修正建议**：删除该行
- **修正代码**：
  ```go
  // 原代码
  nodeName := os.Getenv(constants.NODENAME)
  
  // 修正后（删除该行）
  // 不需要nodeName变量
  ```

### 问题2：...

## 中严重度问题
...

## 低严重度问题
...

## 总体评价
- 代码质量：良好（X分）
- 主要问题：...
- 建议：...
```

---

## 常见修正示例

### Go修正示例

#### 1. 未使用变量
```go
// 问题代码
func NewFmSubscribeRequest() *FmSubscribeRequest {
    appId := os.Getenv("APPID")
    nodeName := os.Getenv("NODENAME")  // 未使用
    return &FmSubscribeRequest{AppId: appId}
}

// 修正后
func NewFmSubscribeRequest() *FmSubscribeRequest {
    appId := os.Getenv("APPID")
    return &FmSubscribeRequest{AppId: appId}
}
```

#### 2. 缺失import
```go
// 问题代码
func TestXXX(t *testing.T) {
    os.Setenv("KEY", "VALUE")  // 未导入os
}

// 修正后
import (
    "os"
    "testing"
)

func TestXXX(t *testing.T) {
    os.Setenv("KEY", "VALUE")
}
```

#### 3. context传nil
```go
// 问题代码
response, err := core.NewRestInvoker().ContextDo(nil, request)

// 修正后
response, err := core.NewRestInvoker().ContextDo(context.TODO(), request)
```

#### 4. 全局单例无锁
```go
// 问题代码
var instance *ServiceImpl

func NewService() Service {
    if instance != nil {
        return instance
    }
    instance = &ServiceImpl{}  // 多线程可能重复初始化
    return instance
}

// 修正后
var instance *ServiceImpl
var once sync.Once

func NewService() Service {
    once.Do(func() {
        instance = &ServiceImpl{}
    })
    return instance
}
```

### Java修正示例

#### 1. NullPointerException风险
```java
// 问题代码
String name = user.getName();  // user可能为null

// 修正后
if (user != null) {
    String name = user.getName();
}

// 或使用Optional
Optional.ofNullable(user).map(User::getName).orElse("");
```

#### 2. 线程池未关闭
```java
// 问题代码
@Component
public class XxxTask {
    private ScheduledExecutorService scheduler;
    
    @PostConstruct
    public void init() {
        scheduler = Executors.newSingleThreadScheduledExecutor();
    }
    // 缺少@PreDestroy
}

// 修正后
@Component
public class XxxTask {
    private ScheduledExecutorService scheduler;
    
    @PostConstruct
    public void init() {
        scheduler = Executors.newSingleThreadScheduledExecutor();
    }
    
    @PreDestroy
    public void destroy() {
        if (scheduler != null) {
            scheduler.shutdown();
        }
    }
}
```

---

## 注意事项

1. **优先检查高严重度问题**：编译错误、并发安全、资源泄漏必须修正
2. **结合项目规范**：检查时参考项目的CLAUDE.md和现有代码风格
3. **提供具体修正代码**：不只指出问题，还要给出可执行的修正方案
4. **区分详设代码与生产代码**：详设文档中的代码片段可能不完整，检查时标注"需确认"