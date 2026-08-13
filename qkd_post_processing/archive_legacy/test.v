module tb;
    parameter data_w = 6;
    wire [data_w-1:0] sat_max = (1 << (data_w-1)) - 1;
    wire [data_w-1:0] sat_min = ~(sat_max);
    
    wire signed [8:0] llr_new_unshifted = 122; // 122 > 31 -> expect 31
    wire signed [data_w-1:0] llr_new_sat1 = (llr_new_unshifted > $signed(sat_max)) ? sat_max :
                                           (llr_new_unshifted < $signed(sat_min)) ? sat_min : 
                                           llr_new_unshifted[data_w-1:0];
                                           
    wire signed [8:0] llr_new_unshifted2 = -122; // -122 < -32 -> expect -32
    wire signed [data_w-1:0] llr_new_sat2 = (llr_new_unshifted2 > $signed(sat_max)) ? sat_max :
                                           (llr_new_unshifted2 < $signed(sat_min)) ? sat_min : 
                                           llr_new_unshifted2[data_w-1:0];
                                           
    initial begin
        $display("sat_max: %d, sat_min: %d", $signed(sat_max), $signed(sat_min));
        $display("122 sat: %d", $signed(llr_new_sat1));
        $display("-122 sat: %d", $signed(llr_new_sat2));
        #10;
        $finish;
    end
endmodule
