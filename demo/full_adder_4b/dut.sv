////////////////////////////////////////////////////////////////////////////////
// Project name: EdgeX                                                        //
// File name   : dut.sv                                                       //
// Description : 4-bit ripple-carry full adder built from four 1-bit cells   //
// Time        : 2026-09-08                                                   //
// Version     : 0.1.2                                                        //
// Copyright (C) 2026 by Unillog                                             //
////////////////////////////////////////////////////////////////////////////////

// Adds two 4-bit operands and a carry-in; produces a 4-bit sum and a
// carry-out. Structural RTL: one 1-bit full adder cell instantiated
// four times, each cell's carry feeding the next cell (IEEE 1800-2023
// arithmetic -- {cout,sum} = a + b + cin, range 0..31).
//
// Shape note (2026-09-08): each cell drives its OWN scalar wire and the
// parent assembles sum with one concat assign. The earlier revision
// connected cell outputs to BIT-SELECTS of parent vectors
// (.sum(sum[0]), .cout(c[0])) -- EdgeX drops the value on that
// connection shape (the tb read x; the same sources run correctly on
// QuestaSim; probe kept at /mnt/c/Users/Public/edgex_n71/fa_probe/),
// so the demo uses whole-scalar connections, which EdgeX verifies
// correctly on this exact design.

module full_adder (
    input  logic a,
    input  logic b,
    input  logic cin,
    output logic sum,
    output logic cout
);
    assign sum  = a ^ b ^ cin;
    assign cout = (a & b) | (cin & (a ^ b));
endmodule

module full_adder_4b (
    input  logic [3:0] a,
    input  logic [3:0] b,
    input  logic       cin,
    output logic [3:0] sum,
    output logic       cout
);
    // Cell outputs land on scalar wires (see shape note above); the
    // parent assembles the vectors.
    logic s0, s1, s2, s3;
    logic c0, c1, c2, c3;

    full_adder fa0 (.a(a[0]), .b(b[0]), .cin(cin), .sum(s0), .cout(c0));
    full_adder fa1 (.a(a[1]), .b(b[1]), .cin(c0),  .sum(s1), .cout(c1));
    full_adder fa2 (.a(a[2]), .b(b[2]), .cin(c1),  .sum(s2), .cout(c2));
    full_adder fa3 (.a(a[3]), .b(b[3]), .cin(c2),  .sum(s3), .cout(c3));

    assign sum  = {s3, s2, s1, s0};
    assign cout = c3;
endmodule
