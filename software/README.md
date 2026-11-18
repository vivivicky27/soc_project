# 软件基线：完整 NTT 和加密演示

本目录实现 proposal 的纯软件基线：

```text
接收方生成 ML-KEM 密钥对
        ↓
发送方用公钥封装，得到共享秘密和 KEM 密文
        ↓
接收方用私钥解封装，恢复相同的共享秘密
        ↓
双方分别用 HKDF-SHA256 派生 AES-256 密钥
        ↓
AES-GCM 加密 / 解密消息，并验证认证标签
```

ML-KEM 内部的正向 NTT 已替换成我们自己的完整 256 点调度，每次调度
调用 896 次 butterfly。目前这些调用由 Python 完成，**没有调用 VCS、RTL
或真实芯片**。这里可以先验证软件逻辑，为后续接入硬件提供基线。

## 运行

学校当前 Python 3.9 环境已具备所需依赖，无需联网或 VCS 许可证：

```bash
cd /home/yj3494/soc/project/software
make demo
make test
make check
```

以上分别运行默认演示、软件回归、回归加演示。命令不带行尾注释，兼容当前终端。

可以改变消息和参数：

```bash
python3 demo.py --message "hello FPGA" --parameter 512
python3 demo.py --message "你好，测试消息" --parameter 1024
```

成功时 JSON 输出中的三个字段均为 `true`：

- `shared_secret_match`：发送方和接收方共享秘密一致。
- `plaintext_match`：恢复的消息与原始字节完全一致。
- `tampered_tag_rejected`：改变 AES-GCM 标签后解密失败。

另外会显示消息、公开数据的长度以及实际正向 NTT / butterfly 调用数。
默认 ML-KEM-768 演示为 15 次正向 NTT、13440 次 butterfly；这包含密钥
生成、封装、解封装中的正向变换，不能与单次 NTT 的 896 次混淆。
演示使用系统随机数，不打印或保存私钥、共享秘密或 AES 密钥。

## 文件和实现分工

| 文件 | 内容 |
|---|---|
| `ntt.py` | 单次 butterfly、旋转因子表、完整正向 NTT、可替换 backend |
| `mlkem_adapter.py` | 用独立子类把自己的正向 NTT 接入 ML-KEM |
| `demo.py` | 共享密钥建立、HKDF、AES-GCM、篡改标签检查 |
| `tests/test_software.py` | NTT、参考实现对照、三种参数、端到端回归 |
| `vendor/` | 固定版本 kyber-py 1.2.0 原始代码和许可证 |
| `THIRD_PARTY.md` | 依赖来源、版本和 wheel 校验值 |
| `SOFTWARE_RESULTS.md` | 已执行的测试和结果 |

ML-KEM 的其余计算（采样、哈希、逆 NTT、NTT 域乘法、编码、封装/解封装）
复用 kyber-py。HKDF 和 AES-GCM 使用 cryptography。第三方代码没有修改；
自定义 NTT 通过对象级别的子类接入，不全局修改参考实现，方便独立对照。

## NTT 如何接到现有硬件接口

软件 `backend(a, b, zeta)` 的输入输出约定与现有 RTL 一致：

```python
t = b * zeta % 3329
u = (a + t) % 3329
v = (a - t) % 3329
```

三个输入和两个输出均为 0～3328 的普通整数，无 Montgomery 缩放。
每层选择一个或多个旋转因子，遍历 128 对系数，共 7 层、896 次调用。
ML-KEM 库可能产生带符号中间系数，adapter 会在 NTT 边界先对 3329 取模。
旋转因子由 17 的幂及 7 位反转顺序生成，不使用官方 C 代码中的 Montgomery 表。

下一步可以实现同样调用形式的 RTL backend：把输入送进仿真器，驱动时钟和
`in_valid`，等 `out_valid` 后返回结果。只需把它传入
`make_mlkem(768, backend=rtl_backend)`；完整 NTT 的调度仍由 Python 负责。
这个桥接程序尚未实现，不能把当前演示称为软硬件联合仿真。

## 验证范围

测试既对照未修改的第三方 NTT，也用独立的直接多项式求值公式检查 NTT。
对于 512、768、1024 参数，固定测试随机输入后，比较替换 NTT 前后的
密钥、共享秘密和封装密文，并验证改变 KEM 密文时的隐式拒绝行为。
端到端测试覆盖空消息、中文和二进制消息。

这些是课程功能验证，不是 NIST 认证或完整 ACVP 验证。kyber-py 定位为学习
实现，本项目用于课程演示；没有做生产安全、常数时间或性能保证。
软件基线无需布局布线，仿真桥接和 ASIC 物理设计后续单独进行。
