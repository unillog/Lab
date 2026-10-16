////////////////////////////////////////////////////////////////////////////////
// Project name: EdgeX                                                        //
// File name   : tb.sv                                                        //
// Description : Self-checking testbench for the 4-bit full adder -- all     //
//               512 input combinations vs the arithmetic model              //
// Time        : 2026-09-08                                                   //
// Version     : 0.1.2                                                        //
// Copyright (C) 2026 by Unillog                                             //
////////////////////////////////////////////////////////////////////////////////

// Sweeps every combination of a, b and cin (16 x 16 x 2 = 512 vectors)
// and checks the DUT against plain arithmetic: the 5-bit expected value
// is a + b + cin, so sum must equal expected[3:0] and cout must equal
// expected[4]. The comparisons use !== so an X on any DUT output fails
// LOUDLY -- a 4-state != would evaluate to x and, inside if(x), silently
// take neither branch, which is exactly how a vacuous [PASS] happens
// (measured 2026-09-08: the first revision of this tb passed vacuously
// while the DUT outputs read x). Every vector also prints one trace
// line -- inputs and outputs together, fixed field order:
//   VEC a=<a> b=<b> cin=<cin> sum=<sum> cout=<cout>
// which makes the two tools' runs diffable line by line: run the same
// tb under EdgeX and QuestaSim, keep the ^VEC lines from both (Questa
// prefixes each with "# "), and diff. Prints one [FAIL] line per
// mismatch and a final verdict on top.

`timescale 1ns/1ps
module tb_full_adder_4b;
    logic [3:0] a, b;
    logic       cin;
    logic [3:0] sum;
    logic       cout;

    logic [4:0] expected;
    int         errors;

    full_adder_4b dut (
        .a   (a),
        .b   (b),
        .cin (cin),
        .sum (sum),
        .cout(cout)
    );

    initial begin
        errors = 0;
        for (int i = 0; i < 16; i++) begin
            for (int j = 0; j < 16; j++) begin
                for (int k = 0; k < 2; k++) begin
                    a   = i[3:0];
                    b   = j[3:0];
                    cin = k[0];
                    #1;
                    expected = i + j + k;
                    $display("VEC a=%0d b=%0d cin=%0d sum=%0d cout=%0d",
                             a, b, cin, sum, cout);
                    if (sum !== expected[3:0] || cout !== expected[4]) begin
                        $display("[FAIL] a=%0d b=%0d cin=%0d -> sum=%0d cout=%0d (expected sum=%0d cout=%0d)",
                                 a, b, cin, sum, cout, expected[3:0], expected[4]);
                        errors++;
                    end
                end
            end
        end
        // Marker at line start: run_questa_wsl.py recognises `^\[PASS\]`
        // / `^\[FAIL\]` (fail-closed when the marker is absent).
        if (errors == 0)
            $display("[PASS] all 512 vectors match");
        else
            $display("[FAIL] %0d of 512 vectors mismatched", errors);
        #1;  // let the last vector settle before the final-state dump
        $finish;
    end
endmodule
