
`timescale 1ns/1ps

module butterfly_e2_hy3281 (
    input  logic        clk,
    input  logic        rst_n,

    input  logic        in_valid,
    output logic        in_ready,

    input  logic [11:0] a,
    input  logic [11:0] b,
    input  logic [11:0] zeta,

    output logic [11:0] u,
    output logic [11:0] v,
    output logic        out_valid
);

    // Barrett approximation. For product < 2^26, quotient is exact
    // or one too small, so the residual needs at most one subtraction.
    function automatic logic [11:0] reduce(input logic [23:0] product);
        logic [38:0] scaled;
        logic [12:0] quotient;
        logic [24:0] residual;
        scaled = product * 15'd20158;
        quotient = scaled[38:26];
        residual = {1'b0, product} - quotient * 25'd3329;
        if (residual >= 25'd3329)
            residual = residual - 25'd3329;
        return residual[11:0];
    endfunction

    // Stage 0: Input registers
    logic [11:0] s0_a, s0_b, s0_zeta;
    logic s0_valid;

    // Stage 1: Multiplication
    logic [11:0] s1_a;
    logic [23:0] s1_product;
    logic s1_valid;

    // Stage 2: Modular reduction
    logic [11:0] s2_a, s2_t;
    logic s2_valid;

    // Stage 3: Modular addition/subtraction
    logic [12:0] sum, diff;
    logic [11:0] next_u, next_v;

    // Fixed pipeline: always accepts one input/cycle
    assign in_ready = 1'b1;

    always_comb begin
        sum = {1'b0, s2_a} + {1'b0, s2_t};

        if (sum >= 13'd3329)
            next_u = sum - 13'd3329;
        else
            next_u = sum[11:0];

        if (s2_a >= s2_t)
            diff = {1'b0, s2_a} - {1'b0, s2_t};
        else
            diff = {1'b0, s2_a} + 13'd3329
                   - {1'b0, s2_t};

        next_v = diff[11:0];
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s0_a       <= '0;
            s0_b       <= '0;
            s0_zeta    <= '0;
            s0_valid   <= 1'b0;

            s1_a       <= '0;
            s1_product <= '0;
            s1_valid   <= 1'b0;

            s2_a       <= '0;
            s2_t       <= '0;
            s2_valid   <= 1'b0;

            u          <= '0;
            v          <= '0;
            out_valid  <= 1'b0;
        end
        else begin

            // Stage 0: Capture inputs
            s0_valid <= in_valid;
            if (in_valid) begin
                s0_a    <= a;
                s0_b    <= b;
                s0_zeta <= zeta;
            end

            // Stage 1: Compute multiplication
            s1_valid <= s0_valid;
            if (s0_valid) begin
                s1_a       <= s0_a;
                s1_product <= s0_b * s0_zeta;
            end

            // Stage 2: Compute modular reduction
            s2_valid <= s1_valid;
            if (s1_valid) begin
                s2_a <= s1_a;
                s2_t <= reduce(s1_product);
            end

            // Stage 3: Compute final outputs
            out_valid <= s2_valid;
            if (s2_valid) begin
                u <= next_u;
                v <= next_v;
            end

        end
    end

endmodule
