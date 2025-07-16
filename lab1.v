// Exp 1
// a. continuous assign
module mux21a (a, b, sel, out, outbar);
input a, b, sel;
output out, outbar;
assign out = ~sel&a | sel&b;
assign outbar = ~out;
endmodule


// b. conditional operator
module mux21b (input logic a, b, sel,
output logic out, outbar);
assign out = sel ? b:a;
assign outbar = ~out;
endmodule


//c 8-bit 2-to-1 Mux with implementation on DE2

module mux21c_wrapper (input logic [17:0] SW,
output logic [6:0] HEX0, HEX1, HEX4,
HEX5, HEX6, HEX7);
logic [7:0] mux_out;
mux21c dut (SW[7:0], SW[15:8], SW[17], mux_out);
sevenseg h0 (mux_out[3:0], HEX0);
sevenseg h1 (mux_out[7:4], HEX1);
sevenseg h4 (SW[3:0], HEX4);
sevenseg h5 (SW[7:4], HEX5);
sevenseg h6 (SW[11:8], HEX6);
sevenseg h7 (SW[15:12], HEX7);
endmodule
module sevenseg(input logic [3:0] data,
output logic [6:0] segments);
always_comb
case(data)
0: segments = 7'h40;
1: segments = 7'h79;
2: segments = 7'h24;
3: segments = 7'h30;
4: segments = 7'h19;
5: segments = 7'h12;
6: segments = 7'h02;
7: segments = 7'h78;
8: segments = 7'h00;
9: segments = 7'h18;
4'hA: segments = 7'h08;
4'hB: segments = 7'h03;
4'hC: segments = 7'h27;
4'hD: segments = 7'h21;
4'hE: segments = 7'h06;
4'hF: segments = 7'h0E;
default: segments = 7'hFF;
endcase
endmodule
module mux21c (input logic [7:0] a, b,
input logic sel,
output logic [7:0] out, outbar);
assign out = sel ? b:a;
assign outbar = ~out;
endmodule



// Exp 2
module tb_adder();
reg [3:0] a, b;
reg ci;
wire [3:0] s;
wire co;
rca dut (a, b, ci, co, s);
initial begin
a = 0; b = 0; ci = 0; #5;
a = 4'h2; b = 4'h2; ci = 1; #5;
a = 4'h5; b = 4'h5; ci = 0; #5;
a = 4'hf; b = 4'hf; ci = 0; #5;
a = 4'hf; b = 4'h2; ci = 1; #5;
end
endmodule
module rca (a, b, ci, co, s);
input [3:0] a, b;
input ci;
output [3:0] s;
output co;
wire co0, co1, co2;
fa a0 (a[0], b[0], ci, co0, s[0]);
fa a1 (a[1], b[1], co0, co1, s[1]);
fa a2 (a[2], b[2], co1, co2, s[2]);
fa a3 (a[3], b[3], co2, co, s[3]);
endmodule
module fa (a,b,ci,co,s);
input a,b,ci;
output co,s;
assign s = a^b^ci;
assign co = a&b | ci&(a^b);
endmodule



// exp 3

module alu_wrapper(input logic [17:0] SW,
output logic [6:0] HEX0,
output logic [6:0] HEX2,
output logic [6:0] HEX3,
output logic [6:0] HEX4,
output logic LEDR[0]); // carry out
bit
logic [3:0] alu_out;
ALU dut(alu_out, SW[3:0],SW[7:4],LEDR[0],SW[8],SW[17:15]);
sevenseg ss0(alu_out, HEX0);
sevenseg ss1(SW[3:0], HEX2);
sevenseg ss2(SW[7:4], HEX3);
sevenseg ss3(SW[17:15], HEX4);
endmodule
module sevenseg(input logic [3:0] data,
output logic [6:0] segments);
always_comb
case(data)
0: segments = 7'h40;
1: segments = 7'h79;
2: segments = 7'h24;
3: segments = 7'h30;
4: segments = 7'h19;
5: segments = 7'h12;
6: segments = 7'h02;
7: segments = 7'h78;
8: segments = 7'h00;
9: segments = 7'h18;
4'hA: segments = 7'h08;
4'hB: segments = 7'h03;
4'hC: segments = 7'h27;
4'hD: segments = 7'h21;
4'hE: segments = 7'h06;
4'hF: segments = 7'h0E;
default: segments = 7'hFF;
endcase
endmodule
module ALU (
output reg [3:0] out,
input logic [3:0] a,b,
output logic cout,
input logic cin,
input logic [2:0] sel );
always @ (*)
begin
case(sel)
3'b000: begin
out = a + 1;
cout = (a == 4'b1111);
end
3'b001: begin
out = a - 1;
cout = (a == 4'b0000);
end
3'b010: begin
out = {a[0],a[3:1]};
cout = 0;
end
3'b011: begin
out = a >> 1;
cout = 0;
end
3'b100: begin
out = a&b;
end
3'b101: begin
out = a|b;
end
3'b110: begin
out = a+b+cin;
cout = (a+b+cin > 4'b1111);
end
3'b111: begin
out = a-b-cin;
cout = (b+cin > a);
end
endcase
end
endmodule