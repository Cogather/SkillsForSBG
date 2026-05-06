---
name: mock-external-service
description: Add or adjust HTTP Mock routes for external dependencies (GIDS, stats, etc.) so local integration matches caller contracts. Use when the gateway or scripts call remote HTTP services and you need a test-client Mock that mirrors method, path, fields, and status codes.
license: MIT
metadata:
  author: sbg
  version: "1.0"
---

# Mock 外部依赖服务

在**现有 Mock 工程**上增量实现外系统替身，契约与 Java/Python 调用方一致。

## 何时使用

- 调用方已存在（网关配置里的 `*.endpoint`、RestTemplate/WebClient、Python `httpx` 等）。
- 需要**补全或修改** Mock 路由与响应体，而不是从零定义一套新协议。

## 用户需提供

- 调用方所在模块或配置项（便于对齐 endpoint）。
- 每个依赖：**HTTP 方法、路径、Query/Body 字段、期望状态码与 JSON 形状**。
- 与生产/正式文档不一致之处须显式写出。

## 必须遵守

1. **契约优先**：先固定上述契约，再写实现。
2. **字段名**与调用方代码一致；不要随意改名。
3. **风格一致**：与同文件内已有路由相同框架、错误处理、启动方式。
4. **边界**：Mock 仅用于联调与自动化，不扩展为完整业务实现。

## 本仓库参考路径

- Mock 代码：`Test/browsergateway-test-client/src/mock/`（按需编辑现有文件，如 `gids_mock_server.py`）。
- 网关将外系统指到本机时：对齐 `BrowserGateway/BrowserGateway/browser-gateway/src/main/resources/application*.yaml` 中相关 endpoint / profile。

## 实施步骤

1. 阅读调用方（Java 或 Python）中实际请求的 URL、方法与序列化字段。
2. 在现有 Mock 服务中增加或修改路由，返回体可被调用方解析。
3. 本地按联调顺序启动依赖后，确认调用方无连接/JSON 解析错误；可用 curl 自测新路径。

## 验收

- 约定启动顺序下，调用方日志无连接失败、无解析异常。
- curl 或测试客户端能命中新路径并得到约定 JSON。
