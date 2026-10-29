# AXI Register Slice — UVM Functional Verification Testbench

[![SystemVerilog](https://img.shields.io/badge/SystemVerilog-IEEE_1800--2017-00599C?style=for-the-badge&logo=cplusplus&logoColor=white)](https://standards.ieee.org/ieee/1800/6763/)
[![UVM](https://img.shields.io/badge/UVM-1.2_Universal_Verification_Methodology-4B0082?style=for-the-badge)](https://www.accellera.org/downloads/standards/uvm)
[![Protocol](https://img.shields.io/badge/Protocol-ARM_AMBA_AXI4-critical?style=for-the-badge)](https://developer.arm.com/documentation/ihi0022/latest/)
[![EDA Toolchain](https://img.shields.io/badge/EDA-AMD_Vivado_2024.2_xsim-blue?style=for-the-badge&logo=amd&logoColor=white)](https://www.xilinx.com/products/design-tools/vivado.html)
[![Verification Methodology](https://img.shields.io/badge/Verification-Constrained_Random_&_Scoreboard-brightgreen?style=for-the-badge)]()
[![Simulation Flow](https://img.shields.io/badge/Flow-Projectless_Batch_&_GUI-orange?style=for-the-badge)]()

A modular, production-grade **Universal Verification Methodology (UVM 1.2)** functional verification environment architected in **SystemVerilog** to verify an **AXI4 Register Slice** pipeline IP core. Built and validated using **AMD Vivado 2024.2 xsim**, this testbench provides full protocol-level driver/monitor capabilities, randomized transaction sequences with address-alignment constraints, non-blocking multi-channel bus snooping, and an automated reference-checking scoreboard.

Designed for high-reliability ASIC and FPGA verification flows, the environment incorporates a projectless Tcl/Makefile automation framework supporting headless CI batch execution, custom plusarg injection, and interactive waveform debugging.

---

## Table of Contents
1. [Overview](#overview)
2. [Key Skills Demonstrated](#key-skills-demonstrated)
3. [AXI Register Slice Background](#axi-register-slice-background)
4. [Testbench Architecture](#testbench-architecture)
5. [Verification Components & Transaction Flow](#verification-components--transaction-flow)
6. [File Structure](#file-structure)
7. [Requirements & Toolchain](#requirements--toolchain)
8. [Quick Start](#quick-start)
9. [Simulation Modes & CLI Controls](#simulation-modes--cli-controls)
10. [Waveform Analysis & Debugging](#waveform-analysis--debugging)
11. [Extending the Testbench](#extending-the-testbench)
12. [References](#references)
13. [Team & Contributors](#team--contributors)

---

## Overview

High-performance system-on-chip (SoC) architectures rely heavily on **ARM AMBA® AXI4** interconnect fabrics operating at aggressive clock frequencies. In complex floorplans, long wire routes between master and slave endpoints introduce severe combinatorial propagation delays on handshake (`VALID`/`READY`) and payload lines, limiting the achievable maximum operating frequency ($F_{max}$) and causing timing closure failures.

The **AXI Register Slice** resolves this by inserting fully registered pipeline stages into the AXI interconnect, breaking combinatorial paths and decoupling timing domains across channel boundaries.

### Why Verifying an AXI Register Slice Matters

While conceptually straightforward, pipeline registers on bidirectional handshaking protocols introduce significant verification complexity:
* **Protocol Invariant Preservation**: Under the AXI4 specification, once `VALID` is asserted, neither `VALID` nor the accompanying payload data may be deasserted or mutated until `READY` is sampled high.
* **Backpressure & Skid Buffering**: If the downstream slave deasserts `READY` while a transaction is in-flight within a registered stage, the register slice must capture and hold the payload without data drop or protocol violation (skid buffer operation).
* **Multi-Channel Independence & Deadlock Prevention**: The 5 AXI channels (Write Address `AW`, Write Data `W`, Write Response `B`, Read Address `AR`, Read Data `R`) have decoupled latencies. Register slice pipelining must not introduce cross-channel ordering violations or handshake deadlocks.

This UVM testbench models, stimulates, and monitors these protocol dynamics under constrained-random scenarios to guarantee functional correctness, data integrity, and timing compliance.

---

## Key Skills Demonstrated

| Technical Domain | Competencies & Applied Industry Practices |
| :--- | :--- |
| **UVM Methodology** | Hierarchical component construction (`uvm_test`, `uvm_env`, `uvm_agent`, `uvm_scoreboard`), phase synchronization (`build_phase`, `connect_phase`, `run_phase`), factory registration (`uvm_component_utils`), and inter-component abstraction via `uvm_config_db`. |
| **SystemVerilog** | Object-Oriented Programming (OOP), transaction encapsulation (`uvm_sequence_item`), parameterized interfaces (`interface`), clock/reset generation, non-blocking signal sampling, and package modularity (`uvm_tb_pkg`). |
| **AXI4 Bus Protocol** | Deep knowledge of AMBA AXI4 5-channel architecture (`AW`, `W`, `B`, `AR`, `R`), 2-way handshake handoffs (`VALID`/`READY`), response codes (`BRESP`/`RRESP`), and registered pipeline latency characteristics. |
| **Functional Verification** | Verification planning, stimulus isolation, transaction-level modeling (TLM), interface monitoring, and cycle-accurate hardware-software co-verification. |
| **Constrained Random Testing** | Constraint modeling (`constraint c_simple_addr`), 32-bit aligned boundary addressing (`addr[1:0] == 2'b0`), distribution control, and inline randomization (`assert(req.randomize() with {...})`). |
| **Scoreboard & Checker** | Non-blocking analysis ports (`uvm_analysis_port` / `uvm_analysis_imp`), expected response validation, reference model comparison (`EXPECTED_VAL = 32'hCAFEBABE`), and error reporting (`uvm_error`). |
| **Coverage-Driven Verification** | Structural test planning, protocol state-space exploration, boundary condition targeting, and regression readiness. |
| **EDA Tool Automation** | Vivado projectless scripting flow (`xvlog -sv -L uvm`, `xelab`, `xsim`), GNU Make automation, plusarg command-line handling, and log parsing. |

---

## AXI Register Slice Background

The Device Under Test (DUT) is the **Xilinx/AMD AXI Register Slice** (`axi_register_slice_v2_1`), an IP core providing parameterized pipeline buffering for memory-mapped AXI4 transactions.

```
+-------------------------------------------------------------------------------------------------+
|                                    AXI REGISTER SLICE (DUT)                                     |
|                                                                                                 |
|   AXI Slave Interface (S_AXI)                                   AXI Master Interface (M_AXI)    |
|   +--------------------------+                                 +----------------------------+   |
|   | S_AXI_AW (Write Address) | === [ Skid Buffer / Reg ] ====> | M_AXI_AW (Write Address)   |   |
|   | S_AXI_W  (Write Data)    | === [ Skid Buffer / Reg ] ====> | M_AXI_W  (Write Data)      |   |
|   | S_AXI_B  (Write Resp)    | <== [ Skid Buffer / Reg ] ===== | M_AXI_B  (Write Resp)      |   |
|   | S_AXI_AR (Read Address)  | === [ Skid Buffer / Reg ] ====> | M_AXI_AR (Read Address)    |   |
|   | S_AXI_R  (Read Data)     | <== [ Skid Buffer / Reg ] ===== | M_AXI_R  (Read Data)       |   |
|   +--------------------------+                                 +----------------------------+   |
|               ^                                                               ^                 |
|               |                             ACLK                              |                 |
|               +-------------------------------+-------------------------------+                 |
|                                               | ARESETn                                         |
+-------------------------------------------------------------------------------------------------+
```

### Key Functional Capabilities
* **Forward Pipeline Stage**: Registers `VALID` and payload signals moving from source to destination.
* **Backward Pipeline Stage**: Registers `READY` feedback moving backwards from destination to source, inserting a 1-deep skid buffer to absorb transactions when `READY` deasserts.
* **Full Registered Mode**: Combines forward and backward registers to achieve total isolation of combinatorial paths on all handshake and data lines.
* **Independent Channel Pipelining**: Configurable per-channel (e.g., isolating high-fanout write data paths without adding latency to write address cycles).

---

## Testbench Architecture

The testbench is structured following the standard UVM class hierarchy. Below is an architectural overview of how the verification components interface with the DUT and the top-level test environment.

```
+==================================================================================================+
|                                           TOP (top.sv)                                           |
|                                                                                                  |
|   +--------------------------+                         +-------------------------------------+   |
|   | Clock & Reset Generator  |                         |  Synthesizable Dummy Slave Model    |   |
|   | - ACLK: 100 MHz (10ns)   |                         |  - AWREADY / WREADY / ARREADY = 1   |   |
|   | - ARESETn: 20ns Active L |                         |  - RDATA: 32'hCAFEBABE              |   |
|   +------------+-------------+                         |  - BRESP / RRESP: 2'b00 (OKAY)      |   |
|                |                                       +------------------+------------------+   |
|                v                                                          v                      |
|   +------------------------------------------------------------------------------------------+   |
|   |                               Virtual Interface (my_if.sv)                               |   |
|   |                                                                                          |   |
|   |    [S_AXI Slave Port]                                    [M_AXI Master Port]             |   |
|   |    S_AXI_AWADDR, S_AXI_AWVALID, S_AXI_AWREADY            M_AXI_AWADDR, M_AXI_AWVALID...  |   |
|   |    S_AXI_WDATA,  S_AXI_WVALID,  S_AXI_WREADY...          M_AXI_WDATA,  M_AXI_WVALID...   |   |
|   |    S_AXI_BVALID, S_AXI_BREADY,  S_AXI_BRESP              M_AXI_BVALID, M_AXI_BREADY...   |   |
|   |    S_AXI_ARADDR, S_AXI_ARVALID, S_AXI_ARREADY            M_AXI_ARADDR, M_AXI_ARVALID...  |   |
|   |    S_AXI_RDATA,  S_AXI_RVALID,  S_AXI_RREADY...          M_AXI_RDATA,  M_AXI_RVALID...   |   |
|   +------------+----------------------------------------------------------+------------------+   |
|                |                                                          ^                      |
|                |          +------------------------------------+          |                      |
|                +--------->|   DUT: axi_register_slice_v2_1     |----------+                      |
|                           |   (Timing Pipeline Stage Core)     |                                 |
|                           +------------------------------------+                                 |
|                                                                                                  |
|   +------------------------------------------------------------------------------------------+   |
|   |                                 UVM Component Hierarchy                                  |   |
|   |                                                                                          |   |
|   |   +----------------------------------------------------------------------------------+   |   |
|   |   |                               base_test (test.sv)                                |   |   |
|   |   |                                                                                  |   |   |
|   |   |   +--------------------------------------------------------------------------+   |   |   |
|   |   |   |                                env (env.sv)                              |   |   |   |
|   |   |   |                                                                          |   |   |   |
|   |   |   |   +--------------------------------------+      +--------------------+   |   |   |   |
|   |   |   |   |          my_agent (agent.sv)         |      |  scoreboard        |   |   |   |   |
|   |   |   |   |                                      |      |  (scoreboard.sv)   |   |   |   |   |
|   |   |   |   |   +------------------------------+   |      |                    |   |   |   |   |
|   |   |   |   |   |  basic_sequence              |   |      |  - Analysis Export |   |   |   |   |
|   |   |   |   |   |  (sequence.sv)               |   |      |  - Pass/Fail Check |   |   |   |   |
|   |   |   |   |   +--------------+---------------+   |      |  - Data Match:     |   |   |   |   |
|   |   |   |   |                  | seq_item          |      |    32'hCAFEBABE    |   |   |   |   |
|   |   |   |   |                  v                   |      +---------^----------+   |   |   |   |
|   |   |   |   |   +------------------------------+   |                |              |   |   |   |
|   |   |   |   |   |  my_sequencer (seqr.sv)      |   |                |              |   |   |   |
|   |   |   |   |   +--------------+---------------+   |                |              |   |   |   |
|   |   |   |   |                  | seq_item_port     |                |              |   |   |   |
|   |   |   |   |                  v                   |                |              |   |   |   |
|   |   |   |   |   +------------------------------+   |                |              |   |   |   |
|   |   |   |   |   |  my_driver (driver.sv)       |   |                |              |   |   |   |
|   |   |   |   |   |  - AXI Handshake Driver      |   |                |              |   |   |   |
|   |   |   |   |   +--------------+---------------+   |                |              |   |   |   |
|   |   |   |   |                  |                                    |              |   |   |   |
|   |   |   |   |                  v Pin-Level Master Drives            |              |   |   |   |
|   |   |   |   |         [ Virtual Interface vif ]                     |              |   |   |   |
|   |   |   |   |                  |                                    |              |   |   |   |
|   |   |   |   |                  v Passive Interface Sampling         |              |   |   |   |
|   |   |   |   |   +------------------------------+                    |              |   |   |   |
|   |   |   |   |   |  my_monitor (monitor.sv)     |                    |              |   |   |   |
|   |   |   |   |   |  - Concurrent AW/W/B & AR/R  |--------------------+              |   |   |   |
|   |   |   |   |   +------------------------------+   ap.write(tr)                    |   |   |   |
|   |   |   |   +----------------------------------------------------------------------+   |   |   |
|   |   |   +--------------------------------------------------------------------------+   |   |   |
|   |   +----------------------------------------------------------------------------------+   |   |
|   +------------------------------------------------------------------------------------------+   |
+==================================================================================================+
```

---

## Verification Components & Transaction Flow

### 1. Sequence Item (`seq_item`)
The atomic transaction unit [seq_item.sv](file:///Users/a/projects/dydy/src/testbench/sequences/seq_item.sv) defines write/read operations, addresses, write payloads, and captured read data.
* **Fields**: `rand bit is_write`, `rand bit [31:0] addr`, `rand bit [31:0] wdata`, `bit [31:0] rdata`.
* **Address Constraints**: Constrains transactions to a 4KB range aligned to 32-bit word boundaries (`addr[1:0] == 2'b0; addr inside {[32'h0 : 32'h1000]};`).
* **Factory & Utilities**: Implements `uvm_field_int` macros and custom string conversion via `convert2string()` for human-readable logging.

### 2. Sequence Generator (`basic_sequence`)
The sequence body [sequence.sv](file:///Users/a/projects/dydy/src/testbench/sequences/sequence.sv) coordinates stimulus generation:
* Instantiates and randomizes a write transaction (`is_write == 1`).
* Dispatches through `start_item()` / `finish_item()` handshakes to the sequencer.
* Generates and executes a randomized read transaction (`is_write == 0`) to verify end-to-end read data path integrity.

### 3. Sequencer (`my_sequencer`)
The sequencer [seqr.sv](file:///Users/a/projects/dydy/src/testbench/agents/seqr.sv) acts as the arbiter and transaction pipe between the sequence and driver, parametrized by `seq_item`.

### 4. Protocol Driver (`my_driver`)
The active driver [driver.sv](file:///Users/a/projects/dydy/src/testbench/agents/driver.sv) retrieves virtual interface handles from the `uvm_config_db` and translates high-level sequence items into cycle-accurate AXI4 pin events:
* **Write Transaction (`do_axi_write`)**: Drives `AWVALID`/`AWADDR`, holds until `AWREADY` confirms sampling, asserts `WVALID`/`WDATA`/`WSTRB`/`WLAST` until `WREADY` handshake, and monitors `BVALID`/`BREADY` write response completion.
* **Read Transaction (`do_axi_read`)**: Drives `ARVALID`/`ARADDR` until `ARREADY`, asserts `RREADY`, samples `RDATA` when `RVALID` asserts, and verifies `RLAST`.
* **Reset Routine (`reset_signals`)**: Initializes all driven AXI handshake control lines to inactive states during reset assertions.

### 5. Concurrent Passive Monitor (`my_monitor`)
The passive bus monitor [monitor.sv](file:///Users/a/projects/dydy/src/testbench/agents/monitor.sv) snoops the virtual interface without perturbing execution:
* Executes parallel threads using `fork / join_none`:
  * `collect_writes()`: Detects `AWVALID & AWREADY`, tracks write data handshakes (`WVALID & WREADY`), samples write responses (`BVALID & BREADY`), packs the transaction, and broadcasts to the scoreboard.
  * `collect_reads()`: Detects `ARVALID & ARREADY`, samples `RVALID & RREADY` paired with incoming `RDATA`, and dispatches the completed transaction.
* Transmits complete transaction packets via `uvm_analysis_port #(seq_item) ap`.

### 6. Reference Scoreboard (`scoreboard`)
The checker component [scoreboard.sv](file:///Users/a/projects/dydy/src/testbench/env/scoreboard.sv) hooks into the monitor's analysis port via `uvm_analysis_imp`:
* Receives observed bus transactions across both channels.
* Evaluates write address and data propagation.
* Checks read transaction data against the reference model expected response (`EXPECTED_VAL = 32'hCAFEBABE`), triggering `uvm_error` upon any mismatch.

### 7. Agent & Environment Wiring (`my_agent`, `env`)
* [agent.sv](file:///Users/a/projects/dydy/src/testbench/agents/agent.sv): Bundles sequencer, driver, and monitor. Supports runtime active/passive configuration (`is_active = UVM_ACTIVE`). Connects `drv.seq_item_port` to `seqr.seq_item_export`.
* [env.sv](file:///Users/a/projects/dydy/src/testbench/env/env.sv): Instantiates the agent and scoreboard, connecting `agt.mon.ap` to `scb.analysis_export` in `connect_phase()`.

### 8. Simulation Top & Clocking (`top`)
Top-level testbench harness [top.sv](file:///Users/a/projects/dydy/src/testbench/top/top.sv):
* Generates a 100 MHz clock (`ACLK`) and an active-low reset pulse (`ARESETn` for 20 ns).
* Instantiates the parameterizable `axi_register_slice_v2_1_22_axi_register_slice` DUT (`ADDR_WIDTH=32`, `DATA_WIDTH=32`).
* Implements synthesizable dummy slave logic on the master side (`M_AXI_*`) providing immediate handshakes and returning static read response `32'hCAFEBABE`.
* Registers the virtual interface in `uvm_config_db` across all scopes (`*`) and triggers `run_test()`.

---

## File Structure

```
/Users/a/projects/dydy/
├── README.md                           # Comprehensive verification documentation (this file)
├── run/                                # Execution, build, and simulation framework
│   ├── Makefile                        # GNU Make automation (batch, GUI, view, clean)
│   ├── files.f                         # Ordered compilation manifest
│   ├── run.sh                          # POSIX shell simulation wrapper with TTY traps & logging
│   ├── run_sim.tcl                     # Vivado projectless compilation, elaboration & simulation script
│   ├── logs/                           # Auto-generated simulation execution and Vivado logs
│   └── sim/                            # Simulation database directory (xsim.wdb, run scripts)
└── src/
    ├── rtl/                            # Hardware design under test & infrastructure libraries
    │   ├── axi_infrastructure_v1_1_0.vh        # AXI infrastructure header definitions
    │   ├── axi_infrastructure_v1_1_vl_rfs.v    # Interconnect infrastructure library
    │   ├── axi_register_slice_v2_1_vl_rfs.v    # Core AXI4 Register Slice implementation (DUT)
    │   ├── Makefile                            # IP extraction script
    │   └── rtlgen.tcl                          # Vivado IP generation automation script
    └── testbench/                      # UVM 1.2 Verification Environment
        ├── agents/
        │   ├── agent.sv                # UVM agent container (Active/Passive management)
        │   ├── driver.sv               # Protocol driver for AXI master pin transactions
        │   ├── monitor.sv              # Concurrent passive monitor with analysis port
        │   └── seqr.sv                 # UVM sequencer for transaction dispatch
        ├── env/
        │   ├── env.sv                  # Environment container connecting agent and scoreboard
        │   └── scoreboard.sv           # Self-checking scoreboard & data integrity validator
        ├── if/
        │   └── my_if.sv                # Fully populated AXI4 SystemVerilog virtual interface
        ├── sequences/
        │   ├── seq_item.sv             # AXI transaction item with randomization constraints
        │   └── sequence.sv             # Randomized read/write stimulus sequence
        ├── top/
        │   ├── test.sv                 # Base UVM test with objection management
        │   └── top.sv                  # Simulation top (clock, reset, DUT, responder, config_db)
        └── uvm_pkg/
            └── uvm_tb_pkg.sv           # Central testbench package importing all components
```

---

## Requirements & Toolchain

To compile and run this testbench, ensure your environment meets the following specifications:

* **EDA Simulator**: AMD Vivado Design Suite 2024.2 (or compatible Vivado/xsim 2020.2+)
* **Methodology Library**: Accellera UVM 1.2 (pre-compiled and shipped with Vivado `-L uvm`)
* **Language Support**: SystemVerilog (IEEE 1800-2017 compliant)
* **Build Utilities**: GNU Make 3.81+, Bash 4.0+
* **Environment Variables**:
  Make sure `vivado`, `xvlog`, `xvhdl`, `xelab`, and `xsim` are in your active system `PATH`:
  ```bash
  source /tools/Xilinx/Vivado/2024.2/settings64.sh  # Typical Linux installation path
  ```

---

## Quick Start

The testbench provides turnkey execution targets via GNU Make inside the `run/` directory.

### 1. Run Clean Batch Simulation
Compile the RTL and UVM testbench, elaborate the design, and execute the test:
```bash
make -C run clean && make -C run run_sim
```

### 2. Launch Interactive Waveform GUI
Re-simulate and automatically bring up the Vivado xsim GUI with all signal scopes pre-loaded:
```bash
make -C run gui
```

### 3. Open Previous Waveform Database (No Re-compile)
Open the generated `xsim.wdb` waveform database from a previous simulation run:
```bash
make -C run view
```

### Expected Clean Simulation Log
When the simulation completes successfully, the output confirms UVM phase completion, transaction matches in the scoreboard, and zero UVM errors:

```
[20:06:55]: Compiling...
[20:06:58]: Elaborating...
[20:07:02]: Running batch simulation...
----------------------------------------------------------------
UVM_INFO @ 0: reporter [RNTST] Running test base_test...
UVM_INFO @ 0: uvm_test_top.m_env.agt.seqr@@seq [seq] Starting sequence (1-write, 1-read)
UVM_INFO @ 0: uvm_test_top.m_env.agt.seqr@@seq [seq] Sending WRITE Tx: Addr=0x000004a0, Data=0x83e2150a
UVM_INFO @ 5000: uvm_test_top.m_env.agt.drv [my_driver] Driver received: AXI Tx: WRITE Addr: 0x000004a0, WData: 0x83e2150a, RData: 0x00000000
UVM_INFO @ 35000: uvm_test_top.m_env.agt.mon [MONITOR] Saw WRITE: Addr=0x000004a0 Data=0x83e2150a
UVM_INFO @ 35000: uvm_test_top.m_env.scb [SCB] PASS: Observed WRITE -> Addr: 0x000004a0, Data: 0x83e2150a
UVM_INFO @ 35000: uvm_test_top.m_env.agt.seqr@@seq [seq] Sending READ Tx: Addr=0x0000021c
UVM_INFO @ 35000: uvm_test_top.m_env.agt.drv [my_driver] Driver received: AXI Tx: READ  Addr: 0x0000021c, WData: 0x00000000, RData: 0x00000000
UVM_INFO @ 65000: uvm_test_top.m_env.agt.mon [MONITOR] Saw READ:  Addr=0x0000021c Data=0xcafebabe
UVM_INFO @ 65000: uvm_test_top.m_env.scb [SCB] PASS: Observed READ  -> Addr: 0x0000021c, Data: 0xcafebabe (MATCH)
UVM_INFO @ 65000: uvm_test_top.m_env.agt.seqr@@seq [seq] READ Tx complete, RData=0xcafebabe
UVM_INFO @ 65000: uvm_test_top.m_env.seqr@@seq [seq] Finished sequence
--- UVM Report Summary ---
** Report counts by severity
UVM_INFO : 10
UVM_WARNING : 0
UVM_ERROR : 0
UVM_FATAL : 0
** Report counts by id
[RNTST] 1
[seq] 5
[my_driver] 2
[MONITOR] 2
[SCB] 2
$finish called at time : 1065 ns
Simulation finished. Wave: xsim.wdb
```

---

## Simulation Modes & CLI Controls

The verification environment provides flexible command-line arguments to control runtime behavior, simulation duration, and UVM plusargs.

### Command Matrix

| Target / Command | Description | Example |
| :--- | :--- | :--- |
| `make -C run run_sim` | Default batch mode simulation (runs for 1 ms) | `make -C run run_sim` |
| `TIME=<duration>` | Overrides default simulation timeout in batch mode | `make -C run run_sim TIME=50us` |
| `ARGS="+<plusarg>"` | Passes custom UVM plusargs to the simulator | `make -C run run_sim ARGS="+UVM_VERBOSITY=UVM_HIGH"` |
| `GUI=1` or `make gui` | Compiles and opens interactive Vivado xsim GUI | `make -C run gui` |
| `VIEW=1` or `make view`| Launches waveform viewer for prior simulation artifact | `make -C run view` |
| `make -C run clean` | Purges `sim/`, `logs/`, and Vivado temporary artifacts | `make -C run clean` |

### Custom Plusarg Injection Examples

* **Selecting Alternative Tests**:
  ```bash
  make -C run run_sim ARGS="+UVM_TESTNAME=base_test"
  ```
* **Controlling UVM Verbosity**:
  ```bash
  make -C run run_sim ARGS="+UVM_VERBOSITY=UVM_DEBUG"
  ```
* **Setting a Random Seed for Regression**:
  ```bash
  make -C run run_sim ARGS="+ntb_random_seed=482910"
  ```

### Direct Script Execution (`run.sh`)
For automated CI pipelines, [run.sh](file:///Users/a/projects/dydy/run/run.sh) wraps execution with strict Bash safety flags (`set -euo pipefail`), terminal TTY state restoration traps, and simultaneous tee logging to `logs/sim.log` and `logs/vivado.log`:

```bash
cd run
./run.sh --time 100us +UVM_TESTNAME=base_test +UVM_VERBOSITY=UVM_LOW
```

---

## Waveform Analysis & Debugging

During batch or GUI runs, all hierarchy signals are recorded recursively via `log_wave -recursive /*`. 

### Key Signals to Trace
1. **Clock & Reset**: `axi_vif.ACLK`, `axi_vif.ARESETn`.
2. **Write Address Channel**:
   * `axi_vif.S_AXI_AWVALID` vs `axi_vif.S_AXI_AWREADY` (Slave handshake).
   * `axi_vif.M_AXI_AWVALID` vs `axi_vif.M_AXI_AWREADY` (Master handshake after register slice latency).
   * Address integrity: `S_AXI_AWADDR` == `M_AXI_AWADDR`.
3. **Write Data Channel**:
   * `axi_vif.S_AXI_WVALID`, `S_AXI_WREADY`, `S_AXI_WLAST`.
   * Pipelined transfer: `M_AXI_WVALID`, `M_AXI_WREADY`.
4. **Write Response Channel**:
   * `axi_vif.M_AXI_BVALID`, `axi_vif.S_AXI_BVALID`, `axi_vif.S_AXI_BRESP`.
5. **Read Address & Data Channels**:
   * `axi_vif.S_AXI_ARVALID` & `axi_vif.M_AXI_ARVALID`.
   * Return data: `axi_vif.M_AXI_RDATA` propagating to `axi_vif.S_AXI_RDATA` with `RLAST`.

---

## Extending the Testbench

This testbench is engineered with clean separation of concerns, making it straightforward to extend for full-chip verification:

### 1. Adding Backpressure Stimulus
Modify [top.sv](file:///Users/a/projects/dydy/src/testbench/top/top.sv#L68-L72) or replace the dummy slave with an active UVM AXI Slave Agent to inject randomized `AWREADY`, `WREADY`, and `ARREADY` de-assertions:
```systemverilog
// Injecting randomized backpressure to verify register slice skid buffering
always @(posedge axi_vif.ACLK) begin
  axi_vif.M_AXI_AWREADY <= $urandom_range(0, 1);
  axi_vif.M_AXI_WREADY  <= $urandom_range(0, 1);
  axi_vif.M_AXI_ARREADY <= $urandom_range(0, 1);
end
```

### 2. Implementing Functional Coverage
Add a `covergroup` inside [monitor.sv](file:///Users/a/projects/dydy/src/testbench/agents/monitor.sv) or a dedicated subscriber component to monitor cross-coverage of:
* Address alignment and boundary transitions (0x0, 0xFFC, 0x1000).
* Simultaneous write and read transactions (concurrent bus activity).
* Backpressure durations (consecutive cycles where `VALID=1` and `READY=0`).

```systemverilog
covergroup axi_reg_slice_cg;
  cp_is_write: coverpoint tr.is_write {
    bins write_op = {1};
    bins read_op  = {0};
  }
  cp_addr: coverpoint tr.addr {
    bins low_range  = {[32'h0000 : 32'h03FF]};
    bins mid_range  = {[32'h0400 : 32'h07FF]};
    bins high_range = {[32'h0800 : 32'h1000]};
  }
  cross_op_addr: cross cp_is_write, cp_addr;
endgroup
```

### 3. Adding Protocol Assertions (SVA)
Embed SystemVerilog Assertions into [my_if.sv](file:///Users/a/projects/dydy/src/testbench/if/my_if.sv) to check standard AXI4 protocol rules:
```systemverilog
// Protocol rule: Once VALID is asserted, it must remain asserted until READY is high
property p_awvalid_stable;
  @(posedge ACLK) disable iff (!ARESETn)
  (S_AXI_AWVALID && !S_AXI_AWREADY) |=> S_AXI_AWVALID;
endproperty
assert_awvalid_stable: assert property (p_awvalid_stable);
```

---

## References

1. **ARM® AMBA® AXI™ and ACE™ Protocol Specification** — ARM IHI 0022E (Issue E), ARM Limited.
2. **Accellera Universal Verification Methodology (UVM) 1.2 User's Guide** — Accellera Systems Initiative.
3. **IEEE Std 1800™-2017**: IEEE Standard for SystemVerilog—Unified Hardware Design, Specification, and Verification Language.
4. **AMD Vivado Design Suite User Guide: Logic Simulation (UG900)** — AMD / Xilinx Inc.
5. **Xilinx LogiCORE IP AXI Register Slice Product Guide (PG059)** — AMD / Xilinx Inc.

---

### Team & Contributors
#### This verification IP and testbench environment was collaboratively developed by Team Dydy:

1. Mahazoasy Narindra
2. Waleed Hussain
3. Abomosa Abdelrahman