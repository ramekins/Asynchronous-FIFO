// rptr_empty
// purpose: handles read pointer of the FIFO & flag when FIFO is empty
//
// not as long as an explanation as the full (which i implemented first
// on purpose because it was harder ......)
// to know if the fifo is empty, employ the same binary to grey code
// conversion process, and check for equality.
// if they are the same, that means the fifo is empty!
//
// note: after reset, rempty (read is empty) is set to a 1.
// obviously, when the fifo is no longer empty it's set
// to a 0, but you can compare this asymmetry with
// wfull, which is set to 0 after the FIFO is reset.

module rptr_empty #(parameter ADDR_WIDTH = 4)(
    input rclk,                         // read clock
    input rrst_n,                       // read reset
    input rinc,                         // read request
    input [ADDR_WIDTH:0] wptr_sync,     // write pointer
    output [ADDR_WIDTH:0] rptr,         // read pointer
    output [ADDR_WIDTH-1:0] raddr,      // read address
    output logic rempty                 // empty flag 
); 

logic [ADDR_WIDTH:0] rbin, rgrey, rbin_next, rgrey_next; 
logic rempty_next; 
assign rbin_next = rbin + (rinc & ~rfull);
assign rgrey_next = rbin_next ^ (rbin_next >> 1);
assign rempty_next = (rgrey_next == wptr_sync); // here!

always_ff @(posedge rclk or negedge rrst_n) begin
    if (rrst_n == 0) begin
        rbin <= 0;
        rgrey <= 0;
        rempty <= 1'b1;
    end
    else begin
    rbin <= rbin_next;
    rgrey <= rgrey_next;
    rempty <= rempty_next;
    end
end

assign raddr = rbin[ADDR_WIDTH-1:0];
assign rptr = rgrey;

endmodule