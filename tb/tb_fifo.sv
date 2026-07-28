`timescale 1ns/1ps

module tb_fifo();
localparam DATA_WIDTH = 8;
localparam ADDR_WIDTH = 4;

    // write
    logic wclk;
    logic wrst_n;
    logic winc;
    logic [DATA_WIDTH-1:0] wdata;

    // read
    logic rclk;
    logic rrst_n;
    logic rinc;
    logic [DATA_WIDTH-1:0] rdata;

    // flags
    logic wfull;
    logic rempty;

    fifo dut (.wclk(wclk), .wrst_n(wrst_n), .winc(winc), .wdata(wdata),
        .rclk(rclk), .rrst_n(rrst_n), .rinc(rinc), .rdata(rdata),
            .wfull(wfull), .rempty(rempty));

    initial wclk = 0;
    initial rclk = 0;
    always #3 wclk = ~wclk;
    always #5 rclk = ~rclk;
    
    initial begin 
        wrst_n = 0;
        rrst_n = 0;
        winc = 0;
        rinc = 0;
        wdata = 0;
        #10;
        wrst_n = 1;
        rrst_n = 1;
        wdata = 67;
        winc = 1;
        @(posedge wclk);
        winc = 0;
        repeat (10) @(posedge wclk);
        $finish;
    end

endmodule