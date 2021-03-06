`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/08/05 19:16:10
// Design Name: 
// Module Name: iTLB
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module TLB(
	input clk,
	input rst,
	
	
	input [31:0] logic_addr,
	input [1:0] reftype,
	output [31:0] phy_addr,
	//TLB exceptions
	output Refill,
	output Invalid,
	output Modified,
	//TLB write
	input we,
	input [31:0] EntryHi,
	input [31:0] PageMask,
	input [31:0] EntryLo0,
	input [31:0] EntryLo1,
	//TLB output
	output [31:0] output_EntryHi,
	output [31:0] output_PageMask,
	output [31:0] output_EntryLo0,
	output [31:0] output_EntryLo1
);
localparam fetch = 2'b00;
localparam load  = 2'b01;
localparam store = 2'b10;

//TLB registers
reg [18:0] VPN2 	[0:31];
reg [7:0]  ASID 	[0:31];
reg [11:0] Pagemask [0:31];
reg        G        [0:31];
reg [19:0] PFN0     [0:31];
reg [4:0]  CDV0     [0:31];
reg [19:0] PFN1     [0:31];
reg [4:0]  CDV1     [0:31];

//wires from logic_addr
wire [18:0] vahigh;
wire va12;
wire [11:0] valow;
wire [7:0] addr_ASID;
assign vahigh=logic_addr[31:13];
assign addr_ASID=logic_addr[7:0];
assign va12=logic_addr[12];
assign valow=logic_addr[11:0];

//judging type of addr
wire [2:0] iseg = logic_addr[31:29];
wire i_kseg3    = iseg[2]&iseg[1]&iseg[0];       //3'b111
wire i_ksseg    = iseg[2]&iseg[1]&(~iseg[0]);    //3'b110
wire i_kseg1    = iseg[2]&(~iseg[1])&iseg[0];    //3'b101
wire i_kseg0    = iseg[2]&(~iseg[1])&(~iseg[0]); //3'b100
wire i_useg     = ~iseg[2];                      //3'b0xx
//regs for comparing TLB
reg [31:0] found;
reg [19:0] PFN;
reg [2:0] c;
reg d,v;
assign Refill=!(|found);
assign Invalid=!v;
assign Modified=(d==0 & reftype==store);
reg [4:0] hitidx;
always @(*) begin
    casez (found)
        32'b???????????????????????????????1: hitidx <= 0;
        32'b??????????????????????????????10: hitidx <= 1;
        32'b?????????????????????????????100: hitidx <= 2;
        32'b????????????????????????????1000: hitidx <= 3;
        32'b???????????????????????????10000: hitidx <= 4;
        32'b??????????????????????????100000: hitidx <= 5;
        32'b?????????????????????????1000000: hitidx <= 6;
        32'b????????????????????????10000000: hitidx <= 7;
        32'b???????????????????????100000000: hitidx <= 8;
        32'b??????????????????????1000000000: hitidx <= 9;
        32'b?????????????????????10000000000: hitidx <= 10;
        32'b????????????????????100000000000: hitidx <= 11;
        32'b???????????????????1000000000000: hitidx <= 12;
        32'b??????????????????10000000000000: hitidx <= 13;
        32'b?????????????????100000000000000: hitidx <= 14;
        32'b????????????????1000000000000000: hitidx <= 15;
        32'b???????????????10000000000000000: hitidx <= 16;
        32'b??????????????100000000000000000: hitidx <= 17;
        32'b?????????????1000000000000000000: hitidx <= 18;
        32'b????????????10000000000000000000: hitidx <= 19;
        32'b???????????100000000000000000000: hitidx <= 20;
        32'b??????????1000000000000000000000: hitidx <= 21;
        32'b?????????10000000000000000000000: hitidx <= 22;
        32'b????????100000000000000000000000: hitidx <= 23;
        32'b???????1000000000000000000000000: hitidx <= 24;
        32'b??????10000000000000000000000000: hitidx <= 25;
        32'b?????100000000000000000000000000: hitidx <= 26;
        32'b????1000000000000000000000000000: hitidx <= 27;
        32'b???10000000000000000000000000000: hitidx <= 28;
        32'b??100000000000000000000000000000: hitidx <= 29;
        32'b?1000000000000000000000000000000: hitidx <= 30;
        32'b10000000000000000000000000000000: hitidx <= 31;
        default:                              hitidx <= 0;
    endcase
end
always@(*) begin
	if (va12) begin
	    PFN<=PFN1[hitidx];
		{c,d,v}<=CDV1[hitidx];
	end
	else begin
		PFN<=PFN0[hitidx];
		{c,d,v}<=CDV0[hitidx];
	end
end

assign phy_addr=(i_kseg3 | i_ksseg | i_useg) ? {PFN,valow}: logic_addr;

reg [7:0] LRU [0:31];
reg [4:0] writereg;
reg [4:0] count;
reg [4:0] nextwritereg;
getnextreg(LRU,nextwritereg);

always@(posedge clk) begin
	if (rst) begin
		for (integer i=0;i<31;i++) LRU[i]<=0;
	end
	else begin
		if ((|found) && we) begin
			for (integer i=0;i<31;i++) begin
				if (found[i]) LRU[i]<=0;
				else LRU[i]<=LRU[i]+1;
			end
		end
	end
end
always@(posedge clk) begin
	nextwritereg <= LRU[count] > LRU[nextwritereg]? count:nextwritereg;
	count <= count+1;
end
always@(posedge clk) begin
	if (we) begin
		VPN2 	 [writereg] <= EntryHi[31:13];
		ASID 	 [writereg] <= EntryHi[7:0];
		Pagemask [writereg] <= PageMask[24:13];
		G     	 [writereg] <= EntryLo0[0];
		PFN0     [writereg] <= EntryLo0[25:6];
		CDV0     [writereg] <= EntryLo0[5:1];
		PFN1     [writereg] <= EntryLo1[25:6];
		CDV1     [writereg] <= EntryLo1[5:1];
		writereg<=nextwritereg;
	end
end
assign output_EntryHi = {VPN2[writereg],5'b0,ASID[writereg]};
assign output_PageMask = {7'b0,Pagemask[writereg],13'b0};
assign output_EntryLo0 = {6'b0,PFN0[writereg],CDV0[writereg],G[writereg]};
assign output_EntryLo1 = {6'b0,PFN1[writereg],CDV1[writereg],G[writereg]};
endmodule

