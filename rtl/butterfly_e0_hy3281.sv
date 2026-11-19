`timescale 1ns/1ps

module butterfly_e0_hy3281 (
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

    localparam logic [23:0] Q = 24'd3329;

    logic [23:0] product;
    logic [11:0] t;
    logic [12:0] sum;
    logic [12:0] diff;

    logic [11:0] next_u;
    logic [11:0] next_v;

    // Baseline: one operation per clock
    assign in_ready = 1'b1;

    always_comb begin
        // Modular multiplication
        product = b * zeta;
        t = product % Q;

        // Modular addition
        sum = {1'b0, a} + {1'b0, t};

        if (sum >= 13'd3329)
            next_u = sum - 13'd3329;
        else
            next_u = sum[11:0];

        // Modular subtraction
        if (a >= t)
            diff = {1'b0, a} - {1'b0, t};
        else
            diff = {1'b0, a} + 13'd3329 - {1'b0, t};

        next_v = diff[11:0];
    end

    // Output registers
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            u         <= 12'd0;
            v         <= 12'd0;
            out_valid <= 1'b0;
        end
        else begin
            out_valid <= in_valid;

            if (in_valid) begin
                u <= next_u;
                v <= next_v;
            end
        end
    end

endmodule
