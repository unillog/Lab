////////////////////////////////////////////////////////////////////////////////
// Project name: EdgeX                                                        //
// File name   : tb.sv                                                        //
// Description : Self-checking testbench for counter_8b -- directed 582-step  //
//               stimulus scored cycle by cycle against a golden counter      //
// Time        : 2026-09-08                                                   //
// Version     : 0.1.2                                                        //
// Copyright (C) 2026 by Unillog                                              //
////////////////////////////////////////////////////////////////////////////////

// Drives one deterministic stimulus sequence (582 clocked steps):
//   step 0         rst=1           -> reset
//   steps 1..520   en=1            -> free run, crosses 255 -> 0 twice
//   steps 521..530 en=0            -> hold
//   step 531       rst=1           -> reset mid-count
//   steps 532..581 en=1 with hold gaps (540..545, 550..552)
// Every step is scored against a golden model kept in the testbench with
// ===/!== so an X on any DUT output fails LOUDLY (a 4-state != would
// evaluate to x and take neither branch -- the vacuous-[PASS] trap that
// the full_adder_4b tb first revision fell into, measured 2026-09-08).
// Every step also prints one trace line, inputs and outputs together,
// fixed field order, so EdgeX and QuestaSim runs diff line by line:
//   VEC step=<t> rst=<r> en=<e> cnt=<cnt> wrap=<w>
//
// Style note: the stimulus avoids ternary ``?:`` on the right-hand side
// of procedural assignments -- EdgeX's tb import skips those today
// (EDX-I0005, measured 2026-09-08); plain if/else classifies fine.

`timescale 1ns/1ps
module tb_counter_8b;
    localparam int N_STEPS = 582;

    logic       clk, rst, en;
    logic [7:0] cnt;
    logic       wrap;

    logic [7:0] cnt_exp;
    logic       wrap_exp;
    int         errors;

    counter_8b dut (
        .clk (clk),
        .rst (rst),
        .en  (en),
        .cnt (cnt),
        .wrap(wrap)
    );

    initial begin
        errors   = 0;
        clk      = 0;
        cnt_exp  = 8'd0;
        wrap_exp = 1'b0;

        for (int t = 0; t < N_STEPS; t++) begin
            rst = 1'b0;
            en  = 1'b0;
            if (t == 0 || t == 531)
                rst = 1'b1;
            if (t >= 1 && t <= 520)
                en = 1'b1;
            if (t >= 532 && t <= 581)
                en = 1'b1;
            if (t >= 540 && t <= 545)
                en = 1'b0;
            if (t >= 550 && t <= 552)
                en = 1'b0;

            // Golden model: post-edge values from pre-edge state.
            if (rst) begin
                cnt_exp  = 8'd0;
                wrap_exp = 1'b0;
            end else begin
                wrap_exp = 1'b0;
                if (en) begin
                    if (cnt_exp == 8'd255)
                        wrap_exp = 1'b1;
                    cnt_exp = cnt_exp + 8'd1;
                end
            end

            #1 clk = 1;  // the rising edge; NBAs settle within #1
            #1;
            $display("VEC step=%0d rst=%0d en=%0d cnt=%0d wrap=%0d",
                     t, rst, en, cnt, wrap);
            if (cnt !== cnt_exp || wrap !== wrap_exp) begin
                $display("[FAIL] step=%0d cnt=%0d (expected %0d) wrap=%0d (expected %0d)",
                         t, cnt, cnt_exp, wrap, wrap_exp);
                errors++;
            end
            clk = 0;
            #1;
        end

        // Marker at line start: run_questa_wsl.py recognises `^\[PASS\]`
        // / `^\[FAIL\]` (fail-closed when the marker is absent).
        if (errors == 0)
            $display("[PASS] all %0d steps match", N_STEPS);
        else
            $display("[FAIL] %0d of %0d steps mismatched", errors, N_STEPS);
        #1;
        $finish;
    end
endmodule
