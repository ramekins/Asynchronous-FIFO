# Asynchronous (Dual-Clock) FIFO in SystemVerilog with Scoreboard Design Verification

FIFO, standing for First In First Out, is a type of data structure that is quite self explanatory - data is written into the queue and is read out of the queue in the same order that it was put in. In computer hardware it is used as a buffer to pass data streams in sequential order without losing track, and it shows up inside peripherals like UART (Universal Asynchronous Receiver/Transmitter) and SPI (Serial Peripheral Interface) controllers.

The type of FIFO implemented in this project is the asynchronous FIFO, specifically the design described in the paper "Simulation and Synthesis Techniques for Asynchronous FIFO Design" by Clifford E. Cummings, which features grey-coded pointers and two-flop synchronizers. An asynchronous FIFO is useful for passing data between independent clock domains without corruption, as opposed to its much simpler counterpart, the synchronous FIFO (where the read and write sides share the same clock). On top of the RTL, this project also includes a self-checking verification environment with a scoreboard, directed corner-case tests, and some basic coverage tracking.

This project was simulated in AMD Vivado with xsim, meaning if you'd like to test this implementation for yourself you do not need an FPGA!

---

## Block Diagram

```
        WRITE DOMAIN (wclk)                      READ DOMAIN (rclk)
   +--------------------------+          +--------------------------+
   |                          |          |                          |
   |   winc --> wptr_full     |          |     rptr_empty <-- rinc  |
   |             |      ^     |          |      ^       |           |
   |      wptr   |      |     |          |      |       |  rptr     |
   |     (grey)  |      | rptr_sync  wptr_sync  |       | (grey)    |
   |             |      |     |          |      |       |           |
   |             |   +--+-----+--+  +----+------+--+    |           |
   |             +-->|  synchro  |  |   synchro    |<---+           |
   |                 |    w2r ---+--+-->           |                |
   |                 |           |  |    r2w ------+--->            |
   |                 +-----------+  +--------------+                |
   |      waddr  |                         | raddr                  |
   +-------------+-------------------------+------------------------+
                 |                         |
                 v                         v
        +------------------------------------------+
  wdata |              fifo_mem                    | rdata
   ---->|  clocked write (wclk) / comb. read       |---->
        +------------------------------------------+
```

The thing to notice: each pointer crosses into the **opposite** clock domain through its own synchronizer. That's so the flag logic on each side can compare its own local pointer against the synchronized copy of the other one.

---

## How It Works

### Grey-coded pointers

In normal binary counting, several bits can change at once (such as 0111 -> 1000, where all 4 bits are changed). When it comes to crossing clock domains, the receiving flops sample the value at some arbitrary moment - so a mid-transition data sample could produce a value that was never real.

The fix: grey code. As shown in the table below, grey codes only change ONE bit per increment, meaning a bad data sample will give you either the *old* or the *new* value - which are both legitimate.

| Binary | Grey Code |
| --- | --- |
| 000 | 000 |
| 001 | 001 |
| 010 | 011 |
| 011 | 010 |
| 100 | 110 |
| 101 | 111 |
| 110 | 101 |
| 111 | 100 |

Converting binary to grey turns out to be a one-liner: `grey = bin ^ (bin >> 1)`. Shifting right by one lines every binary bit up underneath the bit above it, so one XOR computes every grey bit at the same time.

If you'd like to hear more on my input regarding grey bits, you can read the in-text comments in the file `greybinconv.sv` under the `rtl` folder.

### Two-flop synchronizers

Metastability is a temporary, unstable condition where data-receiving flip-flops get stuck in an odd and invalid mid-level voltage instead of a clear voltage low or high. It happens when a flop samples a signal at the exact moment that signal is changing, which is impossible to avoid when the signal is coming from a completely unrelated clock domain. To combat this, the RTL design includes a synchronizer of two flip-flops in series, where the first flop is there simply to allow time for the data being transferred to exit its metastable state before the second flop samples it.

So grey code and the two-flop synchronizers solve two annoying and unique problems:

- the **grey bit** solution solves multi-bit coherence - only one bit is ever in flight, so whatever gets sampled is a real pointer value
- the **synchronizer** eliminates metastability - each individual bit gets a full clock cycle to settle into a clean 0 or 1

Neither one on its own is enough. You need both.

This is a general synopsis of what I wrote in the comments in the file `synchro.sv`, which can be found under the `rtl` folder - please go to that file if you'd like to read more.

### Full and empty flags

In RTL implementations of FIFO buffers, there are "flags" that signal when the queue is full and when it is empty. Within this specific design, our read and write pointers are one bit longer than the width of their addresses: so for example, if we have 4 bit read and write addresses, the pointers themselves are 5 bits. That extra bit might seem useless or counterintuitive, but its purpose is to signal whether one pointer is a full lap *ahead* of the other.

How can a pointer be a lap ahead of another pointer?

Because the buffer is circular. The write pointer can run all the way around the ring and catch the read pointer from behind (that's **full**), or the read pointer can chase down the write pointer and catch it (that's **empty**). What we care about is when they land on the same address - and once they have, the FIFO is either completely full or completely empty, and without that extra bit you wouldn't be able to tell which unless you actually looked inside the contents of the queue.

(Worth noting: this ambiguity is not caused by the FIFO being asynchronous. A synchronous FIFO has the exact same problem, because it also wraps around. Being asynchronous is why we need the grey coding and the synchronizers, which is a separate issue.)

The scheming goes:

- FIFO is **empty** if the pointers are **EXACTLY** equal - lap bit included.
- FIFO is **full** if the pointers are equal except the top **two** grey bits are inverted.

Now, if you read that second one and thought "shouldn't it only be the one lap bit that's different?" - you'd be right, *in binary*. But we compare the pointers in the grey-code domain, not binary, and inverting one binary bit does not invert exactly one grey bit.

Here's why. Remember from earlier that `grey[i] = bin[i] ^ bin[i+1]`. That means the binary MSB feeds into **two** grey bits, so flipping it flips both of them:

```
grey[4] = bin[4]           <- flips
grey[3] = bin[4] ^ bin[3]  <- also flips, because bin[4] changed
grey[2] = bin[3] ^ bin[2]  <- unchanged
grey[1] = bin[2] ^ bin[1]  <- unchanged
grey[0] = bin[1] ^ bin[0]  <- unchanged
```

One binary bit in, two grey bits out. That's the whole reason the full check inverts two.

Two other details in this design worth mentioning:

- Both flags are computed from the **next** pointer value instead of the current one, so the flag pops out of a register in lockstep with the pointer it's describing rather than lagging a cycle behind it.
- `wfull` resets **low** but `rempty` resets **high**, because a freshly reset FIFO is empty, not full. Same reset event, opposite answers, since the two flags ask opposite questions.

A somewhat more detailed explanation can be found within the files `wptr_full.sv` and `rptr_empty.sv`, under the `rtl` folder.

---

## Repo Structure

| File | Description |
|---|---|
| `rtl/fifo.sv` | The top level. Instantiates and wires up all five sub-blocks - this is the only module you need to instantiate to use the FIFO. |
| `rtl/fifo_mem.sv` | The actual storage. Dual-port: clocked write on the write clock, combinational read. |
| `rtl/wptr_full.sv` | Write pointer (kept in binary *and* grey at the same time) plus the full flag. |
| `rtl/rptr_empty.sv` | Read pointer (binary and grey) plus the empty flag. Mirror image of the write side, but the empty comparison is the easy one. |
| `rtl/synchro.sv` | The two-flop synchronizer, parameterized by width. Instantiated twice, once per crossing direction. |
| `rtl/greybinconv.sv` | Standalone `bin2grey` and `grey2bin` converters. The bin-to-grey logic ends up inlined inside the pointer modules, and `grey2bin` is a verification/reference utility rather than part of the datapath. |
| `tb/tb_fifo.sv` | The main functional test - two-clock scoreboard testbench. |
| `tb/tb_fifo_corner.sv` | Directed corner-case tests, i.e. me trying to break my own FIFO on purpose. |
| `tb/tb_greybinconv.sv` | Exhaustive test of the grey converters. |
| `fluff/` | A tiny 4-bit counter and its testbench, which I used on day one to prove the Vivado simulation flow worked before writing any FIFO code. Not part of the design, kept for posterity. |

---

## Verification

There are three testbenches and all of them are **self-checking** - each one prints its own pass/fail verdict to the Tcl console, so nobody has to squint at a waveform to decide whether it worked.

### 1. `tb_greybinconv.sv` - exhaustive converter test

Sweeps all 16 possible input values and checks two properties:

- **round trip**: `grey2bin(bin2grey(x)) == x` for every `x`, so the conversion is losslessly reversible
- **the grey property itself**: consecutive grey codes differ in exactly one bit, checked with `$countones` on the XOR of successive outputs

Since a 4-bit input space is only 16 values, this sweep is *exhaustive* - there is no 17th input hiding a bug, so this is genuinely proof rather than sampling.

### 2. `tb_fifo.sv` - two-clock scoreboard

The main functional test. A SystemVerilog queue acts as a **golden reference model**: every value written gets pushed on with `push_back`, and every value read back out gets compared against `pop_front`. Since `push_back`/`pop_front` *is* first-in-first-out by definition, the queue is a reference FIFO that's correct by construction - so if the hardware ever disagrees with it, the hardware is wrong.

The writer and reader run as two **independent concurrent processes** on two unrelated clocks (6 ns write, 10 ns read). They never coordinate with each other - they only communicate through the DUT and the queue, which is what makes this an actual asynchronous test rather than a synchronous one in disguise. At the end it also checks the queue got fully drained, which catches data that quietly vanishes.

### 3. `tb_fifo_corner.sv` - corner cases

This one is sequential instead of concurrent, because corner cases need control - "fill it completely, THEN check full, THEN abuse it" is impossible if a reader process is draining the FIFO behind your back.

| Test | What it proves |
|---|---|
| Fill to depth | `wfull` asserts at exactly DEPTH words, not one early or one late |
| Write while full | Holding `winc` high against a full FIFO does not move the write pointer and does not corrupt what's already stored |
| Drain completely | Everything comes back out in the original order, and `rempty` reasserts |
| Read while empty | Holding `rinc` high against an empty FIFO does not move the read pointer |
| Wrap-around | Data is still correct after the pointers pass the wrap point - which is the all-bits-flip transition that grey coding exists to survive in the first place |

The two "abuse" tests use **hierarchical references** into the DUT (`dut.wpf.wbin` and `dut.rpe.rbin`) to look at the real pointers and confirm they genuinely didn't budge, rather than just assuming from the flags. That's what actually verifies the `(winc & ~wfull)` and `(rinc & ~rempty)` gating inside the pointer modules.

### Clock ratios and coverage

Both clock-ratio directions get exercised: `tb_fifo.sv` runs the write clock faster, and `tb_fifo_corner.sv` runs the read clock faster. Different ratios line the edges up differently and stress different timing relationships across the synchronizers, so covering both directions was free coverage for no extra work.

The corner testbench also latches whether `wfull` and `rempty` were *ever actually observed high* and reports it at the end. It's a crude stand-in for real functional coverage, but it answers a different question than "did the test pass" - a test that passes without ever reaching full or empty hasn't really proven much.

---

## How to Run

1. Create a new Vivado RTL project. Any target part is fine - this is simulation only, no synthesis and no FPGA needed.
2. **Add Sources -> Add or Create Design Sources -> Add Directories**, and add `rtl/`. Uncheck **Copy sources into project** so Vivado references the files where they already live.
3. **Add Sources -> Add or Create Simulation Sources -> Add Directories**, and add `tb/`, again without copying.
4. In the Sources panel under **Simulation Sources**, right-click whichever testbench you want to run and pick **Set as Top**. Only one can be the simulation top at a time, so swap between them to run each.
5. **Flow Navigator -> SIMULATION -> Run Simulation -> Run Behavioral Simulation.**
6. Read the verdict in the **Tcl console**:
   - `tb_greybinconv` -> `all checks passed`
   - `tb_fifo` -> `all checks passed - 20 values verified`
   - `tb_fifo_corner` -> `CORNER TESTS PASSED (0 errors)` and `saw_full=1 saw_empty=1`

One gotcha: Vivado doesn't watch the folder, so if it can't see a file you just made, right-click in the Sources panel and hit **Refresh Hierarchy**.

---

## Parameters

| Parameter | Default | Notes |
|---|---|---|
| `DATA_WIDTH` | 8 | How many bits wide each stored word is. |
| `ADDR_WIDTH` | 4 | Address width. Depth is `2**ADDR_WIDTH`, so the default gives 16 words. The pointers are `ADDR_WIDTH+1` bits - that extra top bit is the lap bit the full/empty logic depends on. |

---

## Known Limitations / TODO

Things I know are missing, and what I  add next:

- **No SVA concurrent assertions.** All the checking right now is immediate - `check()` tasks and `if`/`$error` - which only fires at the specific points my tests happen to look. Concurrent assertions (`assert property (@(posedge clk) ...)`) would run continuously in the background for the whole simulation and catch violations in tests I didn't write for that purpose. This is the first thing on the list.
- **No functional coverage.** What I have is two manual latch flags, not real covergroups with bins and cross coverage.
- **Stimulus is directed, not constrained-random.** Every test drives a sequence I wrote by hand, so it only explores states I thought of. Random stimulus with coverage-driven closure would go places I didn't.
- **The `synchro` instances use the default `WIDTH` parameter** instead of deriving it from `ADDR_WIDTH`. Works fine at the defaults, but would silently break if `ADDR_WIDTH` changed. Noted inline in `fifo.sv` - the safe form is `synchro #(.WIDTH(ADDR_WIDTH+1))`.
- **Planned:** rebuild this verification environment in UVM, so I can compare a hand-rolled scoreboard against the framework version and actually understand what the framework is doing for me.

---

## References

### The design

Clifford E. Cummings, *"Simulation and Synthesis Techniques for Asynchronous FIFO Design"*, SNUG 2002 - [sunburst-design.com](http://www.sunburst-design.com). This is the paper the whole RTL side of this project comes from.

### SystemVerilog and verification

Stuff I leaned on for the language and the DV side:

- [SystemVerilog Assertions Basics - systemverilog.io](https://www.systemverilog.io/verification/sva-basics/) - immediate vs concurrent assertions, the implication operators (`|->` and `|=>`), `disable iff`, `$past`/`$rose`/`$fell`/`$stable`, `cover property`, and using `bind` to attach assertions to a design without editing it. This is what the assertions TODO will be built from.
- [SystemVerilog Queues - Verification Guide](https://verificationguide.com/systemverilog/systemverilog-queue/) - the queue mechanics behind the scoreboard (`push_back`, `pop_front`, `size()`).
- [SystemVerilog Functional Coverage - ChipVerify](https://chipverify.com/systemverilog/systemverilog-functional-coverage) and [Cross Coverage](https://chipverify.com/systemverilog/systemverilog-cross-coverage) - covergroups, coverpoints, bins, and crosses, for when the manual coverage latches get replaced with the real thing.
- [Functional Coverage Patterns - FIFO (AMIQ Consulting)](https://www.amiq.com/consulting/2022/06/28/functional-coverage-patterns-fifo/) - FIFO-specific coverage planning, e.g. crossing write-enable against FIFO occupancy and crossing the empty/full states.
- [UVM Support in Vivado Simulator (UG900)](https://docs.amd.com/r/en-US/ug900-vivado-logic-simulation/Universal-Verification-Methodology-UVM-Support) - xsim ships UVM 1.2 precompiled, which is what makes the planned UVM rebuild possible without switching simulators. Also documents the SystemVerilog and cover-property limitations worth knowing about in xsim.
