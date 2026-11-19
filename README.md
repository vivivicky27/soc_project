# NTT butterfly ASIC 与软件演示

## 软件入口

已将跑通的软件基线放入 `software/`，包括完整 256 点正向 NTT、ML-KEM、
HKDF 和 AES-GCM 加密解密演示，以及参考实现、原始许可证和软件测试。

在 project 目录直接运行（命令不带行尾注释，兼容当前终端）：

```bash
cd /home/yj3494/soc/project
make demo
make test
```

`make demo` 运行纯软件演示，`make test` 运行五项软件回归；也可分别使用
`make software-demo`、`make software-test`。`make software-check` 会运行
单次 butterfly golden model 测试、完整软件测试和演示。

自定义消息：

```bash
python3 software/demo.py --message "hello NTT" --parameter 768
```

目前 `software/` 的 butterfly 仍由 Python 执行，尚未接入 RTL 联合仿真。
详细实现和范围见 [software/README.md](software/README.md)。
RTL 测试继续使用 `make sim`、`make sim-golden`，综合使用 `make synth`。

## 硬件基础版

本版只实现一次 CT butterfly，模数为 3329：

```text
t = (b * zeta) mod 3329
u = (a + t) mod 3329
v = (a - t) mod 3329
```

例如 a=10、b=4、zeta=3 时，u=22、v=3327。

## 接口和时序

- `a`、`b`、`zeta`：12 位无符号输入，调用方保证范围为 0～3328。
- 使用普通整数模表示，不使用 Montgomery 或 K-reduction 缩放。
- `rst_n`：低有效异步复位，清零输出和 `out_valid`。
- `in_valid=1` 时，每个时钟上升沿采样一组输入；该沿之后，输出寄存器和 `out_valid` 更新。
- 输入在一个周期内经过组合计算，在下一个上升沿输出；没有额外输入寄存级。
- 连续每拍都可以输入；没有 `ready` 或输出反压，下游必须能接收每个有效结果。
- `in_valid=0` 时，`out_valid` 清零，`u/v` 保持上次值。

## 仿真

在 project 目录运行 `make sim`，需要环境中配置好 VCS 和许可证。
测试包含示例、边界组合、10000 次随机事务、连续输入、空拍和运行中复位。
日志在 `build/compile.log` 和 `build/simulation.log`。

## Python golden model

`model/golden_model.py` 是独立于 RTL 的数学参考模型，只计算单次正向
butterfly，不模拟时钟或流水线，也尚未实现完整 256 点 NTT。
输入要求与 RTL 相同：普通整数表示、范围 0～3328；越界会报错。
Python 的取模会自动把负数转换为非负余数。

在 project 目录运行（仅使用 Python 标准库，需要 Python 3.9 或更新版本）：

```bash
# 计算一次，输出 u=22, v=3327
python3 model/golden_model.py calc 10 4 3

# 检查已知答案、非法输入、模运算恒等式和随机向量可复现性
make model-test

# 生成 10065 行测试向量：一个示例、64 个边界组合、10000 个随机输入
make vectors

# 使用 Python 生成的答案检查真实 RTL；需要 VCS 和许可证
make sim-golden
```

测试向量在 `build/butterfly_vectors.txt`，每行是十进制的 `a b zeta u v`，
没有表头。固定默认随机种子为 1，也可以指定：

```bash
python3 model/golden_model.py vectors build/custom.txt --count 500 --seed 42
```

其他 Python 程序可以用 `from model.golden_model import butterfly` 导入
（从 project 目录运行），然后调用 `u, v = butterfly(10, 4, 3)`。
`make model-test` 通过只表示 Python 模型自身检查通过；RTL 的正确性仍须
由 `make sim` 和 `make sim-golden` 实际仿真确认。

## 基础版 ASIC 综合

`synth/run.tcl` 使用 Synopsys Design Compiler，把 RTL 映射到课程实验的
TSMC 16 nm 标准单元库（TT、0.8 V、25°C）。这是逻辑综合，不需要创建
课程 lab3 的物理设计库，也不会改动其他实验的文件。

`synth/constraints.sdc` 指定 10 ns 时钟（100 MHz）、0.1 ns 时钟不确定性、
输入/输出最大延迟 2 ns、最小延迟 0.5 ns，以及 0.005 pF 输出负载。
这些是初始接口假设，后续系统集成时需要确认。异步复位路径排除在本次时序检查外，
系统必须保证复位同步释放；本次不包含复位 recovery/removal 签核。

```bash
make synth     # 综合、展开算术子模块、修复短路径 hold、导出报告和网表
make sim-gate  # 用 Python 向量验证综合后的标准单元网表
```

`sim-gate` 使用课程库的 Verilog 功能模型，关闭时序检查、没有 SDF 回标；
用于检查网表计算功能，不证明真实布线延迟满足时序。

主要输出（全部位于 build，make clean 会删除）：

| 文件 | 用途 |
|---|---|
| `build/synth/reports/area.rpt` | 标准单元面积与数量，不是芯片总面积 |
| `build/synth/reports/timing_setup.rpt` | 最慢路径与 setup 裕量 |
| `build/synth/reports/timing_hold.rpt` | 最短路径与 hold 裕量 |
| `build/synth/reports/constraints.rpt` | 尚未满足的约束 |
| `build/synth/reports/check_design.rpt` | 电路连接检查 |
| `build/synth/reports/check_timing.rpt` | 时序约束完整性检查 |
| `build/synth/reports/qor.rpt` | 面积和时序汇总 |
| `build/synth/netlist/ntt_butterfly_mapped.v` | 标准单元门级网表 |
| `build/synth/netlist/ntt_butterfly.ddc` | Design Compiler 数据库 |
| `build/synth/netlist/ntt_butterfly.sdc` | 导出的时序约束 |
| `build/simulation_gate.log` | 门级功能仿真结果 |

默认库位置沿用 lab3；如环境不同，可通过 `BUTTERFLY_TARGET_DB` 指定 .db，
通过 `CELL_VERILOG` 指定相匹配的标准单元 Verilog 模型。
目前使用理想时钟和 ZeroWireload，不包含布线寄生参数；满足本次 100 MHz
约束仅是综合阶段结论，仍需在布局布线后、多工艺角下重新验证。

## 本版范围

模乘直接使用常数 `% 3329`，用于建立可验证的基础 RTL。
还没有做专用模约减优化或内部流水线。基础版已配置 ASIC 综合流程；
布局布线、最终时序签核和功耗分析尚未完成。
本模块不包含完整 NTT 的存储、旋转因子表和调度；这些仍由外部软件负责。

## E0 and E1 RTL variants (hy3281)

The independent `butterfly_e0_hy3281` and `butterfly_e1_hy3281` modules are in
`rtl/`. Both accept a valid input on every clock and keep `in_ready` high.
E0 produces its registered result on the accepting edge. E1 produces its result
three rising edges after the accepting edge and can sustain one result per cycle.

Run their VCS testbenches with `make sim-hy3281`, or run
`make sim-e0-hy3281` and `make sim-e1-hy3281` individually. Outputs are under
`build/e0_hy3281/` and `build/e1_hy3281/`.
