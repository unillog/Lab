////////////////////////////////////////////////////////////////////////////////
// Project name: EdgeX                                                        //
// File name   : dut.sv                                                       //
// Description : Moore FSM detecting the serial pattern 1011 (overlapping),   //
//               exercises state registers, localparam encoding and a         //
//               two-always-block (comb next-state / ff state) style          //
// Time        : 2026-09-08                                                   //
// Version     : 0.1.2                                                        //
// Copyright (C) 2026 by Unillog                                              //
////////////////////////////////////////////////////////////////////////////////

// States encode the longest suffix of the input stream that is a prefix
// of 1011; det is 1 whenever that suffix is the full pattern. Overlap
// works because e.g. S_1011 falls back to S_1 on a 1 (the last 1 is also
// the first 1 of the next match).

module fsm_seq_1011 (
    input  logic clk,
    input  logic rst,   // synchronous, back to the idle state
    input  logic din,
    output logic det
);
    localparam [2:0] S_IDLE  = 3'd0,  // no useful suffix
                     S_1     = 3'd1,  // "1"
                     S_10    = 3'd2,  // "10"
                     S_101   = 3'd3,  // "101"
                     S_1011  = 3'd4;  // "1011" -- match

    logic [2:0] state, next;

    always_comb begin
        case (state)
            S_IDLE:  next = din ? S_1    : S_IDLE;
            S_1:     next = din ? S_1    : S_10;
            S_10:    next = din ? S_101  : S_IDLE;
            S_101:   next = din ? S_1011 : S_10;
            default: next = din ? S_1    : S_10;  // S_1011
        endcase
    end

    always_ff @(posedge clk) begin
        if (rst)
            state <= S_IDLE;
        else
            state <= next;
    end

    assign det = (state == S_1011);
endmodule
