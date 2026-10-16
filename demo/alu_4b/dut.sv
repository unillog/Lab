////////////////////////////////////////////////////////////////////////////////
// Project name: EdgeX                                                        //
// File name   : dut.sv                                                       //
// Description : 4-bit ALU -- eight operations selected by a 3-bit opcode,    //
//               exercises always_comb, case and shift operators              //
// Time        : 2026-09-08                                                   //
// Version     : 0.1.2                                                        //
// Copyright (C) 2026 by Unillog                                              //
////////////////////////////////////////////////////////////////////////////////

// Pure combinational datapath. carry carries the ADD carry out, doubles
// as the SUB borrow out, and is 0 for the logic and shift operations.
// The default arm drives x on purpose: the testbench sweeps op 0..7, so
// an x in any output means the case fell into a hole it should not have.
//
// Style note: ADD/SUB go through a 5-bit temp instead of assigning the
// concatenation {carry, result} = ... directly -- EdgeX skips a concat
// on the LEFT-hand side of a procedural assignment today (measured
// 2026-09-08: result silently stayed x); reading bit/part-selects on the
// right-hand side classifies fine.

module alu_4b (
    input  logic [2:0] op,
    input  logic [3:0] a,
    input  logic [3:0] b,
    output logic [3:0] result,
    output logic       carry
);
    logic [4:0] op5;

    always_comb begin
        carry = 1'b0;
        case (op)
            3'd0: begin                                     // ADD
                op5    = {1'b0, a} + {1'b0, b};
                result = op5[3:0];
                carry  = op5[4];
            end
            3'd1: begin                                     // SUB (borrow)
                op5    = {1'b0, a} - {1'b0, b};
                result = op5[3:0];
                carry  = op5[4];
            end
            3'd2: result = a & b;                            // AND
            3'd3: result = a | b;                            // OR
            3'd4: result = a ^ b;                            // XOR
            3'd5: result = ~a;                               // NOT a
            3'd6: result = a << b[1:0];                      // SLL by b[1:0]
            3'd7: result = a >> b[1:0];                      // SRL by b[1:0]
            default: begin
                result = 4'bx;
                carry  = 1'bx;
            end
        endcase
    end
endmodule
