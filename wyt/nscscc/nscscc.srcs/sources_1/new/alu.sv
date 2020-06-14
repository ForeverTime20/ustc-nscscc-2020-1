`timescale 1ns / 1ps
`include "aluop.vh"

module alu(
    input clk,
    input rst,
    input [31:0] a, b,
    input [5:0] op,
    input [31:0] hi_i,
    input [31:0] lo_i,						
    output logic [31:0] result,
    output logic [2:0]  exception,
    output logic [31:0] hi_o,
    output logic [31:0] lo_o,
    output logic stall			
    );

    wire [63:0] mul_res;
    reg [31:0] mul_a, mul_b;
    reg mul_sign;
    reg mul_begin;
    reg mul_done;

    reg [31:0] div_dividend, div_divisor;
    wire [31:0] div_quotient, div_remainder;
    reg div_sign, div_dividend_sign;
    reg div_begin;
    reg div_done;

    multiplier_control multiplier_control (
        .clk        (clk),
        .rst        (rst),
        .mul_begin  (mul_begin),
        .mul_sign   (mul_sign),
        .mul_a      (mul_a),
        .mul_b      (mul_b),
        .mul_res    (mul_res),
        .mul_done   (mul_done)
    );
    divider_control divider_control (
        .clk                (clk),
        .rst                (rst),
        .div_begin          (div_begin),
        .div_sign           (div_sign),
        .div_dividend_sign  (div_dividend_sign),
        .div_dividend       (div_dividend),
        .div_divisor        (div_divisor),
        .div_quotient       (div_quotient),
        .div_remainder      (div_remainder),
        .div_done           (div_done)
    );

    assign stall = mul_begin | div_begin;

    always_comb begin : calculate_result
        result = 0;
        mul_begin = 0;
        mul_sign = 0;
        mul_a = 0;
        mul_b = 0;
        div_begin = 0;
        div_sign = 0;
        div_dividend_sign = 0;
        div_dividend = 0;
        div_divisor = 0;
        case (op)
            `ALU_ADD, `ALU_ADDI:
                result = a + b;
            `ALU_ADDIU:
                result = a + $signed(b[15:0]);
            `ALU_SUB, `ALU_SUBU:
                result = a - b;
            `ALU_SLT:
                result = $signed(a) < $signed(b) ? 1 : 0;
            `ALU_SLTI:
                result = $signed(a) < $signed(b[15:0]) ? 1 : 0;
            `ALU_SLTU:
                result = a < b ? 1 : 0;
            `ALU_SLTIU:
                result = a < $signed(b[15:0]) ? 1 : 0;

            `ALU_DIV: begin
                div_begin = 1;
                div_sign = a[31] ^ b[31];
                div_dividend_sign = a[31];
                div_dividend = a[31]? ~ a + 1 : a;
                div_divisor = b[31]? ~ b + 1 : b;
            end

            `ALU_DIVU: begin
                div_begin = 1;
                div_sign = 0;
                div_dividend_sign = 0;
                div_dividend = a;
                div_divisor = b;
            end

            `ALU_MULT: begin
                mul_begin = 1;
                mul_sign = a[31] ^ b[31];
                mul_a = a[31]? ~ a + 1 : a;
                mul_b = b[31]? ~ b + 1 : b;
            end

            `ALU_MULTU: begin
                mul_begin = 1;
                mul_sign = 0;
                mul_a = a;
                mul_b = b;
            end

            `ALU_AND, `ALU_ANDI:
                result = a & b;
            `ALU_LUI:
                result = {b[15:0], 16'b0};
            `ALU_NOR:
                result = ~ (a | b);
            `ALU_OR, `ALU_ORI:
                result = a | b;
            `ALU_XOR, `ALU_XORI:
                result = a ^ b;
            `ALU_SLLV, `ALU_SLL:
                result = b << a[4:0];
            `ALU_SRAV, `ALU_SRA:
                result = $signed(b) >>> a[4:0];
            `ALU_SRLV, `ALU_SRL:
                result = b >> a[4:0];
            `ALU_LB, `ALU_LBU, `ALU_SB,
            `ALU_LH, `ALU_LHU, `ALU_SH,
            `ALU_LW, `ALU_SW:
                result = a + $signed(b[15:0]);
            `ALU_MFHI:
                result = hi_i;
            `ALU_MFLO:
                result = lo_i;
        endcase
    end
    
    always_comb begin : set_exception
        exception = 0;
        case (op)
            `ALU_ADD, `ALU_ADDI:
                if((a[31] ~^ b[31]) & (a[31] ^ result[31])) 
                    exception = `EXP_OVERFLOW;
            `ALU_SUB:
                if((a[31] ^ b[31]) & (a[31] ^ result[31]))
                    exception = `EXP_OVERFLOW; 
            `ALU_DIV, `ALU_DIVU:
                if(b == 32'b0)
                    exception = `EXP_DIVZERO;
            `ALU_BREAK:
                exception = `EXP_BREAK;
            `ALU_SYSCALL:
                exception = `EXP_SYSCALL;
            `ALU_LH, `ALU_LHU, `ALU_SH:
                if(result[0] != 1'b0)
                    exception = `EXP_ADDRERR;
            `ALU_LW, `ALU_SW:
                if(result[1:0] != 2'b00)
                    exception = `EXP_ADDRERR;
            `ALU_ERET:
                exception = `EXP_ERET;
        endcase
    end

    always_comb begin : set_hilo
        if(mul_done) begin
            hi_o = mul_res[63:32];
            lo_o = mul_res[31:0];
        end
        else if(div_done) begin
            hi_o = div_quotient;
            lo_o = div_remainder;
        end
        else if(op == `ALU_MTHI) begin
            hi_o = a; 
            lo_o = lo_i;
        end
        else if(op == `ALU_MTLO) begin
            hi_o = hi_i;
            lo_o = a;
        end
        else begin
            hi_o = hi_i;
            lo_o = lo_i;
        end
    end

endmodule
