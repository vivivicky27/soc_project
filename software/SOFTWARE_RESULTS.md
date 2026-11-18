# 纯软件验证结果

日期：2026-11-16。环境：学校 ecs04，Python 3.9.25，cryptography 36.0.1，
目录内固定依赖 kyber-py 1.2.0。运行命令：`make check`。

五项测试全部通过：

| 测试 | 内容 / 结果 |
|---|---|
| butterfly_and_validation | 示例 10,4,3 → 22,3327；拒绝非法输入 |
| ntt_matches_unmodified_reference | 4 组固定输入 + 100 组固定种子随机多项式；全部 256 个输出一致；每次 896 个 butterfly；不修改输入 |
| ntt_against_direct_mathematical_definition | 与独立 O(n²) 偶/奇多项式求值公式逐系数一致 |
| integrated_mlkem_matches_reference_all_parameters | 512/768/1024：与未修改实现的密钥和封装结果逐字节一致；解封装成功；篡改 KEM 密文后的隐式拒绝结果一致 |
| end_to_end_messages | 3 种参数 × 空消息/中文/二进制消息；共享秘密一致，消息恢复，认证标签篡改被拒绝 |

默认演示实际输出：

```json
{
  "mode": "software-only",
  "algorithm": "ML-KEM-768 + HKDF-SHA256 + AES-256-GCM",
  "shared_secret_match": true,
  "plaintext_match": true,
  "tampered_tag_rejected": true,
  "public_key_bytes": 1184,
  "kem_ciphertext_bytes": 1088,
  "message_bytes": 25,
  "aes_ciphertext_and_tag_bytes": 41,
  "forward_ntt_calls": 15,
  "butterfly_calls": 13440,
  "recovered_message": "你好，NTT butterfly！"
}
```

这里的 butterfly 是 Python 软件后端，尚未调用 project 的 RTL。
没有进行完整 ACVP/NIST 验证，也没有测量硬件加速效果。
