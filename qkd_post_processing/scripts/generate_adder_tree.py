import math
import os

def generate_adder_tree_verilog(num_inputs=1152, stages_per_pipeline=3, module_name="syndrome_weight_counter", out_filename="syndrome_weight_counter.v"):
    lines = []
    
    # 1. Header
    out_width = math.ceil(math.log2(num_inputs + 1))
    lines.append(f"`timescale 1ns / 1ps")
    lines.append(f"module {module_name} (")
    lines.append(f"    input wire clk,")
    lines.append(f"    input wire rst_n,")
    lines.append(f"    input wire [{num_inputs-1}:0] syn_in,")
    lines.append(f"    output reg [{out_width-1}:0] shw_out")
    lines.append(f");")
    lines.append("")
    lines.append(f"    // Automatically generated pipeline binary adder tree")
    lines.append(f"    // Inputs: {num_inputs}")
    lines.append(f"    // Pipeline stages inserted every {stages_per_pipeline} levels")
    lines.append("")
    
    # 2. Level 0 wire assignment
    current_nodes = [f"syn_in[{i}]" for i in range(num_inputs)]
    current_width = 1
    level = 0
    
    lines.append(f"    // Level 0: Input layer")
    for i in range(num_inputs):
        lines.append(f"    wire [{current_width-1}:0] node_{level}_{i} = syn_in[{i}];")
    lines.append("")
    
    # 3. Binary Tree Generation
    while len(current_nodes) > 1:
        next_nodes = []
        next_width = current_width + 1
        level += 1
        
        lines.append(f"    // Level {level}")
        
        # Decide if this level is registered (don't register the very last level before output reg)
        is_registered = (level % stages_per_pipeline == 0) and (len(current_nodes) > 2)
        node_prefix = "reg" if is_registered else "wire"
        
        # Generate declarations for next level
        for i in range(math.ceil(len(current_nodes) / 2)):
            lines.append(f"    {node_prefix} [{next_width-1}:0] node_{level}_{i};")
            next_nodes.append(f"node_{level}_{i}")
            
        if is_registered:
            lines.append(f"    always @(posedge clk or negedge rst_n) begin")
            lines.append(f"        if (!rst_n) begin")
            for i in range(math.ceil(len(current_nodes) / 2)):
                lines.append(f"            node_{level}_{i} <= 0;")
            lines.append(f"        end else begin")
            
        for i in range(0, len(current_nodes), 2):
            node_idx = i // 2
            n1 = current_nodes[i]
            if i + 1 < len(current_nodes):
                n2 = current_nodes[i+1]
                assign_str = f"node_{level}_{node_idx} {'<=' if is_registered else '='} {n1} + {n2};"
            else:
                assign_str = f"node_{level}_{node_idx} {'<=' if is_registered else '='} {n1};"
                
            if is_registered:
                lines.append(f"            {assign_str}")
            else:
                lines.append(f"    assign {assign_str}")
                
        if is_registered:
            lines.append(f"        end")
            lines.append(f"    end")
            
        lines.append("")
        current_nodes = next_nodes
        current_width = next_width
        
    # 4. Output register
    lines.append(f"    // Final Output Register")
    lines.append(f"    always @(posedge clk or negedge rst_n) begin")
    lines.append(f"        if (!rst_n) begin")
    lines.append(f"            shw_out <= 0;")
    lines.append(f"        end else begin")
    lines.append(f"            shw_out <= {current_nodes[0]};")
    lines.append(f"        end")
    lines.append(f"    end")
    lines.append("")
    lines.append(f"endmodule")
    
    with open(out_filename, 'w') as f:
        f.write("\n".join(lines))
    print(f"Generated {out_filename} successfully.")

if __name__ == "__main__":
    out_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "rtl", "syndrome_weight_counter.v")
    generate_adder_tree_verilog(out_filename=out_path)
