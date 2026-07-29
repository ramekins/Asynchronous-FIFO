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

    // queue
    logic [DATA_WIDTH-1:0] expected[$];
    
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
    end

    // write function
    initial begin
        wait (wrst_n == 1);
        for (int i = 0; i < 20; i++) begin
            wait (!wfull);
            wdata <= i;
            winc <= 1;
            @(posedge wclk);
            #1;
            expected.push_back(i);
            winc <= 0;
        end
    end
    
    // read function
    initial begin : reader
        // local variables
        logic [DATA_WIDTH-1:0] data, exp;
        wait (rrst_n == 1);
        for (int i = 0; i < 20; i++) begin
            wait (!rempty);
            data = rdata;
            rinc = 1;
            @(posedge rclk);
            #1;
            exp = expected.pop_front();
            if (exp !== data) begin
                $error("mismatch detected, expected value: %b, actual : %b", exp, data);
            end
            rinc = 0;
        end
        if (expected.size() != 0) begin
        $error("leftover in queue: %0d", expected.size());
        end
        $display("all checks passed - %0d values verified", 20);
        $finish;
    end

    initial begin
      #2000;
        $finish;
    end

endmodule