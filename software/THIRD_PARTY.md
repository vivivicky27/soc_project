# 第三方来源

## kyber-py 1.2.0

- 项目：https://github.com/GiacomoPope/kyber-py
- 发布包：https://pypi.org/project/kyber-py/1.2.0/
- wheel 文件：`kyber_py-1.2.0-py3-none-any.whl`
- 下载地址：https://files.pythonhosted.org/packages/eb/50/0eda99082660ead34aebe2c212e40ff371ce7dd327d80c0980a7398f2d43/kyber_py-1.2.0-py3-none-any.whl
- SHA-256：`517f4c8f5009f5b4dfb8f4bfd0f6d631bf56e0cad3f709282e6450e5d8eda6aa`
- 2026-11-16 下载，先校验 wheel SHA-256 再解压。
- 未修改的代码位于 `vendor/kyber_py`，原始 distribution metadata 一并保留。
- 原许可证：`vendor/kyber_py-1.2.0.dist-info/licenses/LICENSE`（MIT 或 Apache-2.0）。
- 使用其 FIPS 203 ML-KEM 实现，不使用旧版 Kyber 类。
- 这不是 NIST 官方实现；上游将其定位为教学用途。

## cryptography 36.0.1

- 项目：https://cryptography.io/
- 使用系统已安装版本，测试时为 36.0.1；未复制其代码。
- 使用 AESGCM、HKDF-SHA256 和 InvalidTag，不自行编写 AES 或 KDF。
- 复现依赖版本记录在 requirements.txt；当前学校环境可直接运行。

## 算法依据

- FIPS 203：https://doi.org/10.6028/NIST.FIPS.203
- NTT 使用普通模表示，与本项目的 12 位 butterfly 接口一致。
- 本项目自己编写的 adapter 和调度见 `mlkem_adapter.py`、`ntt.py`。
