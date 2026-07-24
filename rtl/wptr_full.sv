// wptr_full
// purpose: handles write pointer of the FIFO & flag when FIFO is full
//
// q: conceptually how does it work?
//
// a: full flags are a little tricky because a lot of the times
// read and write pointers run on different clock speeds.
// it's especially an issue when the pointers end up back at
// their starting address and we want to know whether the FIFO
// is empty or full without looking at the data at all.
//
// the way that this is actually determined is by adding
// an extra bit to the MSB to see whether if the
// write pointer has done a full loop around the FIFO.
// you'll compare this with the read pointer which 
// would be on the same address.
//
// for example - if the FIFO is full at read and write address 0110
// without the added extra bit at the front, the read and write address 
// would both be 0110. but with this method, we use the first bit to 
// determine if it's full or empty. in this case, write pointer is
// 10110, and read pointer is 00110. to check for full, compare only
// the first number. wptr == {~rptr[4], rptr[3:0]} 
// 
// in this instance, we also convert the binary value of the write
// pointer, convert it into grey code which is intended to save
// data across clock domains. after it's been converted into grey
// code, compare the addresses to determine if FIFO is full or 
// empty. when comparing in grey code, it is the same method
// as in binary, except when doing in grey code we are actually
// comparing the first TWO bits instead of only the MSB.

module wptr_full #(parameter ADDR_WIDTH = 4)(
    input wclk,                         // write clock
    input wrst_n,                       // write reset
    input winc,                         // write request
    input [ADDR_WIDTH:0] rptr_sync,     // read pointer
    output [ADDR_WIDTH:0] wptr,         // write pointer
    output [ADDR_WIDTH-1:0] waddr,      // write address
    output logic wfull                  // full flag 
); 

logic [ADDR_WIDTH:0] wbin, wgrey, wbin_next, wgrey_next; // start with write - write binary, grey code, and its next values
logic wfull_next; // 
assign wbin_next = wbin + winc;
assign wgrey_next = wbin_next ^ (wbin_next >> 1);
assign wfull_next = (wgrey_next == {~rptr_sync[ADDR_WIDTH:ADDR_WIDTH-1], 
rptr_sync[ADDR_WIDTH-2:0]});


always_ff @(posedge wclk or negedge wrst_n) begin
    if (wrst_n == 0) begin
        wbin <= 0;
        wgrey <= 0;
        wfull <= 0;
    end
    else begin
    wbin <= wbin_next;
    wgrey <= wgrey_next;
    wfull <= wfull_next;
    end
end

assign waddr = wbin[ADDR_WIDTH-1:0];
assign wptr = wgrey;

endmodule