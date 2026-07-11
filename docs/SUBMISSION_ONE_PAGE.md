# MoonEmbed 申报书

项目名称：MoonEmbed

项目标识：`wskwsk68/MoonEmbed`

项目链接：

- GitHub: https://github.com/wskwsk68/MoonEmbed
- GitLink: https://gitlink.org.cn/wskwsk68/MoonEmbed

项目简介：

MoonEmbed 是一个 MoonBit 原生的词向量加载与轻量语义检索库，面向本地、Wasm 和离线场景使用。项目支持 word2vec 文本、GloVe 文本与 word2vec 二进制词向量文件的解析，并提供余弦相似度搜索、词组查询和轻量近似索引，尽量避免依赖 Python、数据库或大型运行时。

核心内容：

- 解析常见词向量格式
- 归一化向量并进行余弦相似度检索
- 提供轻量桶式近似候选集
- 提供 CLI 示例、测试与 CI

项目价值：

MoonEmbed 适合浏览器展示、离线语义检索、教学示例和 MoonBit 生态实践。它不是通用向量数据库，而是一个更聚焦、更易集成的基础工具库，后续可继续扩展为短句嵌入、元数据过滤和更完整的 ANN 检索能力。

合规说明：

本项目以 MoonBit 为主要实现语言，采用 Apache-2.0 开源许可证，仓库公开可访问，并提供 README、测试、CI、示例程序与来源说明，满足比赛对工程质量和可复现性的要求。

仓库已按单一贡献者整理，并通过多次有效提交补充了代码、测试、文档与自查材料。
