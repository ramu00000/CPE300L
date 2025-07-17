// exp 4
module fsm4(
input clk,
input rstN,
input serial_in,
output reg shift_en,
output reg cntr_rstN,
output reg data_rdy
);
// FSM state encoding
parameter RESET = 2'b00, WAITE = 2'b01, LOAD = 2'b10, READY =
2'b11;
reg [1:0] state, next_state;
reg [2:0] downcount; // 3-bit counter
// FSM State Register
always @(posedge clk or negedge rstN) begin
if (!rstN)
state <= RESET;
else
state <= next_state;
end
// Next-State Logic
always @(*) begin
case (state)
RESET: begin
next_state = WAITE; // Move to WAITE after reset
end
WAITE: begin
if (serial_in == 0)
next_state = LOAD; // Wait for start bit
else
next_state = WAITE;
end
LOAD: begin
if (downcount == 3'b000)
next_state = READY; // After 8 cycles, go to
READY
else
next_state = LOAD;
end
READY: begin
next_state = WAITE; // Back to waiting
end
default: next_state = RESET;
endcase
end
// Downcounter Logic (Controlled by FSM)
always @(posedge clk or negedge rstN) begin
if (!rstN)
downcount <= 3'b111; // Reset counter to 7
else if (state == WAITE)
downcount <= 3'b111; // Reset counter when waiting for
start bit
else if (state == LOAD && downcount > 0)
downcount <= downcount - 1; // Decrement in LOAD state
end
// Output Logic
always @(*) begin
shift_en = 1'b0;
cntr_rstN = 1'b1;
data_rdy = 1'b0;
case (state)
WAITE: begin
shift_en = 1'b0;
cntr_rstN = 1'b0; // Reset counter in WAITE
data_rdy = 1'b0;
end
LOAD: begin
shift_en = 1'b1; // Enable shift while loading
cntr_rstN = 1'b1; // Allow counter decrement
data_rdy = 1'b0;
end
READY: begin
shift_en = 1'b0;
cntr_rstN = 1'b0; // Reset counter in READY
data_rdy = 1'b1; // Data is ready after LOAD
completes
end
endcase
end
endmodule
TB code:
module fsm4_tb;
// Signals
reg clk;
reg rstN;
reg serial_in;
wire shift_en;
wire cntr_rstN;
wire data_rdy;
// Instantiate FSM
fsm4 uut (
.clk(clk),
.rstN(rstN),
.serial_in(serial_in),
.shift_en(shift_en),
.cntr_rstN(cntr_rstN),
.data_rdy(data_rdy)
);
// Clock generation (10ns period, 5ns high, 5ns low)
always #5 clk = ~clk;
initial begin
// Initialize waveform dump (for Modelsim or GTKWave)
$dumpfile("fsm4.vcd");
$dumpvars(0, fsm4_tb);
// 1. Reset the FSM
clk = 0;
rstN = 0;
serial_in = 1; // Default to idle state
#20;
// Release reset
rstN = 1;
#20;
// 2. Apply Start Bit (Move from WAITE → LOAD)
serial_in = 0;
#10; // Hold low for WAITE detection
// 3. FSM should now enter LOAD for 8 cycles
repeat (8) begin
#10; // Wait one clock cycle (10ns)
end
// 4. FSM should now enter READY state
#10;
// 5. Set serial_in = 1 to go back to WAITE
serial_in = 1;
#20;
// Finish simulation
$finish;
end
// Monitor FSM states, outputs, and downcount
initial begin
$monitor("Time = %0t | State = %b | shift_en = %b |
cntr_rstN = %b | data_rdy = %b | downcount = %b",
$time, uut.state, shift_en, cntr_rstN, data_rdy,
uut.downcount);
end
endmodule




// exp 3
module wxyzfsm (
input wire clk_50mhz,
input wire reset,
input wire up_down, // 1 for up, 0 for down
output reg [3:0] count, // 4-bit output
output wire [6:0] HEX0, HEX1 // 7-segment display outputs
);
// Internal signals
wire clk_1hz; // 1Hz clock signal
// Generate 1Hz clock
onehertz clk_divider (
.clk_50mhz(clk_50mhz),
.clk_1hz(clk_1hz)
);
// Define the sequence as a lookup table
reg [3:0] sequence [0:7];
initial begin
sequence[0] = 4'b1000; // 8
sequence[1] = 4'b1100; // 12 (C)
sequence[2] = 4'b0100; // 4
sequence[3] = 4'b0110; // 6
sequence[4] = 4'b0010; // 2
sequence[5] = 4'b0011; // 3
sequence[6] = 4'b0001; // 1
sequence[7] = 4'b1001; // 9
end
// Index to track position in sequence
reg [2:0] index; // 3-bit index (0 to 7)
always @(posedge clk_1hz or posedge reset) begin // Use 1Hz
clock
if (reset) begin
index <= 0; // Reset to first position
end else if (up_down) begin
// Counting UP (wrap around)
index <= (index == 7) ? 0 : index + 1;
end else begin
// Counting DOWN (wrap around)
index <= (index == 0) ? 7 : index - 1;
end
count <= sequence[index]; // Update count after index
change
end
// Instantiate seven-segment display module
sevenseg display_inst (
.counts(count),
.segA(HEX0),
.segB(HEX1)
);
endmodule
module sevenseg (
input [3:0] counts, // 4-bit input
output reg [6:0] segA, // Lower 7-segment display
output reg [6:0] segB // Upper 7-segment display (always
off)
);
always @(*) begin
case(counts)
4'b0000: segA = 7'b1000000; // 0
4'b0001: segA = 7'b1111001; // 1
4'b0010: segA = 7'b0100100; // 2
4'b0011: segA = 7'b0110000; // 3
4'b0100: segA = 7'b0011001; // 4
4'b0110: segA = 7'b0000010; // 6
4'b1000: segA = 7'b0000000; // 8
4'b1001: segA = 7'b0010000; // 9
4'b1100: segA = 7'b1000110; // C (12)
default: segA = 7'b1111111; // Blank
endcase
// Upper 7-segment display (HEX1) remains off
segB = 7'b1111111;
end
endmodule
TB code:
module wxyzfsm_tb;
reg clk_50mhz;
reg reset;
reg up_down;
wire [3:0] count;
// Instantiate the DUT (Device Under Test)
wxyzfsm dut (
.clk_50mhz(clk_50mhz),
.reset(reset),
.up_down(up_down),
.count(count)
);
// Super-fast clock: Toggle every 1ns (Period = 2ns)
always #1 clk_50mhz = ~clk_50mhz;
initial begin
// Initialize signals
clk_50mhz = 0;
reset = 1;
up_down = 1; // Start counting up
#5 reset = 0; // Release reset after 5ns
// Let FSM cycle through states once (8 transitions)
repeat (8) begin
#2; // Move to the next state every 2ns
end
// Flip direction to count down
up_down = 0;
// Let FSM cycle through states in the opposite
direction
repeat (8) begin
#2;
end
// End simulation
$stop;
end
// Monitor FSM outputs
initial begin
$monitor("Time = %0t ns | up_down = %b | count = %b",
$time, up_down, count);
end
endmodule


// exp 2
module fsm2 (
input clk,
input rst,
input x,
output reg z
);
// Define state encoding using parameters
parameter S0 = 3'b000, S1 = 3'b001, S2 = 3'b010,
S3 = 3'b011, S4 = 3'b100, S5 = 3'b101, S6 =
3'b110;
reg [2:0] current_state, next_state;
// State transition logic (combinational)
always @(*) begin
case (current_state)
S0: next_state = (x) ? S2 : S1;
S1: next_state = (x) ? S4 : S3;
S2: next_state = (x) ? S4 : S4;
S3: next_state = (x) ? S5 : S5;
S4: next_state = (x) ? S6 : S5;
S5: next_state = (x) ? S0 : S0;
S6: next_state = (x) ? S6 : S0;
default: next_state = S0;
endcase
end
// State register (sequential logic)
always @(posedge clk or posedge rst) begin
if (rst)
current_state <= S0;
else
current_state <= next_state;
end
// Output logic
always @(*) begin
case (current_state)
S0, S1, S4, S6: z = 1;
S2, S3, S5: z = 0;
default: z = 0;
endcase
end
endmodule
TB:
module fsm2_tb;
reg clk, rst, x;
wire z;
// Instantiate FSM module
fsm2 dut (
.clk(clk),
.rst(rst),
.x(x),
.z(z)
);
// Clock generation
always #5 clk = ~clk; // 10ns period (toggle every 5ns)
// Stimulus process
initial begin
// Initialize signals
clk = 0;
rst = 1;
x = 0;
// Apply reset
#10 rst = 0;
// Apply test inputs
#10 x = 1;
#10 x = 1;
#10 x = 0;
#10 x = 0;
#10 x = 1;
#10 x = 0;
#10 x = 0;
#10 x = 1;
#10 x = 1;
#10 x = 0;
// Introduce a random sequence
repeat (10) begin
#10 x = $random % 2;
end
// End simulation
#50;
$stop;
end
// Monitor outputs
initial begin
$monitor("Time = %0t | State = %b | x = %b | z = %b",
$time, dut.current_state, x, z);
end
endmodule

//exp 1
module lock_fsm (
input clk, reset, digit1, digit2, digit3, digit4,
output reg match1, match2, match3, match4,
output reg [8:0] unlock_indicator,
output reg [6:0] hex_unlock, hex_lock
);
reg [3:0] data;
// State encoding using `parameter`
parameter S0 = 3'b000, // Initial locked state
S1 = 3'b001, // First digit correct
S2 = 3'b010, // Second digit correct
S3 = 3'b011, // Third digit correct
S4 = 3'b100, // Fourth digit correct
S5 = 3'b101; // Unlocked state
reg [2:0] state, nextstate;
// State register (Sequential logic)
always @(posedge clk or posedge reset) begin
if (reset)
state <= S0;
else
state <= nextstate;
end
// Next state logic (Combinational logic)
always @(*) begin
case (state)
S0: if (digit1 & ~digit2 & ~digit3 & ~digit4)
nextstate = S1;
else
nextstate = S0;
S1: if (digit3 & ~digit1 & ~digit2 & ~digit4)
nextstate = S2;
else
nextstate = S0;
S2: if (digit4 & ~digit1 & ~digit2 & ~digit3)
nextstate = S3;
else
nextstate = S0;
S3: if (digit2 & ~digit1 & ~digit3 & ~digit4)
nextstate = S4;
else
nextstate = S0;
S4: if (digit1 & ~digit2 & ~digit3 & ~digit4)
nextstate = S5;
else
nextstate = S0;
S5: if (digit1 || digit2 || digit3 || digit4)
nextstate = S0;
else
nextstate = S0;
default: nextstate = S0;
endcase
end
// Output logic (Combinational logic)
always @(*) begin
match1 = (state == S0 || state == S4);
match2 = (state == S3);
match3 = (state == S1);
match4 = (state == S2);
data = (state == S5);
end
// 7-Segment Display Logic for `hex_unlock`
always @(*) begin
case (data)
0: hex_unlock = 7'b1111111; // Display nothing
1: hex_unlock = 7'b1000001; // 'U' for Unlocked
default: hex_unlock = 7'b1111111;
endcase
end
// 7-Segment Display Logic for `hex_lock`
always @(*) begin
case (state)
S0, S1, S2, S3, S4: hex_lock = 7'b1000111; // 'L' for
Locked
S5: hex_lock = 7'b1111111; // Clear display when
unlocked
default: hex_lock = 7'b1111111;
endcase
end
endmodule