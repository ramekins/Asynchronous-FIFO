// tb_fifo_corner
// purpose: directed corner-case tests. the scoreboard tb (tb_fifo.sv) proves
// the FIFO works normally. this one tries to break it on purpose.
//
// q: why is this a separate file instead of just adding to tb_fifo.sv?
//
// a: tb_fifo.sv runs the writer and reader as two independent processes at
// the same time, which is what you want for testing an async design normally.
// but corner cases need CONTROL - "fill it completely, THEN check full, THEN
// abuse it" is impossible if the reader is draining behind your back.
// so this tb is one single sequential process instead.
//
// q: why are the clocks flipped compared to tb_fifo.sv?
//
// a: tb_fifo.sv has the WRITE clock faster (6ns vs 10ns). this file has the
// READ clock faster. that way between the two testbenches i've covered both
// directions, which stress different timing relationships in the
// synchronizers. free coverage, no extra work.
//
// the 5 tests:
//   1. fill to DEPTH             -> wfull should assert
//   2. write while full          -> pointer should NOT move, data survives
//   3. drain completely          -> data comes back in order, rempty asserts
//   4. read while empty          -> pointer should NOT move
//   5. wrap-around refill/drain  -> still correct after pointers pass the wrap
//
`timescale 1ns/1ps

module tb_fifo_corner();

    localparam DATA_WIDTH = 8;
    localparam ADDR_WIDTH = 4;
    localparam DEPTH      = 1 << ADDR_WIDTH;   // 16 words

    // write side
    logic wclk, wrst_n, winc;
    logic [DATA_WIDTH-1:0] wdata;

    // read side
    logic rclk, rrst_n, rinc;
    logic [DATA_WIDTH-1:0] rdata;

    // flags
    logic wfull, rempty;

    int errors = 0;    // count failures instead of just printing "passed"

    // poor man's coverage - did the test actually REACH these states?
    // a test that passes but never hit full or empty proves basically nothing.
    logic saw_full  = 0;
    logic saw_empty = 0;

    fifo dut (.wclk(wclk), .wrst_n(wrst_n), .winc(winc), .wdata(wdata),
              .rclk(rclk), .rrst_n(rrst_n), .rinc(rinc), .rdata(rdata),
              .wfull(wfull), .rempty(rempty));

    // clocks - read side is the fast one here (opposite of tb_fifo.sv)
    initial wclk = 0;
    initial rclk = 0;
    always #5 wclk = ~wclk;   // 10ns period
    always #3 rclk = ~rclk;   // 6ns period

    // latch the flags if we ever see them high
    always @(posedge wclk) if (wfull)  saw_full  <= 1;
    always @(posedge rclk) if (rempty) saw_empty <= 1;

    // ---------------------------------------------------------------
    // helper tasks
    //
    // q: what is a task?
    // a: basically a subroutine. lets me write do_write(5) instead of
    // copy pasting the same 5 lines every time. makes the actual test
    // body readable.
    // ---------------------------------------------------------------

    // one write. drive the data + winc first, THEN let one wclk edge
    // commit it. order matters - the edge is what actually does the write.
    task do_write(input [DATA_WIDTH-1:0] d);
        wdata <= d;
        winc  <= 1;
        @(posedge wclk);      // write lands here
        #1;
        winc  <= 0;
    endtask

    // one read. remember rdata is a COMBINATIONAL read of mem[raddr], so the
    // value is already sitting there before i pulse rinc. like a book that's
    // always open to the current page - read the page, THEN turn it.
    // so: capture first, advance second. backwards = off by one.
    task do_read(output [DATA_WIDTH-1:0] d);
        d = rdata;            // capture BEFORE the pointer moves
        rinc <= 1;
        @(posedge rclk);      // pop lands here
        #1;
        rinc <= 0;
    endtask

    // check something and count it if it fails
    task check(input logic cond, input string msg);
        if (!cond) begin
            errors++;
            $error("FAIL: %s", msg);
        end
    endtask

    // ---------------------------------------------------------------
    // the actual test
    // ---------------------------------------------------------------
    initial begin : main
        logic [DATA_WIDTH-1:0] got, exp_val;
        logic [ADDR_WIDTH:0]   wbin_before, wbin_after;
        logic [ADDR_WIDTH:0]   rbin_before, rbin_after;

        // reset both domains
        wrst_n = 0; rrst_n = 0;
        winc   = 0; rinc   = 0; wdata = 0;
        repeat (4) @(posedge wclk);
        wrst_n = 1; rrst_n = 1;
        repeat (4) @(posedge wclk);

        // reset asymmetry check - fresh FIFO is empty, not full
        check(rempty === 1'b1, "rempty should be high right after reset");
        check(wfull  === 1'b0, "wfull should be low right after reset");

        // ---- test 1: fill it up ----
        $display("[T1] filling %0d words", DEPTH);
        for (int i = 0; i < DEPTH; i++) begin
            exp_val = i;
            do_write(exp_val);
        end

        repeat (3) @(posedge wclk);   // let it settle
        check(wfull === 1'b1, "wfull should be high after DEPTH writes");

        // ---- test 2: write while full ----
        // this is the test that the ungated pointer bug would have failed.
        // holding winc high against a full FIFO should do NOTHING - the
        // (winc & ~wfull) gating in wptr_full is what protects it.
        //
        // q: how do i prove the pointer didn't move?
        // a: hierarchical reference - dut.wpf.wbin reaches inside the DUT
        // and grabs the actual pointer. so i can compare before vs after
        // instead of just assuming.
        $display("[T2] hammering winc while full");
        wbin_before = dut.wpf.wbin;
        wdata <= 8'hEE;                // a value that must NEVER show up later
        winc  <= 1;
        repeat (6) @(posedge wclk);
        #1;
        winc  <= 0;
        wbin_after = dut.wpf.wbin;
        check(wbin_after === wbin_before,
              $sformatf("write pointer moved while full: %0d -> %0d",
                        wbin_before, wbin_after));
        check(wfull === 1'b1, "wfull should still be high");

        // ---- test 3: drain it, check order ----
        // if 0xEE shows up here, test 2 lied and data got corrupted
        $display("[T3] draining and checking order");
        for (int i = 0; i < DEPTH; i++) begin
            wait (!rempty);
            do_read(got);
            exp_val = i;
            check(got === exp_val,
                  $sformatf("order/data mismatch at %0d: expected %0h got %0h",
                            i, exp_val, got));
        end

        repeat (4) @(posedge rclk);   // let the pointer cross domains
        check(rempty === 1'b1, "rempty should be high after draining all words");

        // wfull has to release too, but only after the read pointer
        // crosses BACK into the write domain (2 flops + a compare)
        repeat (4) @(posedge wclk);
        check(wfull === 1'b0, "wfull should have released after draining");

        // ---- test 4: read while empty ----
        // mirror of test 2. nothing to read, so the pointer better not move.
        $display("[T4] hammering rinc while empty");
        rbin_before = dut.rpe.rbin;
        rinc <= 1;
        repeat (6) @(posedge rclk);
        #1;
        rinc <= 0;
        rbin_after = dut.rpe.rbin;
        check(rbin_after === rbin_before,
              $sformatf("read pointer moved while empty: %0d -> %0d",
                        rbin_before, rbin_after));
        check(rempty === 1'b1, "rempty should still be high");

        // ---- test 5: wrap-around ----
        // both pointers are sitting at DEPTH now, so this batch crosses the
        // wrap point in the address space. this is the transition that would
        // be all-bits-flip in binary (1111 -> 0000) and is exactly why the
        // pointers are grey coded. data should still come out in order.
        $display("[T5] wrap-around refill/drain");
        for (int i = 0; i < DEPTH/2; i++) begin
            exp_val = 8'hA0 + i;
            do_write(exp_val);
        end

        for (int i = 0; i < DEPTH/2; i++) begin
            wait (!rempty);
            do_read(got);
            exp_val = 8'hA0 + i;
            check(got === exp_val,
                  $sformatf("wrap mismatch at %0d: expected %0h got %0h",
                            i, exp_val, got));
        end

        // ---- verdict ----
        repeat (4) @(posedge rclk);
        $display("--------------------------------------------------");
        $display("coverage: saw_full=%0b  saw_empty=%0b", saw_full, saw_empty);
        if (!saw_full || !saw_empty)
            $display("WARNING: test never reached one of the corner states");
        if (errors == 0)
            $display("CORNER TESTS PASSED (0 errors)");
        else
            $display("CORNER TESTS FAILED: %0d error(s)", errors);
        $display("--------------------------------------------------");
        $finish;
    end

    // safety timeout so a deadlock doesn't hang the sim forever.
    // if i see TIMEOUT instead of a verdict, something stalled -
    // probably a wait() that never released.
    initial begin
        #10000;
        $display("TIMEOUT - test did not complete (likely a stall)");
        $finish;
    end

endmodule
