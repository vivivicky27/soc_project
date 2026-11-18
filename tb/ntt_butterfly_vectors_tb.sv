`timescale 1ns/1ps
// Expected answers come from the Python model, not from SV arithmetic.
module ntt_butterfly_vectors_tb;
    logic clk = 0;
    always #5 clk = ~clk;
    logic rst_n = 0, in_valid = 0;
    logic [11:0] a = 0, b = 0, zeta = 0;
    wire out_valid;
    wire [11:0] u, v;
    integer fd, status, aa, bb, zz, expected_u, expected_v;
    integer checks = 0;
    string vector_path;
    ntt_butterfly dut (.*);

    initial begin
        if (!$value$plusargs("VECTORS=%s", vector_path))
            vector_path = "butterfly_vectors.txt";
        fd = $fopen(vector_path, "r");
        if (fd == 0) $fatal(1, "Cannot open %s", vector_path);
        #1; rst_n = 1; #1; rst_n = 0;
        @(negedge clk); rst_n = 1;
        status = $fscanf(fd, "%d %d %d %d %d", aa, bb, zz, expected_u, expected_v);
        while (status == 5) begin
            @(negedge clk);
            a = aa; b = bb; zeta = zz; in_valid = 1;
            @(posedge clk); #1;
            if (out_valid !== 1'b1 || u !== expected_u || v !== expected_v)
                $fatal(1, "Row %0d: got %0d,%0d expected %0d,%0d",
                       checks + 1, u, v, expected_u, expected_v);
            checks++;
            status = $fscanf(fd, "%d %d %d %d %d", aa, bb, zz, expected_u, expected_v);
        end
        if (status != -1) $fatal(1, "Malformed vector file after row %0d", checks);
        if (checks == 0) $fatal(1, "Empty vector file");
        $fclose(fd);
        @(negedge clk); in_valid = 0;
        @(posedge clk); #1;
        if (out_valid !== 0) $fatal(1, "valid did not clear");
        $display("PASS: %0d Python golden vectors checked against RTL", checks);
        $finish;
    end
endmodule
