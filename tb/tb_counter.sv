`timescale 1ns/1ps

module tb_counter();

    logic clk, rst_n;
    logic [3:0] count;

    initial clk = 0;
    always #5 clk = ~clk;

    counter dut (.clk(clk), .rst_n(rst_n), .count(count));
    
    initial begin
        rst_n = 0;
        repeat (3) @(posedge clk);
        rst_n = 1;
        repeat (20) @(posedge clk);
    $finish;
  end
endmodule