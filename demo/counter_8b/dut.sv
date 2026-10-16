////////////////////////////////////////////////////////////////////////////////
// Project name: EdgeX                                                        //
// File name   : dut.sv                                                       //
// Description : 8-bit counter with synchronous reset, enable and a wrap      //
//               flag -- exercises clocked always_ff and NBA updates          //
// Time        : 2026-09-08                                                   //
// Version     : 0.1.2                                                        //
// Copyright (C) 2026 by Unillog                                              //
////////////////////////////////////////////////////////////////////////////////

// Counts up on every rising clk edge while en is high, holds while en is
// low; rst is synchronous and returns cnt to 0. wrap is a registered flag
// that is 1 in the cycle where cnt transitioned 255 -> 0. Pure sequential
// logic, so the testbench can carry a golden counter of its own and score
// every cycle against it.

module counter_8b (
    input  logic       clk,
    input  logic       rst,   // synchronous reset to 0
    input  logic       en,    // count enable
    output logic [7:0] cnt,
    output logic       wrap   // set on the edge where cnt wrapped 255 -> 0
);
    always_ff @(posedge clk) begin
        if (rst) begin
            cnt  <= 8'd0;
            wrap <= 1'b0;
        end else begin
            wrap <= en && (cnt == 8'd255);
            cnt  <= en ? cnt + 8'd1 : cnt;
        end
    end
endmodule
