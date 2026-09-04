import re

file_path = "rtl/ir_qc_ldpc/matlinsas_LDPC/core_static.v"
with open(file_path, "r") as f:
    content = f.read()

def replace_cnu(match):
    idx = match.group(1)
    original = match.group(0)
    # The original string ends with "));"
    # We want to insert ", .active(cnu_active[{idx}])" before the final "));"
    if original.endswith("));"):
        return original[:-3] + f"), .active(cnu_active[{idx}]));"
    return original

content = re.sub(
    r"CNU(\d+)\s*\([^;]+\);",
    replace_cnu,
    content
)

with open(file_path, "w") as f:
    f.write(content)

print("Fixed core_static.v CNU instantiations successfully")
