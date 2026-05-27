# Tcl script to generate Xilinx AXI-Stream FIFO IPs for QKD Post-Processing
# Run this script in the Vivado Tcl Console:
# source d:/DownloadD/03. Post-Processing-FPGA-QKD-20260508T062156Z-3-001/03. Post-Processing-FPGA-QKD/qkd_post_processing/scripts/generate_ips.tcl

puts "Generating AXI-Stream FIFO IPs..."

# 1. Input LLR FIFO (Width = 8 bits, Depth = 4096)
create_ip -name axis_data_fifo -vendor xilinx.com -library ip -version 2.0 -module_name fifo_llr_in
set_property -dict [list \
    CONFIG.TDATA_NUM_BYTES {1} \
    CONFIG.FIFO_DEPTH {4096} \
    CONFIG.HAS_TLAST {1} \
] [get_ips fifo_llr_in]
generate_target {instantiation_template} [get_files [get_property IP_FILE [get_ips fifo_llr_in]]]

# 2. Inter-module Key FIFO (Width = 64 bits, Depth = 512)
create_ip -name axis_data_fifo -vendor xilinx.com -library ip -version 2.0 -module_name fifo_ir_to_pa
set_property -dict [list \
    CONFIG.TDATA_NUM_BYTES {8} \
    CONFIG.FIFO_DEPTH {512} \
    CONFIG.HAS_TLAST {1} \
] [get_ips fifo_ir_to_pa]
generate_target {instantiation_template} [get_files [get_property IP_FILE [get_ips fifo_ir_to_pa]]]

# Generate the products
generate_target all [get_ips fifo_llr_in]
generate_target all [get_ips fifo_ir_to_pa]

puts "IP Generation Complete! Ready for Phase 1 Integration."
