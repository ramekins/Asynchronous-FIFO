`timescale 1ns/1ps

module tb_greybinconv();

logic [3:0] bin_in;
logic [3:0] grey_mid;
logic [3:0] bin_out;
logic [3:0] prev_grey;

bin2grey b2g (.bin(bin_in), .grey(grey_mid));
grey2bin g2b (.grey(grey_mid), .bin(bin_out));

initial begin 
for (int i = 0; i <= 15; i++) begin
    bin_in = i;
    #1;
    if (bin_out != bin_in) begin
        $error("roundtrip failed: bin_in=%b bin_out=%b", bin_in, bin_out);
    end
    if (i > 0 && $countones(grey_mid ^ prev_grey) != 1) begin
        $error("gray not 1-bit: prev=%b curr=%b", prev_grey, grey_mid);
    end
    prev_grey = grey_mid;
end
    $display("all checks passed");
end
endmodule