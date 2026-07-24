// counter
//
// purpose: a simple counter 
// i made, meant just to test 
// vivado studio :3

module counter( 
    input clk,
    input rst_n,
    output logic [3:0] count
);

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        count <= 4'b0;
    end
    else begin
        count <= count + 1;
    end
end
endmodule