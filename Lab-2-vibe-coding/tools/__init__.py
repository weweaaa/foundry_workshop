"""Workshop client-side tools — research scenario.

Tools:
- web_search  : 公开网页检索（Bing / Google CSE / mock 自动回退）
- web_fetch   : 拉取一个 URL 的可读正文
- report_builder : 把 sections + sources 组装成 persona 契约里的最终报告 JSON

每个 tool 都用 @tool 装饰，可被 MAF Agent 自动注册。
"""
