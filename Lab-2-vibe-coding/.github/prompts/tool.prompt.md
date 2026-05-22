---
mode: agent
description: 生成一个客户端 @tool 函数
---

参考 `#file:tools/web_search.py` 与 `#file:.github/instructions/maf-tools.instructions.md`，
生成 `tools/${input:toolName}.py`：

- 用途（一句话中文）：${input:purpose}
- 输入参数（带类型注解 + 中文描述）：${input:inputs}
- 输出 pydantic 模型字段：${input:outputs}
- 真实调用方式（API URL / 环境变量名）：${input:liveBackend}
- mock 兜底：当 ${input:envKey} 未设置或调用失败时，返回一组合理的 ${input:toolName} 示例。

硬性要求：
1. async def。
2. pydantic BaseModel 入参/出参。
3. OpenTelemetry tracer span 包裹整段调用；记录 provider / cached / 主要参数。
4. `@tool(name=..., description=<中文：何时调用 + 输出含义>)`（agent-framework 1.4 起，旧 `@ai_function` 已改名为 `@tool`）。
5. 没有 print；用 logger。
6. 不在 import 时执行 IO。

生成后给我跑：
```
python -m py_compile tools/${input:toolName}.py
pytest tests/unit -k ${input:toolName}
```
