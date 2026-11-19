
`timescale 1ns/1ps

module tb_butterfly_e0_hy3281;

    localparam int Q = 3329;

    logic clk = 0;
    logic rst_n = 0;
    logic in_valid;
    logic in_ready;
    logic [11:0] a, b, zeta;
    logic [11:0] u, v;
    logic out_valid;

    int test_count = 0;
    int unsigned last_u = 0;
    int unsigned last_v = 0;

    always #5 clk = ~clk; // 100 MHz

    butterfly_e0_hy3281 dut (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(in_valid),
        .in_ready(in_ready),
        .a(a),
        .b(b),
        .zeta(zeta),
        .u(u),
        .v(v),
        .out_valid(out_valid)
    );

    // Send one input and compare with the golden result
    task automatic check_one(
        input bit valid,
        input int unsigned aa,
        input int unsigned bb,
        input int unsigned zz
    );
        int unsigned t;
        int unsigned expected_u;
        int unsigned expected_v;

        t = (bb * zz) % Q;

        if (valid) begin
            expected_u = (aa + t) % Q;
            expected_v = (aa + Q - t) % Q;
        end else begin
            expected_u = last_u;
            expected_v = last_v;
        end

        // Drive inputs before the active clock edge
        @(negedge clk);
        in_valid = valid;
        a = aa;
        b = bb;
        zeta = zz;

        if (in_ready !== 1'b1)
            $fatal(1, "Input not ready");

        @(posedge clk);
        #1; // Wait for nonblocking assignments

        if (out_valid !== valid ||
            u !== expected_u[11:0] ||
            v !== expected_v[11:0]) begin

            $display("FAIL: a=%0d b=%0d zeta=%0d",
                     aa, bb, zz);
            $display("Expected: u=%0d v=%0d valid=%0d",
                     expected_u, expected_v, valid);
            $display("Actual:   u=%0d v=%0d valid=%0d",
                     u, v, out_valid);

            $fatal(1, "BUTTERFLY TEST FAILED");
        end

        last_u = expected_u;
        last_v = expected_v;
        test_count++;
    endtask

    initial begin
        in_valid = 0;
        a = 0;
        b = 0;
        zeta = 0;

        // Reset
        repeat (3) @(posedge clk);
        #1;

        if (u !== 0 || v !== 0 || out_valid !== 0)
            $fatal(1, "RESET TEST FAILED");

        @(negedge clk);
        rst_n = 1;

        // Directed tests
        check_one(1, 100, 200, 17);     // u=171, v=29
        check_one(1, 0, 0, 0);
        check_one(1, 3328, 3328, 3328);
        check_one(1, 1, 1, 1);
        check_one(1, 3328, 1, 3328);
        check_one(1, 0, 3328, 3328);

        // Invalid cycle: outputs must remain unchanged
        check_one(0, 100, 200, 17);

        // 1000 randomized tests, one per cycle
        repeat (1000) begin
            check_one(
                1,
                $urandom_range(0, 3328),
                $urandom_range(0, 3328),
                $urandom_range(0, 3328)
            );
        end

        $display("--------------------------------");
        $display("ALL TESTS PASSED");
        $display("Total checked cycles: %0d", test_count);
        $display("--------------------------------");

        $finish;
    end

endmodule
