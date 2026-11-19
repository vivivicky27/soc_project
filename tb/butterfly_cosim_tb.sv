`timescale 1ns/1ps
module butterfly_cosim_tb;
    logic clk = 0;
    always #5 clk = ~clk;
    logic rst_n = 1, in_valid = 0;
    logic [11:0] a = 0, b = 0, zeta = 0;
    wire in_ready, out_valid;
    wire [11:0] u, v;
    int aa, bb, zz, status;
    localparam STDIN = 32'h80000000;
    `BUTTERFLY_DUT dut (.*);

    initial begin
        #1 rst_n = 0;
        @(negedge clk);
        rst_n = 1;
        $display("COSIM_READY");
        $fflush();
        status = $fscanf(STDIN, "%d %d %d", aa, bb, zz);
        while (status == 3) begin
            if (aa < 0 || aa >= 3329 || bb < 0 || bb >= 3329 || zz < 0 || zz >= 3329)
                $fatal(1, "Invalid request");
            a = aa;
            b = bb;
            zeta = zz;
            in_valid = 1;
            @(posedge clk);
            if (in_ready !== 1'b1) $fatal(1, "Request was not accepted");
            @(negedge clk);
            in_valid = 0;
            repeat (3) @(negedge clk);
            if (out_valid !== 1'b1) $fatal(1, "Missing pipeline result");
            $display("COSIM_RESULT %0d %0d", u, v);
            $fflush();
            status = $fscanf(STDIN, "%d %d %d", aa, bb, zz);
        end
        if (status != -1) $fatal(1, "Malformed request");
        $finish;
    end
endmodule
