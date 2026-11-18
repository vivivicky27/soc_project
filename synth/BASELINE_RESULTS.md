# Butterfly 基础版综合结果

运行日期：2026-11-16。结果来自实际 Design Compiler 综合和 VCS 门级功能仿真。

## 做了什么，为什么

1. 沿用课程 lab3 的 TSMC 16 nm 标准单元库，用 Design Compiler 把现有
   `ntt_butterfly.sv` 转成门级网表。这样可以获得实际工艺库下的面积和延迟估计。
2. 添加 10 ns（100 MHz）时钟、输入输出延迟、时钟不确定性和输出负载约束。
   工具需要这些条件，才能判断电路是否有足够时间完成计算。
3. 先进行逻辑映射，再展开算术子模块，检查连接、时序约束、面积及 setup/hold。
   展开后不再保留未使用的除法商输出等算术辅助端口。
4. 初次映射发现 24 条 hold 违例，最差约 -0.06 ns。原因是输出寄存器使能
   逻辑中的短反馈路径。保持约束不变，使用 `set_fix_hold` 和 hold-only
   增量综合插入延时单元，最终 hold 违例清零。无需更改 RTL 功能。
5. 使用工艺库 Verilog 模型运行最终网表，全部 10065 组 Python golden
   向量通过，检查综合变换后的功能仍与参考模型一致。

## 最终结果

| 项目 | 结果 |
|---|---|
| 工具 | Design Compiler Y-2026.03；VCS Y-2026.03 |
| 工艺库 | N16ADFP_StdCelltt0p8v25c_ccs，TT / 0.8 V / 25°C |
| 目标时钟 | 10 ns，100 MHz |
| 标准单元总数 | 1026 |
| 组合单元 / 时序单元 | 1001 / 25 |
| 时序单元含义 | u、v 各 12 位，加 out_valid 1 位 |
| 黑盒 / 未映射逻辑 | 无黑盒；最终网表全部映射到标准单元 |
| 标准单元总面积 | 495.227531 µm² |
| 最差 setup slack | +4.17 ns，满足本次约束 |
| hold 违例 | 0；最小裕量报告四舍五入为 0.00 ns |
| 最大转换时间 / 最大电容违例 | 均为 0 |
| check_design | 通过，无最终连接警告 |
| check_timing | 无约束缺失或环路警告 |
| 门级功能仿真 | PASS，10065 组 Python 向量 |

面积为标准单元面积之和，不是芯片或 core 面积。库面积单位与 LEF 中对应
单元的宽×高一致（µm²）。组合面积包含缓冲器/反相器，不能重复相加。

setup slack 可理解为截止时间前还剩多少时间；正数表示在本次假设下满足要求。
hold 检查约束数据不要过早变化，不能靠降低时钟频率替代修复。

## 如何复现和查看

在 project 目录运行：

```bash
make synth
make sim-gate
```

原始证据：

- `build/synth/reports/area.rpt`：面积和单元数。
- `build/synth/reports/qor.rpt`：最终时序、面积、设计规则汇总。
- `build/synth/reports/constraints.rpt`：This design has no violated constraints。
- `build/synth/reports/check_design.rpt`：最终连接检查成功。
- `build/synth/reports/check_timing.rpt`：约束完整性检查。
- `build/synth/reports/qor_before_hold_fix.rpt`：修复前 hold 违例记录。
- `build/simulation_gate.log`：PASS: 10065 Python golden vectors checked against RTL。
- `build/synth/netlist/ntt_butterfly_mapped.v`：最终标准单元网表。

## 结论的范围

本次为逻辑综合，使用理想时钟、ZeroWireload，尚未考虑真实布线寄生参数。
输入输出延迟和负载是初始假设。只检查一个 TT 工艺角，不构成最终多角时序签核。
异步复位被设置为 false path，其同步释放和 recovery/removal 仍需后续处理。
门级仿真没有 SDF 回标且关闭时序检查，只验证功能；也不等同于形式等价验证。
布局布线后还需要重新检查时序、面积、DRC/LVS。功耗尚未评估。

本次已建立可比较的基础版，后续可以在相同库和约束下评估流水线及专用模约减。
