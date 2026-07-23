// convert a binary number to grey code number
// how it works: start with binary number, shift it right 1 place, and XOR it with the original number

// for example 101 -> 101 ^ 010 = 111
// decimal: 5, binary: 101, grey: 111 
module bin2grey #(parameter WIDTH = 4) 
(
    input logic [WIDTH-1:0] bin, // input LOGIC, different from reg and wire
    output logic [WIDTH-1:0] grey
);

    assign grey = bin ^ (bin >> 1);

endmodule


// convert a grey code number to binary
// how it works: start with with the MSB 
// your MSB input will always equal your MSB output
// e.g; Y4 = X4 (x input, y output)
// go to the next output Y3.
// now, Y3 becomes X4 XOR X3.
// after, Y2 = X4 XOR X3 XOR X2.
// and so on.

// for example, take 101, do each line individually
// X2 stays the same so Y2 = 1 
// now do X2 ^ X1, equals 1 so Y1 = 1
// now X2 ^ X1 ^ X0, equals 0, so Y0 = 0
// result: Y = 110
module grey2bin #(parameter WIDTH = 4) 
(
    input logic [WIDTH-1:0] grey,
    output logic [WIDTH-1:0] bin
);

always_comb begin
    bin[WIDTH-1] = grey[WIDTH-1];
    for (int i = WIDTH-2; i >= 0; i--)
        bin[i] = bin[i+1] ^ grey[i];
   end
endmodule