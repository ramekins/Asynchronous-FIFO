// synchro
//
// two flip flops in series which carry a Grey pointer
// across the clock boundary. this fixes metastability:
// the flops might sample a signal right at the moment
// when it crosses from one clock domain into a different one.
// when this happens, the flop cannot decide 0 or 1, hovering
// at an undefined voltage before randomly settling, which
// is metastability. 
//
// this is why we put two flops in series. the first
// one samples the incoming signal which might be metastable
// but once it leaves the second one it doesn't matter anymore
// because it has been given time to adjust to the new
// clock domain.

module synchro #(parameter WIDTH = 5) (
    input clk,
    input rst_n,
    input [WIDTH-1:0] d_in,
    output logic [WIDTH-1:0] d_out
);

logic [WIDTH-1:0] q1;

always_ff @(posedge clk or negedge rst_n) begin
    if (rst_n == 0) begin
        q1 <= 0;
        d_out <= 0;
    end
    else begin
        q1 <= d_in;
        d_out <= q1;
    end
end

endmodule
