// top module
module GDP(Sum, start, restart, clk, n1, n2, done, state_out);

	input start, clk, restart;
	input [7:0] n1, n2;
	output [7:0] Sum;
	output [2:0] state_out;
	output done;

	wire WE, RAE, RBE, OE, nEqZero, aeqb, agtb, bgta;
	wire [1:0] WA, RAA, RBA, SH, IE;
	wire [2:0] ALU;
	wire [2:0] state;

	CU control (IE, WE, WA, RAE, RAA, RBE, RBA, ALU, SH, OE, ~start, clk, ~restart, nEqZero, aeqb, agtb, bgta, state);

	DP datapath (nEqZero, aeqb, agtb, bgta, Sum, n1, n2, clk, IE, WE, WA, RAE, RAA, RBE, RBA, ALU, SH, OE);

	assign done=OE;
	assign state_out = state;


endmodule


// Control Unit

module CU (IE, WE, WA, RAE, RAA, RBE, RBA, ALU, SH, OE, start, clk, restart, nEqZero, aeqb, agtb, bgta, s_out);
	input start, clk, restart;
	output WE, RAE, RBE, OE;
	output [1:0] WA, RAA, RBA, SH, IE;
	output [2:0] ALU;
	output [2:0] s_out;
	
	input wire nEqZero, aeqb, agtb, bgta;
	reg [2:0] state;
	reg [2:0] nextstate;
	
	parameter S0 = 3'b000;
	parameter S1 = 3'b001;
	parameter S2 = 3'b010;
	parameter S3 = 3'b011;
	parameter S4 = 3'b100;
	parameter S5 = 3'b101;
	parameter S6 = 3'b110;
	
	initial begin
		state = S0;
	end
	
	// state register
	always @ (posedge clk)
	begin
		state <= nextstate;
	end
	
	always @ (*) begin
		case (state)
			S0: if (start) nextstate = S1;
				else	    nextstate = S0;
			S1: nextstate = S5;
			S2: nextstate = S5;
			S3: nextstate = S5;
			S4: if (restart) nextstate=S0;			
				else nextstate = S4;
			S5: if (aeqb) nextstate = S4;
				else if (agtb) nextstate = S2;
				else nextstate = S3;
			default: nextstate = S0;
		endcase	
	end
	
	// output logic
	assign IE[1] = (state==S1);
	assign IE[0] = (state==S0);
	assign WE = ~ (state==S4);
	assign WA[1] = 0;
	assign WA[0] = (state==S1 || state==S3);
	
	assign RAE = ~(state == S0);
	assign RAA[1] = 0;
	assign RAA[0] = state==S3;
	
	assign RBE = (state==S3 || state==S2 || state==S5);
	assign RBA[1] = 0;
	assign RBA[0] = (state==S1 || state== S2 || state==S5);
	
	assign ALU[2] = (state==S2 || state==S3);
	assign ALU[1] = 0;
	assign ALU[0] = (state==S2 || state==S3);
	
	assign SH[1] = 0;
	assign SH[0] = 0;
	assign OE = state==S4;
	
	assign s_out = state;

endmodule


module DP (nEqZero, aeqb, agtb, bgta, sum, nIn1, nIn2, clk, IE, WE, WA, RAE, RAA, RBE, RBA, ALU, SH, OE);

	input clk, WE, RAE, RBE, OE;
	input [1:0] IE;
	input [1:0] WA, RAA, RBA, SH;
	input [2:0] ALU;
	input [7:0] nIn1, nIn2;
	
	output nEqZero, aeqb, agtb, bgta;
	output wire [7:0] sum;
	
	reg [7:0] rfIn;
	wire [7:0] RFa, RFb, aluOut, shOut, n;
	
	initial begin
		rfIn = 0;
	end
	
	always @ (*)
		rfIn = 0;
		
	mux8 muxs (n, shOut, nIn1, nIn2, IE);
	Regfile RF (clk, RAA, RFa, RBA, RFb, WE, WA, rfIn, RAE, RBE);
	alu theALU (aluOut, RFa, RFb, ALU);
	shifter SHIFT (shOut, aluOut, SH);
	buff buffer1 (sum, shOut, OE);
	
	assign nEqZero = n==0;
	assign aeqb = (RFa == RFb);
	assign agtb = (RFa > RFb);
	assign bgta = (RFb > RFa);

endmodule

module alu(out, a, b, sel);
	input [7:0] a, b;
	input [2:0] sel;
	output [7:0] out;
	reg [7:0] out;
	
	always @ (*)
	begin 
		case (sel)
			3'b000: out = a;
			3'b001: out = a&b;
			3'b010: out = a|b;
			3'b011: out = !a;
			3'b100: out = a+b;
			3'b101: out = a-b;
			3'b110: out = a+1;
			3'b111: out = a-1;
		endcase
	end
endmodule

// buffre

module buff(output reg[7:0] result, input[7:0] a, input buf1);
	always @(*)
		if (buf1==1)
			result = a;
		else
			result=8'bzzzz_zzzz;
endmodule

// mux 3-1
module mux8(result, a,b,c, sel);
	output reg[7:0] result;
	input [7:0] a, b, c;
	input [1:0] sel;
	
	always @(*)
		if (sel==3'b00)
			result = a;
		else if (sel==3'b01)
			result = b;
		else	
			result = c;
			
endmodule
			

//Regfile

module Regfile(clk, RAA, ReadA, RBA, ReadB, WE, WA, INPUT_D, RAE, RBE);
	input clk,WE, RAE, RBE;
	input [1:0] RAA, RBA, WA;
	input[7:0] INPUT_D;
	output[7:0] ReadA, ReadB;
	
	reg[7:0] REG_F[0:3];  // width 8, depth 4
	
	
	//write only when we=1
	
	always @ (posedge clk) begin
		if (WE==1) REG_F[WA] <= INPUT_D;
	end

	assign ReadA = (RAE)?REG_F[RAA] : 0;
	assign ReadB = (RBE)? REG_F[RBA] : 0;
	

endmodule


// SHIFT
module shifter(out, a, sh);
	input [7:0] a;
	input [1:0] sh;
	output reg [7:0] out;
	
	always @ (*) 
	begin
		case(sh)
			3'b00: out = a;
			3'b01: out = a << 1;
			3'b10: out = a >> 1;
			3'b11: out = {a[6],a[5],a[4],a[3],a[2],a[1],a[0],a[7]};
		endcase
	end
endmodule




//single port ram

module single_port_ram (
		input wire clk,
		input wire WE,
		input wire [3:0] Addr,
		input wire [7:0] Inp, //input data
		output wire [7:0] opd //op data
	);
	
	reg [7:0] mem [0:15];
	
	integer i;
	initial begin 
		for (i=0; i<16; i = i+1)
			mem[i] = 8'b00000000;
	end
	
	always @ (posedge clk) begin
		if (WE)
			mem[Addr] <= Inp;
	end
	
	assign opd = mem[Addr]; //continuous ReadA

endmodule