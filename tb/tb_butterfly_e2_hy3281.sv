
`timescale 1ns/1ps

module tb_butterfly_e2_hy3281;

    localparam int Q = 3329;

    logic clk = 0;
    logic rst_n = 0;
    logic in_valid = 0;
    logic in_ready;
    logic [11:0] a = 0, b = 0, zeta = 0;
    logic [11:0] u, v;
    logic out_valid;

    int accepted = 0;
    int completed = 0;
    int cycles = 0;

    // Golden-model pipeline: 4 register stages
    logic [11:0] exp_u [0:3];
    logic [11:0] exp_v [0:3];
    logic [3:0]  exp_valid = 0;

    logic [11:0] last_u = 0;
    logic [11:0] last_v = 0;

    always #5 clk = ~clk; // 100 MHz

    butterfly_e2_hy3281 dut (
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

    // Drive one request at a negative clock edge
    task automatic send(
        input bit valid,
        input int unsigned aa,
        input int unsigned bb,
        input int unsigned zz
    );
        @(negedge clk);
        in_valid = valid;
        a = aa;
        b = bb;
        zeta = zz;
    endtask

    // Cycle-by-cycle scoreboard
    always @(posedge clk) begin : scoreboard
        int unsigned t;
        integer i;

        if (!rst_n) begin
            exp_valid = '0;

            for (i = 0; i < 4; i = i + 1) begin
                exp_u[i] = 0;
                exp_v[i] = 0;
            end

            last_u = 0;
            last_v = 0;

            #1;
            if (out_valid !== 1'b0 ||
                u !== 12'd0 || v !== 12'd0)
                $fatal(1, "RESET FAILED");
        end
        else begin
            cycles++;

            // Shift expected results forward
            for (i = 3; i > 0; i = i - 1) begin
                exp_valid[i] = exp_valid[i-1];
                exp_u[i] = exp_u[i-1];
                exp_v[i] = exp_v[i-1];
            end

            // Reference arithmetic
            exp_valid[0] = in_valid;

            if (in_valid) begin
                t = (int'(b) * int'(zeta)) % Q;

                exp_u[0] = (int'(a) + t) % Q;
                exp_v[0] = (int'(a) + Q - t) % Q;

                accepted++;
            end

            // Wait for sequential output updates
            #1;

            if (in_ready !== 1'b1)
                $fatal(1, "IN_READY FAILED");

            if (out_valid !== exp_valid[3]) begin
                $fatal(1,
                    "VALID ALIGNMENT FAILED: cycle=%0d expected=%0b actual=%0b",
                    cycles, exp_valid[3], out_valid);
            end

            if (exp_valid[3]) begin
                if (u !== exp_u[3] ||
                    v !== exp_v[3]) begin

                    $display("FAIL at cycle %0d", cycles);
                    $display("Expected: u=%0d v=%0d",
                             exp_u[3], exp_v[3]);
                    $display("Actual:   u=%0d v=%0d",
                             u, v);

                    $fatal(1, "PIPELINE DATA MISMATCH");
                end

                last_u = exp_u[3];
                last_v = exp_v[3];
                completed++;
            end
            else begin
                if (u !== last_u || v !== last_v)
                    $fatal(1, "OUTPUT HOLD FAILED");
            end
        end
    end

    initial begin
        // Hold reset for 3 cycles
        repeat (3) @(negedge clk);
        rst_n = 1;

        // Directed cases, including back-to-back requests
        send(1, 100, 200, 17);
        send(1, 0, 0, 0);
        send(1, 3328, 3328, 3328);
        send(1, 1, 1, 1);
        send(1, 3328, 1, 3328);
        send(1, 0, 3328, 3328);

        // Bubble followed by valid requests
        send(0, 100, 200, 17);
        send(1, 1234, 2345, 123);

        // Randomized input and valid patterns
        repeat (1000) begin
            send(
                ($urandom_range(0, 4) != 0),
                $urandom_range(0, 3328),
                $urandom_range(0, 3328),
                $urandom_range(0, 3328)
            );
        end

        // Drain the pipeline
        repeat (4)
            send(0, 0, 0, 0);

        @(posedge clk);
        #2;

        if (accepted != completed)
            $fatal(1, "UNFINISHED REQUESTS");

        $display("--------------------------------");
        $display("ALL TESTS PASSED");
        $display("E2 PIPELINE VERIFIED");
        $display("Accepted requests: %0d", accepted);
        $display("Completed results: %0d", completed);
        $display("Checked cycles: %0d", cycles);
        $display("--------------------------------");

        $finish;
    end

endmodule
