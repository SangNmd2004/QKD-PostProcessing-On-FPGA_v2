open_project D:/XilinxProjects/QKD/QKD.xpr
set_property source_mgmt_mode All [current_project]
update_compile_order -fileset sim_1
launch_simulation -step all
run all
close_project
