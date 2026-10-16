////////////////////////////////////////////////////////////////////////////////
// Project name: EdgeX                                                        //
// File name   : tb.sv                                                        //
// Description : Self-checking demo -- join blocks until its branch finishes;//
//               join_none returns immediately and the branch runs on its   //
//               own, both against a golden $time model                    //
// Time        : 2026-09-09                                                  //
// Version     : 0.1.3                                                       //
// Copyright (C) 2026 by Unillog                                             //
////////////////////////////////////////////////////////////////////////////////

// N94 (2026-09-09, Mgt/EdgeX_0.1.3/W202609_0713/EdgeX-Plan-Master-
// 202609_0713.md mục 3.5, VIỆC D): this folder replaces two probe files
// that used to sit loose at Dev/demo/ root (e4.sv, e5.sv -- one
// `join_none`, one `join`), left there while chasing what turned out to
// be N94 (join_none silently dropping its branch's entire body, see the
// debt ledger). Built into a real demo now that the fix lands: the two
// join styles side by side, self-checked against $time, the way
// counter_8b/tb.sv checks a golden model.
//
// The distinguishing IEEE 1800 semantic (clause 9.3.2): `join` suspends
// the parent until every forked branch completes; `join_none` returns
// to the parent immediately, and the branch keeps running independently
// in the background. Checked here as plain `int` snapshots of `$time`
// (not the `time` type itself -- EdgeX does not yet classify `time`-
// typed arithmetic/comparison, measured while building this demo; that
// is a separate, pre-existing gap, not part of N94, and out of scope
// here) -- demo_join()'s own caller must see time already advanced by
// BRANCH_DELAY when it returns; demo_join_none()'s own caller must not.
// join_none_ran is set by the join_none branch itself and checked at
// the very end, once the whole run has settled -- if N94 ever
// regresses, that branch's body silently never runs again, and this
// flag stays 0 forever, which is exactly what the final check below
// catches.

module tb_fork_join;
    localparam int BRANCH_DELAY = 3;

    int errors;
    int join_none_ran;

    task automatic demo_join();
        int t0;
        t0 = $time;
        $display("[join] before fork, t=%0d", t0);
        fork
            begin
                #(BRANCH_DELAY);
                $display("[join] branch done, t=%0d", $time);
            end
        join
        $display("[join] after join (must have waited), t=%0d", $time);
        if ($time != t0 + BRANCH_DELAY) begin
            $display("[FAIL] join returned at t=%0d, expected t=%0d", $time, t0 + BRANCH_DELAY);
            errors++;
        end
    endtask

    task automatic demo_join_none();
        int t0;
        t0 = $time;
        $display("[join_none] before fork, t=%0d", t0);
        fork
            begin
                #(BRANCH_DELAY);
                join_none_ran = 1;
                $display("[join_none] branch done, t=%0d", $time);
            end
        join_none
        $display("[join_none] right after the fork statement (must NOT have waited), t=%0d",
                 $time);
        if ($time != t0) begin
            $display("[FAIL] join_none blocked until t=%0d, expected t=%0d", $time, t0);
            errors++;
        end
    endtask

    initial begin
        errors = 0;
        join_none_ran = 0;

        demo_join();
        demo_join_none();

        // BRANCH_DELAY + 1, not BRANCH_DELAY: the branch's own #(BRANCH_
        // DELAY) and this wait would otherwise land at the EXACT same
        // time slot as each other, and IEEE 1800 leaves same-time-slot
        // ordering between independent processes arbitrary (the same
        // reason lib/Kernel/Kernel.cpp's own N41/N94 notes exist) --
        // measured directly while building this demo: with equal
        // delays, $finish below sometimes wins the tie and the branch
        // never gets a turn to set join_none_ran at all, which LOOKS
        // like the N94 bug returning but is really this demo tying its
        // own two clocks. The +1 gives the branch a full time slot of
        // its own before anything here can end the run.
        #(BRANCH_DELAY + 1);
        if (join_none_ran != 1) begin
            $display(
                "[FAIL] join_none branch never ran its own body -- exactly the N94 shape (rc=0, no diagnostic)");
            errors++;
        end

        if (errors == 0)
            $display("[PASS] join blocks, join_none does not, both branches ran");
        else
            $display("[FAIL] %0d check(s) mismatched", errors);
        $finish;
    end
endmodule
