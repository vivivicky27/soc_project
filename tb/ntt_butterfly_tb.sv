`timescale 1ns/1ps
module ntt_butterfly_tb;
    logic clk = 0;
    always #5 clk = ~clk;
    logic rst_n = 0, in_valid = 0;
    logic [11:0] a = 0, b = 0, zeta = 0;
    wire out_valid;
    wire [11:0] u, v;
    integer checks = 0;
    integer i, j, k;
    integer boundaries [0:3] = '{0, 1, 3327, 3328};
    ntt_butterfly dut (.*);

    task automatic check(input integer aa, bb, zz, input bit valid);
        integer tt, expected_u, expected_v;
        begin
            @(negedge clk);
            a = aa; b = bb; zeta = zz; in_valid = valid;
            tt = (bb * zz) % 3329;
            expected_u = (aa + tt) % 3329;
            expected_v = (aa - tt + 3329) % 3329;
            @(posedge clk); #1;
            if (out_valid !== valid)
                $fatal(1, "valid mismatch");
            if (valid && (u !== expected_u || v !== expected_v))
                $fatal(1, "a=%0d b=%0d zeta=%0d got %0d,%0d expected %0d,%0d",
                       aa, bb, zz, u, v, expected_u, expected_v);
            if (valid && (u >= 3329 || v >= 3329))
                $fatal(1, "output outside canonical range");
            checks++;
        end
    endtask

    initial begin
        // Exercise asynchronous reset, including invalidation of a result.
        #1; rst_n = 1; #1; rst_n = 0; #1;
        if (out_valid !== 0 || u !== 0 || v !== 0) $fatal(1, "reset failed");
        @(negedge clk); rst_n = 1;
        check(10, 4, 3, 1);
        for (i = 0; i < 4; i++)
            for (j = 0; j < 4; j++)
                for (k = 0; k < 4; k++)
                    check(boundaries[i], boundaries[j], boundaries[k], 1);
        // Consecutive valid transactions and bubbles, with an independent model.
        for (i = 0; i < 10000; i++)
            check($urandom_range(0,3328), $urandom_range(0,3328),
                  $urandom_range(0,3328), (i % 7 != 0));
        check(3328, 3328, 3328, 1);
        #1; rst_n = 0; #1;
        if (out_valid !== 0 || u !== 0 || v !== 0) $fatal(1, "mid-run reset failed");
        @(negedge clk); rst_n = 1;
        check(10, 4, 3, 1);
        check(0, 0, 0, 0);
        $display("PASS: %0d transactions checked", checks);
        $finish;
    end
endmodule
