//Experiment 1
module dflipflop(D, Clk, ClearN, Q, QN);
	input D, Clk, ClearN;
	output Q, QN;
	reg data;
	always @ (posedge Clk or negedge ClearN)
	begin
	if(!ClearN)
	data <= 0;
	else
	data <= D;
	end
	assign Q = data;
	assign QN = ~Q;
endmodule


// Experiment 2
module reg_4bit_struct(D, Q, QN, Clk, ClearN);
input [3:0] D;
output [3:0] Q, QN;
input Clk, ClearN;
dflipflop d0 (D[0], Clk, ClearN, Q[0], QN[0]);
dflipflop d1 (D[1], Clk, ClearN, Q[1], QN[1]);
dflipflop d2 (D[2], Clk, ClearN, Q[2], QN[2]);
dflipflop d3 (D[3], Clk, ClearN, Q[3], QN[3]);
endmodule
module tb_reg_4bit;
	// Testbench signals
	reg [3:0] din; // 4-bit data input
	reg Clk; // Clock signal
	reg ClearN; // Active-low asynchronous reset signal
	wire [3:0] dout, doutN; // 4-bit data output
	// Instantiate the Register_4bit module
	// reg_4bit_struct uut (din, dout, doutN, Clk, ClearN);
	reg_4bit_behave uut (din, dout, doutN, Clk, ClearN);
	// Clock generation: 10 time units period
	always #5 Clk = ~Clk;
	// Test sequence
	initial begin
	// Initialize signals
	Clk = 0;
	ClearN = 1;
	din = 4'b0000;
	// Apply asynchronous reset
	ClearN = 0;
	#10;
	ClearN = 1; // Release reset
	#10;
	din = 4'b1010; // Set input data
	#10;
	// Check that dout retains its value
	$display("Time: %0t | dout: %b (expected: 1010)", $time,
	dout);
	din = 8'b1100; // Set new input data
	#10;
	$display("Time: %0t | dout: %b (expected: 1100)", $time,
	dout);
	din = 8'b1111; // Change input data, dout should not change
	#10;
	$display("Time: %0t | dout: %b (expected: 1111)", $time,
	dout);
	// Apply reset again
	ClearN = 0; // Apply asynchronous reset
	#10;
	$display("Time: %0t | dout: %b (expected: 0000)", $time,
	dout);
	ClearN = 1; // Release reset
	#10;
	// Test: Another set of data
	din = 8'b1101; // Load data when enabled
	#10;
	$display("Time: %0t | dout: %b (expected: 1101)", $time,
	dout);
	$stop; // Stop the simulation
	end
endmodule

// Experiment 3
module reg_4bit_struct(D, Q, QN, Clk, ClearN);
	input [3:0] D;
	output [3:0] Q, QN;
	input Clk, ClearN;
	dflipflop d0 (D[0], Clk, ClearN, Q[0], QN[0]);
	dflipflop d1 (D[1], Clk, ClearN, Q[1], QN[1]);
	dflipflop d2 (D[2], Clk, ClearN, Q[2], QN[2]);
	dflipflop d3 (D[3], Clk, ClearN, Q[3], QN[3]);
	endmodule
	module reg_4bit_behave(D, Q, QN, Clk, ClearN);
	input [3:0] D;
	output reg [3:0] Q, QN;
	input Clk, ClearN;
	always @ (posedge Clk or negedge ClearN)
	begin
	if(!ClearN)
	Q <= 0000;
	else
	Q <= D;
	end
	assign QN = ~Q;
endmodule



// Experiment 4
module tb_counter;
// Testbench signals
reg [4:0] in;
reg Clk; // Clock signal
reg start_up, start_down;
wire reset;
wire [4:0] out;
integer i;
mod25count uut (in, out, Clk, start_up, start_down, reset);
// Clock generation: 10 time units period
always #10 Clk = ~Clk;
// Test sequence
initial begin
// Initialize signals
Clk = 0;
in = 5'b0000;
start_up = 1;
start_down = 0;
#10;
for(i = in + 1; i <= 25; i = i + 1) begin
start_up = 0;
$display("Time: %0t | out: %d (expected: %d)", $time,
out, i - 1);
#20;
end
#10;
$stop; // Stop the simulation
end
module mod25count(in, out, clk, start_up, start_down, reset, dir);
input [4:0] in;
input reset;
input clk, start_up, start_down;
output [4:0] out;
output [6:0] dir;
reg [4:0] count;
reg [1:0] direction;
initial direction = 0;
initial count = 0;
always @ (posedge clk or posedge start_up or posedge start_down
or negedge reset)
begin
if(~reset) begin
count <= in;
direction <= 0;
end
else if(start_up) begin
count <= in;
direction <= 2'b01;
end
else if(start_down) begin
count <= in;
direction <= 2'b10;
end
else begin
if (direction == 2'b01) begin
count <= count + 1;
if (count == 24)
direction <= 2'b10;
end
else if (direction == 2'b10) begin
count <= count - 1;
if (count == 1)
direction <= 2'b01;
end
else begin end
end
end
assign out = count;
assign dir = direction;
endmodule