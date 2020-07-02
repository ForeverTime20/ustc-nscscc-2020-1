`timescale 1ns / 1ps
module register #(parameter WIDTH = 32)(
    input [WIDTH-1:0] d,
    input clk,en,rst,Flush,
    output reg [WIDTH-1:0] q
    );
    always @(posedge clk) begin
        if(rst | Flush) q<=0;
        else if(en) q<=d;
    end
endmodule

