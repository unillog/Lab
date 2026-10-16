////////////////////////////////////////////////////////////////////////////////
// Project name: EdgeX                                                        //
// File name   : tb.sv                                                        //
// Description : Self-checking testbench for fsm_seq_1011 -- all 64 six-bit  //
//               input sequences, scored step by step against a golden       //
//               sliding-window model                                        //
// Time        : 2026-09-08                                                   //
// Version     : 0.1.2                                                        //
// Copyright (C) 2026 by Unillog                                              //
////////////////////////////////////////////////////////////////////////////////

// Feeds every 6-bit sequence (64 of them, LSB first, reset before each)
// through the FSM and scores det after every clock edge against a golden
// model that needs no state machine of its own: the match condition
// "the last four input bits were 1,0,1,1" is just a shift register
// compare. The comparisons use !== so an X on det fails LOUDLY -- a
// 4-state != would evaluate to x and take neither branch, the
// vacuous-[PASS] trap measured on 2026-09-08 with the first revision of
// the full_adder_4b tb. Every data step also prints one trace line,
// input and output together, fixed field order, so EdgeX and QuestaSim
// runs diff line by line:
//   VEC seq=<s> step=<k> din=<din> det=<det>

`timescale 1ns/1ps
module tb_fsm_seq_1011;
    localparam int N_SEQ  = 64;
    localparam int SEQLEN = 6;
    localparam int N_VEC  = N_SEQ * SEQLEN;  // 384 scored steps

    logic       clk, rst, din;
    logic       det;

    logic [3:0] hist;      // last four input bits, oldest at [3]
    logic       det_exp;
    int         k_seen;
    int         errors;

    fsm_seq_1011 dut (
        .clk (clk),
        .rst (rst),
        .din (din),
        .det (det)
    );

    initial begin
        errors = 0;
        clk    = 0;
        for (int s = 0; s < N_SEQ; s++) begin
            // Reset step (not traced): back to idle before each sequence.
            rst = 1;
            din = 0;
            #1 clk = 1; #1;
            clk = 0; #1;
            hist   = 4'd0;
            k_seen = 0;
            rst    = 0;

            for (int k = 0; k < SEQLEN; k++) begin
                din    = (s >> k) & 1;
                hist   = {hist[2:0], din};
                k_seen = k_seen + 1;
                det_exp = (k_seen >= 4) && (hist == 4'b1011);

                #1 clk = 1;  // the rising edge; NBAs settle within #1
                #1;
                $display("VEC seq=%0d step=%0d din=%0d det=%0d",
                         s, k, din, det);
                if (det !== det_exp) begin
                    $display("[FAIL] seq=%0d step=%0d din=%0d det=%0d (expected %0d)",
                             s, k, din, det, det_exp);
                    errors++;
                end
                clk = 0;
                #1;
            end
        end

        // Marker at line start: run_questa_wsl.py recognises `^\[PASS\]`
        // / `^\[FAIL\]` (fail-closed when the marker is absent).
        if (errors == 0)
            $display("[PASS] all %0d steps match", N_VEC);
        else
            $display("[FAIL] %0d of %0d steps mismatched", errors, N_VEC);
        #1;
        $finish;
    end
endmodule
