// fifo
//
// wraps all six submodules into one block that safely passes data
// between two independent clock domains (wclk for write and rclk for read)
//
// how the pieces fit:
//   fifo_mem    — dual-port RAM: written in wclk domain, read in rclk domain
//   wptr_full   — write pointer + full flag  (write domain)
//   rptr_empty  — read pointer + empty flag  (read domain)
//   synchro x2  — two-flop synchronizers that carry each Gray pointer
//                 into the OTHER clock domain
//
// the CDC safety comes from two mechanisms working together:
//   1. pointers are Gray-coded, so only one bit changes per step —
//      a mid-transition sample can't produce a garbage multi-bit value
//   2. each pointer is double-flopped when crossing domains, so
//      metastability has a full cycle to settle before it's used
//
// each pointer crosses to the opposite domain so the local flag logic
// can compare its own pointer against the synchronized remote one.

module fifo #(parameter DATA_WIDTH = 8, ADDR_WIDTH = 4) (
    // write
    input wclk,
    input wrst_n,
    input winc,
    input [DATA_WIDTH-1:0] wdata,

    // read
    input rclk,
    input rrst_n,
    input rinc,
    output [DATA_WIDTH-1:0] rdata,

    // flags
    output wfull,
    output rempty
);
    // wires
    wire [ADDR_WIDTH:0] wptr, rptr, wptr_sync, rptr_sync;
    wire [ADDR_WIDTH-1:0] waddr, raddr;
 

    wptr_full wpf (.wclk(wclk), .wrst_n(wrst_n), .winc(winc), .rptr_sync(rptr_sync),
        .wptr(wptr), .waddr(waddr), .wfull(wfull));
    rptr_empty rpe (.rclk(rclk), .rrst_n(rrst_n), .rinc(rinc), .wptr_sync(wptr_sync),
        .rptr(rptr), .raddr(raddr), .rempty(rempty));
    synchro r2w (.clk(wclk), .rst_n(wrst_n), .d_in(rptr), .d_out(rptr_sync));
    synchro w2r (.clk(rclk), .rst_n(rrst_n), .d_in(wptr), .d_out(wptr_sync));
    fifo_mem mem (.wclk(wclk), .wr_en(winc & ~wfull), .waddr(waddr), .wdata(wdata), 
    .raddr(raddr), .rdata(rdata));

// note: if ADDR_WIDTH were ever changed, synchro would default to 5 and break
// safe version would be: synchro #(.WIDTH(ADDR_WIDTH+1)) r2w (...)
endmodule