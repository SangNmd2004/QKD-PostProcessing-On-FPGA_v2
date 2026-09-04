# QKD Post-Processing on FPGA (Gowin)

This repository contains the RTL (Verilog/VHDL) source code for a Hardware-Algorithm Co-Design of a QKD Post-Processing pipeline (LDPC + Reed-Solomon), optimized for Gowin FPGAs (e.g., Gowin 138K Pro).

## Repository Structure

- `rtl/`: Contains the synthesizable Verilog and VHDL source files.
  - `ldpc_core/`: The Partially Parallel LDPC Decoder core.
  - `rs_core/`: The Reed-Solomon (255, 223) Outer Code decoder.
  - `top/`: Top-level integration and wrappers (`system_top.v`, etc.).
- `tb/`: Testbench files (`tb_hw_co_design.v`, `tb_system_top.v`) for Vivado simulation.
- `python_model/`: Python scripts for generating test vectors and verifying the algorithm.
- `scripts/`: TCL scripts for synthesis and bitstream generation.

## How to add this project to Gowin EDA

To synthesize and implement this design on a Gowin FPGA, follow these steps:

### 1. Create a New Gowin Project
1. Open **Gowin IDE**.
2. Go to **File** -> **New** -> **FPGA Design Project**.
3. Name your project (e.g., `QKD_Post_Processing`) and select your target device (e.g., `GW5AST-138B`).

### 2. Add the Source Files
1. In the **Design** tab (usually on the left panel), right-click on the project name and select **Add Files**.
2. Navigate to the cloned repository and add the following specific files (Do NOT add files from `tb/` or `python_model/` to the synthesis project):

   **a) Top-Level Integration (`rtl/top/`)**
   - `system_top.v` *(Set this as Top Module)*
   - `qkd_post_processing_top.v`
   - `ldpc_axi_wrapper.v`
   - `bch_cleaner_wrapper.v`
   - `axis_to_parallel.v`
   - `parallel_to_axis.v`

   **b) Controllers (`rtl/`)**
   - `statistical_controller.v`
   - `syndrome_weight_counter.v`

   **c) LDPC Decoder Core (`rtl/ldpc_core/` and `rtl/ldpc_core/cnu/`)**
   - `core_partially_parallel.v`
   - `ldpc_bram.v`
   - `rom_h_matrix.v`
   - `barrel_shifter.v`
   - `puncturing_mux.v`
   - `cnu/abs.v`
   - `cnu/cmp.v`
   - `cnu/cmp_tree.v`
   - `cnu/cnu.v`
   - `cnu/cnu_cluster.v`
   - `cnu/sat.v`
   - `cnu/sgn_ram.v`

   **d) Reed-Solomon Outer Code (`rtl/rs_core/`)**
   <details>
   <summary>Click to expand all 60 required VHDL files</summary>
   
   - `adder.vhd`
   - `async_dff.vhd`
   - `async_dff_array.vhd`
   - `async_dff_gen_rst.vhd`
   - `comparator.vhd`
   - `config_dff_array.vhd`
   - `d_sync_flop.vhd`
   - `decrementer.vhd`
   - `demultiplexer_array.vhd`
   - `dual_clock_generic_buffer.vhd`
   - `flop_cascade.vhd`
   - `generic_buffer.vhd`
   - `generic_components.vhd`
   - `generic_functions.vhd`
   - `generic_types.vhd`
   - `half_adder_unit.vhd`
   - `half_subtractor_unit.vhd`
   - `incrementer.vhd`
   - `mem_fifo.vhd`
   - `multiplexer_array.vhd`
   - `no_rst_dff.vhd`
   - `parallel_to_serial.vhd`
   - `reg_fifo.vhd`
   - `reg_fifo_array.vhd`
   - `rs_adder.vhd`
   - `rs_berlekamp_massey.vhd`
   - `rs_chien.vhd`
   - `rs_chien_forney.vhd`
   - `rs_codec.vhd`
   - `rs_components.vhd`
   - `rs_constants.vhd`
   - `rs_decoder.vhd`
   - `rs_encoder.vhd`
   - `rs_encoder_wrapper.vhd`
   - `rs_forney.vhd`
   - `rs_full_multiplier.vhd`
   - `rs_full_multiplier_core.vhd`
   - `rs_functions.vhd`
   - `rs_inverse.vhd`
   - `rs_multiplier.vhd`
   - `rs_multiplier_lut.vhd`
   - `rs_reduce_adder.vhd`
   - `rs_remainder_unit.vhd`
   - `rs_syndrome.vhd`
   - `rs_syndrome_subunit.vhd`
   - `rs_types.vhd`
   - `serial_to_parallel.vhd`
   - `shifter_left.vhd`
   - `single_port_2D_ram.vhd`
   - `single_port_linear_ram.vhd`
   - `single_port_ram.vhd`
   - `sync_dff_array.vhd`
   - `sync_dff_gen_rst.vhd`
   - `sync_ld_dff.vhd`
   - `two_input_size_generic_buffer.vhd`
   - `up_counter.vhd`
   - `up_down_counter.vhd`
   
   </details>

3. **Set the Top Module:** Right-click on `system_top.v` in the Design tree and select **Set as Top Module**. This ensures Gowin synthesizes the entire pipeline correctly without trying to compile sub-modules independently.

### 3. Configure Synthesis Strategy (Crucial for BRAM Limits)
Because the Reed-Solomon core and LDPC parity matrices are large, you may encounter `Out of memory` errors during default synthesis in Gowin. You must optimize for Area and disable RAM inference for certain modules:
1. Right-click on your project name -> **Configuration**.
2. Go to **Synthesize** -> **General**.
3. Change **Synthesis Strategy** to **Area**.
4. Check the box for **Disable RAM Inference** (forces Gowin to use LUTs instead of failing to allocate BRAMs if the matrix is too irregular).
5. (Optional) If you have the Gowin EDA version that includes **Synplify Pro**, go to `Synthesize Tool` and select `Synplify Pro` for much better optimization.

### 4. Run the Flow
- Double-click **Synthesize** in the Process pane.
- Once synthesis passes, configure your pin constraints (CST file) if you plan to program the board.
- Double-click **Place & Route** (PnR).
- Double-click **Generate Bitstream**.

## Simulation using Vivado
Because Gowin's built-in simulator can be slow with large VHDL generics, we recommend using Vivado for Behavioral Simulation:
1. Generate test vectors by running: `python python_model/batch_run_sim.py`
2. Add all `rtl/` and `tb/` files to a Vivado project.
3. Run the **Behavioral Simulation** on `tb_hw_co_design.v`.
4. The testbench will automatically iterate through 5 QBER noise levels (2% to 6%) and output a summary report table showing the Syndrome Hamming Weight (SHW) and remaining errors.
