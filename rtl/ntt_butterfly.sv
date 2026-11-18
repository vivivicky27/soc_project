`timescale 1ns/1ps
// Baseline forward CT butterfly. Legal operands: 0 <= a,b,zeta < 3329.
// Inputs are accepted on every rising edge with in_valid=1.
// Outputs and out_valid update just after that edge; no backpressure.
module ntt_butterfly (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        in_valid,
    input  logic [11:0] a,
    input  logic [11:0] b,
    input  logic [11:0] zeta,
    output logic        out_valid,
    output logic [11:0] u,
    output logic [11:0] v
);
    localparam logic [12:0] Q = 13'd3329;
    logic [23:0] product;
    logic [11:0] t;
    logic [12:0] sum, difference;
    logic [11:0] u_next, v_next;

    always_comb begin
        product = {12'd0, b} * {12'd0, zeta};
        t = product % 24'd3329;
        sum = {1'b0, a} + {1'b0, t};
        u_next = (sum >= Q) ? (sum - Q) : sum;
        // Add q before subtraction to avoid a negative unsigned value.
        difference = {1'b0, a} + Q - {1'b0, t};
        v_next = (difference >= Q) ? (difference - Q) : difference;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid <= 1'b0;
            u <= 12'd0;
            v <= 12'd0;
        end else begin
            out_valid <= in_valid;
            if (in_valid) begin
                u <= u_next;
                v <= v_next;
            end
        end
    end
endmodule
