////////////////////////////////////////////////////////////////////////////////
// Project name: EdgeX                                                        //
// File name   : demo_rtl.sv                                                  //
// Description : Self-checking RTL demo -- the constructs EdgeX runs today    //
// Time        : 2026-09-03                                                   //
// Version     : 0.1.2                                                        //
// Copyright (C) 2026 by Unillog                                              //
////////////////////////////////////////////////////////////////////////////////

// A deliberately ordinary RTL design, written to exercise exactly the
// constructs EdgeX is Qualified on today (see `edgex capabilities`):
// clocked always_ff with async reset, always_comb, NBA vs blocking in
// their own regions, 4-state X propagation, casex/casez, generate,
// packed and unpacked arrays, functions, and real arithmetic.
//
// It self-checks: every test prints [PASS] or [FAIL], so the same source
// is meaningful under EdgeX and under QuestaSim without a diff tool.

package demo_pkg;
    localparam int LANES = 4;
    localparam int W     = 8;

    // Plain combinational function -- inlined by the front-end.
    function automatic logic [W-1:0] gray_encode(input logic [W-1:0] v);
        return v ^ (v >> 1);
    endfunction

    function automatic logic [W-1:0] gray_decode(input logic [W-1:0] g);
        logic [W-1:0] v;
        v = g;
        v = v ^ (v >> 1);
        v = v ^ (v >> 2);
        v = v ^ (v >> 4);
        return v;
    endfunction
endpackage

// One lane: a register stage plus a small opcode-driven ALU.
module demo_lane
    import demo_pkg::*;
#(
    parameter int ID = 0
)(
    input  logic             clk,
    input  logic             rst_n,
    input  logic [1:0]       op,
    input  logic [W-1:0]     a,
    input  logic [W-1:0]     b,
    output logic [W-1:0]     result,
    output logic             valid
);
    logic [W-1:0] alu_out;

    // Combinational ALU with a casez wildcard arm.
    always_comb begin
        casez (op)
            2'b00:   alu_out = a + b;
            2'b01:   alu_out = a - b;
            2'b1?:   alu_out = gray_encode(a);   // both 10 and 11
            default: alu_out = '0;
        endcase
    end

    // Sequential stage: async reset, non-blocking update.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= '0;
            valid  <= 1'b0;
        end else begin
            result <= alu_out;
            valid  <= 1'b1;
        end
    end
endmodule

module demo_rtl;
    import demo_pkg::*;

    logic             clk;
    logic             rst_n;
    logic [1:0]       op;
    logic [W-1:0]     a, b;
    logic [W-1:0]     result [0:LANES-1];   // unpacked array of packed
    logic             valid  [0:LANES-1];

    int               pass_count;
    int               fail_count;

    // Four structurally identical lanes -- the shape EdgeX targets.
    genvar gi;
    generate
        for (gi = 0; gi < LANES; gi = gi + 1) begin : g_lane
            demo_lane #(.ID(gi)) u_lane (
                .clk    (clk),
                .rst_n  (rst_n),
                .op     (op),
                .a      (a + gi[W-1:0]),
                .b      (b),
                .result (result[gi]),
                .valid  (valid[gi])
            );
        end
    endgenerate

    always begin
        #5 clk = ~clk;
    end

    // `check` takes a `string` name directly -- item 4 (2026-09-04,
    // Mgt/EdgeX_0.1.2/W202609_0107/EdgeX-Plan-2026-09-03_failclosed.md
    // mục 3.4) wired DYNAMIC support into `input string` task/function
    // arguments, closing the workaround this used to need (a numbered
    // %0d in place of a name, see the report's own history).
    task automatic check(input string name, input logic cond);
        if (cond) begin
            pass_count = pass_count + 1;
            $display("[PASS] %s", name);
        end else begin
            fail_count = fail_count + 1;
            $display("[FAIL] %s", name);
        end
    endtask

    // Real arithmetic runs in the compiled path (Qualified).
    real scale;
    real scaled;

    initial begin
        clk        = 1'b0;
        rst_n      = 1'b0;
        op         = 2'b00;
        a          = 8'd0;
        b          = 8'd0;
        pass_count = 0;
        fail_count = 0;

        // ---- 1. async reset holds outputs at 0 -------------------------
        @(posedge clk);
        check("async reset holds lane0 result at 0", result[0] === 8'd0);
        check("async reset holds lane0 valid low", valid[0] === 1'b0);

        rst_n = 1'b1;

        // ---- 2. add across all four lanes ------------------------------
        a  = 8'd10;
        b  = 8'd7;
        op = 2'b00;
        @(posedge clk);
        @(posedge clk);
        check("lane0 add 10+7 = 17", result[0] === 8'd17);
        check("lane1 add 11+7 = 18", result[1] === 8'd18);
        check("lane2 add 12+7 = 19", result[2] === 8'd19);
        check("lane3 add 13+7 = 20", result[3] === 8'd20);
        check("valid asserted after reset release", valid[0] === 1'b1);

        // ---- 3. subtract, including 2's-complement wrap ----------------
        a  = 8'd5;
        b  = 8'd9;
        op = 2'b01;
        @(posedge clk);
        @(posedge clk);
        check("lane0 sub 5-9 wraps to 252", result[0] === 8'd252);

        // ---- 4. casez wildcard: op 10 and 11 both take the gray arm ----
        a  = 8'hB4;
        op = 2'b10;
        @(posedge clk);
        @(posedge clk);
        check("casez arm 2'b10 -> gray(B4)", result[0] === gray_encode(8'hB4));

        op = 2'b11;
        @(posedge clk);
        @(posedge clk);
        check("casez arm 2'b11 -> same gray arm", result[0] === gray_encode(8'hB4));

        // ---- 5. function round-trip ------------------------------------
        check("gray_decode(gray_encode(B4)) round-trip",
              gray_decode(gray_encode(8'hB4)) === 8'hB4);

        // ---- 6. 4-state: X propagates, it is not silently 0 -------------
        a = 8'hxx;
        b = 8'd1;
        op = 2'b00;
        @(posedge clk);
        @(posedge clk);
        check("X operand propagates to result", result[0] === 8'hxx);

        // ---- 7. real arithmetic ----------------------------------------
        scale  = 2.5;
        scaled = scale * 4.0;
        check("real 2.5 * 4.0 == 10.0", scaled == 10.0);

        // ---- 8. blocking vs non-blocking ordering -----------------------
        begin
            logic [W-1:0] x, y;
            x = 8'd1;
            y = 8'd2;
            x = y;              // blocking: x sees y immediately
            check("blocking assign takes effect at once", x === 8'd2);
        end

        $display("");
        $display("DEMO COMPLETE: %0d passed, %0d failed",
                 pass_count, fail_count);
        if (fail_count == 0)
            $display("ALL TESTS COMPLETE");
        $finish;
    end
endmodule
