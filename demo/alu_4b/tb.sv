////////////////////////////////////////////////////////////////////////////////
// Project name: EdgeX                                                        //
// File name   : tb.sv                                                        //
// Description : Self-checking testbench for alu_4b -- exhaustive sweep of    //
//               8 opcodes x 16 x 16 operand pairs = 2048 vectors             //
// Time        : 2026-09-08                                                   //
// Version     : 0.1.2                                                        //
// Copyright (C) 2026 by Unillog                                              //
////////////////////////////////////////////////////////////////////////////////

// Sweeps every (op, a, b) combination and scores result and carry against
// a golden model written with plain int arithmetic (independent of the
// DUT's packed-vector operators). The comparisons use !== so an X on any
// DUT output fails LOUDLY -- a 4-state != would evaluate to x and take
// neither branch, the vacuous-[PASS] trap measured on 2026-09-08 with the
// first revision of the full_adder_4b tb. Every vector also prints one
// trace line, inputs and outputs together, fixed field order, so EdgeX
// and QuestaSim runs diff line by line:
//   VEC op=<op> a=<a> b=<b> result=<result> carry=<carry>
//
// Style note: the golden model avoids a case on the int loop variable --
// EdgeX's tb import drops such a case today (EDX-C0013, measured
// 2026-09-08); an if/else-if chain classifies fine.

`timescale 1ns/1ps
module tb_alu_4b;
    localparam int N_VEC = 2048;

    logic [2:0] op;
    logic [3:0] a, b;
    logic [3:0] result;
    logic       carry;

    logic [7:0] exp8;      // golden result, wide enough for i << 3
    logic       carry_exp;
    int         errors;

    alu_4b dut (
        .op    (op),
        .a     (a),
        .b     (b),
        .result(result),
        .carry (carry)
    );

    initial begin
        errors = 0;
        for (int o = 0; o < 8; o++) begin
            for (int i = 0; i < 16; i++) begin
                for (int j = 0; j < 16; j++) begin
                    op = o[2:0];
                    a  = i[3:0];
                    b  = j[3:0];
                    #1;

                    // Golden model in plain int arithmetic.
                    carry_exp = 1'b0;
                    exp8      = 8'd0;
                    if (o == 0) begin          // ADD
                        exp8 = i + j;
                        if (exp8[4])
                            carry_exp = 1'b1;
                    end else if (o == 1) begin // SUB (borrow out)
                        exp8 = i - j + 16;
                        if (i < j)
                            carry_exp = 1'b1;
                    end else if (o == 2) begin // AND
                        exp8 = i & j;
                    end else if (o == 3) begin // OR
                        exp8 = i | j;
                    end else if (o == 4) begin // XOR
                        exp8 = i ^ j;
                    end else if (o == 5) begin // NOT a
                        exp8 = (~i) & 15;
                    end else if (o == 6) begin // SLL by b[1:0]
                        exp8 = i << j[1:0];
                    end else begin             // SRL by b[1:0]
                        exp8 = i >> j[1:0];
                    end

                    $display("VEC op=%0d a=%0d b=%0d result=%0d carry=%0d",
                             op, a, b, result, carry);
                    if (result !== exp8[3:0] || carry !== carry_exp) begin
                        $display("[FAIL] op=%0d a=%0d b=%0d -> result=%0d carry=%0d (expected result=%0d carry=%0d)",
                                 op, a, b, result, carry, exp8[3:0], carry_exp);
                        errors++;
                    end
                end
            end
        end

        // Marker at line start: run_questa_wsl.py recognises `^\[PASS\]`
        // / `^\[FAIL\]` (fail-closed when the marker is absent).
        if (errors == 0)
            $display("[PASS] all %0d vectors match", N_VEC);
        else
            $display("[FAIL] %0d of %0d vectors mismatched", errors, N_VEC);
        #1;
        $finish;
    end
endmodule
