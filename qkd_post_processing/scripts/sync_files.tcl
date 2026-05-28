# Tcl script to sync updated files from DownloadD into the Vivado Project

set src_dir "d:/DownloadD/03. Post-Processing-FPGA-QKD-20260508T062156Z-3-001/03. Post-Processing-FPGA-QKD/qkd_post_processing"
set proj_dir "D:/XilinxProjects/QKD/QKD.srcs"

puts "Đang đồng bộ hóa file từ thư mục gốc vào Vivado Project..."

# 1. Copy file nguồn đã chỉnh sửa sang Vivado
file copy -force "$src_dir/rtl/ir_qc_ldpc/matlinsas_LDPC/cnu/cnu.v" "$proj_dir/sources_1/imports/matlinsas_LDPC/cnu/cnu.v"
file copy -force "$src_dir/rtl/ir_qc_ldpc/matlinsas_LDPC/cnu/sgn_ram.v" "$proj_dir/sources_1/imports/matlinsas_LDPC/cnu/sgn_ram.v"
file copy -force "$src_dir/rtl/ir_qc_ldpc/matlinsas_LDPC/core_static.v" "$proj_dir/sources_1/imports/matlinsas_LDPC/core_static.v"
file copy -force "$src_dir/rtl/ir_qc_ldpc/matlinsas_LDPC/check.v" "$proj_dir/sources_1/imports/matlinsas_LDPC/check.v"
file copy -force "$src_dir/rtl/top/qkd_post_processing_top.v" "$proj_dir/sources_1/imports/rtl/top/qkd_post_processing_top.v"
file copy -force "$src_dir/tb/tb_system_top.v" "$proj_dir/sim_1/imports/tb/tb_system_top.v"

# 2. Sync 2 file mới (Ghi đè trực tiếp vào thư mục Vivado)
file copy -force "$src_dir/rtl/top/axis_to_parallel.v" "$proj_dir/sources_1/imports/rtl/top/axis_to_parallel.v"
file copy -force "$src_dir/rtl/top/parallel_to_axis.v" "$proj_dir/sources_1/imports/rtl/top/parallel_to_axis.v"

# 3. Sync Phase 4: Privacy Amplification (PA & NTT Core)
file mkdir "$proj_dir/sources_1/imports/pa_ntt"
file copy -force "$src_dir/rtl/pa_ntt/prng_lfsr.v" "$proj_dir/sources_1/imports/pa_ntt/prng_lfsr.v"
file copy -force "$src_dir/rtl/pa_ntt/pa_bram_ctrl.v" "$proj_dir/sources_1/imports/pa_ntt/pa_bram_ctrl.v"
file copy -force "$src_dir/rtl/pa_ntt/pa_toeplitz_hash.v" "$proj_dir/sources_1/imports/pa_ntt/pa_toeplitz_hash.v"
catch {file delete -force "$proj_dir/sources_1/imports/pa_ntt/parametric_ntt"}
catch {file copy -force "$src_dir/rtl/pa_ntt/parametric_ntt" "$proj_dir/sources_1/imports/pa_ntt/"}

# Cảnh báo: Lần đầu thêm thư mục parametric_ntt, bạn có thể cần add folder này vào project Vivado qua lệnh add_files.
catch {add_files -norecurse "$proj_dir/sources_1/imports/pa_ntt/prng_lfsr.v"}
catch {add_files -norecurse "$proj_dir/sources_1/imports/pa_ntt/pa_bram_ctrl.v"}
catch {add_files -norecurse "$proj_dir/sources_1/imports/pa_ntt/pa_toeplitz_hash.v"}
catch {add_files "$proj_dir/sources_1/imports/pa_ntt/parametric_ntt"}

# Cập nhật thứ tự compile
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "Đồng bộ hoàn tất! Xin vui lòng bấm Relaunch Simulation."
