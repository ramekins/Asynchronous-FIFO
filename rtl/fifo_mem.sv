// fifo_mem
//
// purpose: it's just the memory of the FIFO.
//

module fifo_mem #(parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4)(
    input wclk, // write clock
    input wr_en, // enable write

    input [ADDR_WIDTH-1:0] waddr, // write address
    input [ADDR_WIDTH-1:0] raddr, // read address
    input [DATA_WIDTH-1:0] wdata,  // data write
    output [DATA_WIDTH-1:0] rdata // data read
);

localparam DEPTH = 1 << ADDR_WIDTH;
logic [DATA_WIDTH-1:0] mem [0:DEPTH-1]; // an array: each element DATA_WIDTH bits, DEPTH of them. mem[3] is the word at address 3

// write: clocked
always_ff @(posedge wclk) begin
    if (wr_en) begin
        mem[waddr] <= wdata;
    end
end

// read: unclocked
assign rdata = mem[raddr];

// q: why is write clocked and read is not?
// a: write has to happen at precise moments in time (in our example a clock edge).
// it mutates (changes) memory.
// read, on the other hand, only observes the data and does not change/mutate it. 

endmodule