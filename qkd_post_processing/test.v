module tb;
  reg [7:0] b;
  wire signed [8:0] a = b[7:0];
  initial begin
    b = 8'hFF;
    #1;
    $display("a = %d (hex: %h)", a, a);
  end
endmodule
