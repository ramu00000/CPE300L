//------------------------------------------------
// adder.v
//------------------------------------------------
module adder(
  input  [31:0] a,
  input  [31:0] b,
  output [31:0] y
);
  // Simple adder: same functionality.
  assign y = a + b;
endmodule

//------------------------------------------------
// alu.v
//------------------------------------------------
module alu(
  input  [31:0] a,
  input  [31:0] b,
  input  [2:0]  op,      // ALU control signal
  output [31:0] result, // ALU output
  output        zero    // Zero flag output
);

  // Use a function to compute the ALU result.
  function [31:0] calc;
    input [31:0] a_in;
    input [31:0] b_in;
    input [2:0]  op_in;
    begin
      case(op_in)
        3'b000: calc = a_in & b_in;       // AND
        3'b001: calc = a_in | b_in;       // OR
        3'b010: calc = a_in + b_in;       // ADD
        3'b110: calc = a_in - b_in;       // SUB
        3'b111: begin                    // SLT
                  if(a_in[31] != b_in[31])
                    calc = (a_in[31]) ? 32'd1 : 32'd0;
                  else
                    calc = (a_in < b_in) ? 32'd1 : 32'd0;
                end
        default: calc = 32'd0;
      endcase
    end
  endfunction

  // Compute the ALU result and zero flag.
  assign result = calc(a, b, op);
  assign zero   = (result == 32'd0);
  
endmodule

//------------------------------------------------
// aludec.v
//------------------------------------------------
module aludec(
  input  [5:0] funct,
  input  [1:0] aluop,
  output reg [2:0] alucontrol
);
  // Use if–else to choose the ALU control signal.
  always @(*) begin
    if (aluop == 2'b00)
      alucontrol = 3'b010;         // add
    else if (aluop == 2'b01)
      alucontrol = 3'b110;         // sub
    else begin                     // R-type instruction
      if      (funct == 6'b100000) alucontrol = 3'b010; // add
      else if (funct == 6'b100010) alucontrol = 3'b110; // sub
      else if (funct == 6'b100100) alucontrol = 3'b000; // and
      else if (funct == 6'b100101) alucontrol = 3'b001; // or
      else if (funct == 6'b101010) alucontrol = 3'b111; // slt
      else                        alucontrol = 3'bxxx; // undefined
    end
  end
endmodule

//------------------------------------------------
// controller.v
//------------------------------------------------
module controller(
  input        clk,
  input        reset,
  input  [5:0] op, funct,
  input        zero,
  output       iord, memwrite, irwrite, regdst,
  output       memtoreg, regwrite, alusrca,
  output [1:0] alusrcb,
  output [2:0] alucontrol,
  output [1:0] pcsrc,
  output       pcen
);
  wire [1:0] aluop;
  wire       branch, pcwrite;

  // Instantiate main decoder and ALU decoder.
  maindec mdec(
    .clk(clk),
    .reset(reset),
    .op(op),
    .memtoreg(memtoreg),
    .memwrite(memwrite),
    .pcsrc(pcsrc),
    .pcwrite(pcwrite),
    .regdst(regdst),
    .regwrite(regwrite),
    .iord(iord),
    .irwrite(irwrite),
    .branch(branch),
    .alusrca(alusrca),
    .alusrcb(alusrcb),
    .aluop(aluop)
  );
  
  aludec adec(
    .funct(funct),
    .aluop(aluop),
    .alucontrol(alucontrol)
  );
  
  // PC enable: update when pcwrite is set or branch is taken and zero is true.
  assign pcen = pcwrite | (branch & zero);
endmodule

//------------------------------------------------
// datapath.v
//------------------------------------------------
module datapath(
  input         clk,
  input         reset,
  input         pcen,
  input         iord,
  input         irwrite,
  input         regdst,
  input         memtoreg,
  input         regwrite,
  input         alusrca,
  input  [1:0]  alusrcb,
  input  [2:0]  alucontrol,
  input  [1:0]  pcsrc,
  input  [31:0] readdata,
  output [5:0]  op, funct,
  output        zero,
  output [31:0] adr,
  output [31:0] writedata
);
  // Internal wires.
  wire [31:0] pc, pc_next;
  wire [31:0] instr, data, alu_out;
  wire [4:0]  writereg;
  wire [31:0] wd3, rd1, rd2, regA, srcA, srcB;
  wire [31:0] sign_ext, shift_out, jump_addr, alu_result;
  
  // Extract opcode and function fields.
  assign op    = instr[31:26];
  assign funct = instr[5:0];
  assign jump_addr = {pc[31:28], instr[25:0], 2'b00};
  
  // Program Counter register.
  flopr #(32) pc_reg(
    .clk(clk),
    .reset(reset),
    .enable(pcen),
    .d(pc_next),
    .q(pc)
  );
  
  // Memory address selection: PC or ALU output.
  mux2 #(32) addr_sel(
    .d0(pc),
    .d1(alu_out),
    .s(iord),
    .y(adr)
  );
  
  // Instruction register and data register.
  flopr #(32) instr_reg(
    .clk(clk),
    .reset(reset),
    .enable(irwrite),
    .d(readdata),
    .q(instr)
  );
  flopr #(32) data_reg(
    .clk(clk),
    .reset(reset),
    .enable(1'b1),
    .d(readdata),
    .q(data)
  );
  
  // Register destination multiplexer.
  mux2 #(5) reg_dest(
    .d0(instr[20:16]),
    .d1(instr[15:11]),
    .s(regdst),
    .y(writereg)
  );
  
  // Write-back data multiplexer.
  mux2 #(32) wb_mux(
    .d0(alu_out),
    .d1(data),
    .s(memtoreg),
    .y(wd3)
  );
  
  // Register file instantiation.
  regfile RF(
    .clk(clk),
    .we3(regwrite),
    .ra1(instr[25:21]),
    .ra2(instr[20:16]),
    .wa3(writereg),
    .wd3(wd3),
    .rd1(rd1),
    .rd2(rd2)
  );
  
  // Latching the register outputs.
  flopr #(32) regA_latch(
    .clk(clk),
    .reset(reset),
    .enable(1'b1),
    .d(rd1),
    .q(regA)
  );
  flopr #(32) regB_latch(
    .clk(clk),
    .reset(reset),
    .enable(1'b1),
    .d(rd2),
    .q(writedata)
  );
  
  // Source A multiplexer: choose between PC and regA.
  mux2 #(32) srcA_sel(
    .d0(pc),
    .d1(regA),
    .s(alusrca),
    .y(srcA)
  );
  
  // Sign extension and shift left for branch target.
  signext SE(
    .a(instr[15:0]),
    .y(sign_ext)
  );
  sl2 SL(
    .a(sign_ext),
    .y(shift_out)
  );
  
  // Source B multiplexer: select between regB, constant 4, sign-extended immediate, or shifted immediate.
  mux4 #(32) srcB_sel(
    .d0(writedata),
    .d1(32'd4),
    .d2(sign_ext),
    .d3(shift_out),
    .select(alusrcb),
    .result(srcB)
  );
  
  // ALU instantiation.
  alu ALU_INST(
    .a(srcA),
    .b(srcB),
    .op(alucontrol),
    .result(alu_result),
    .zero(zero)
  );
  
  // Latch ALU result.
  flopr #(32) alu_reg(
    .clk(clk),
    .reset(reset),
    .enable(1'b1),
    .d(alu_result),
    .q(alu_out)
  );
  
  // PC selection multiplexer.
  mux3 #(32) pc_sel(
    .d0(alu_result),
    .d1(alu_out),
    .d2(jump_addr),
    .select(pcsrc),
    .result(pc_next)
  );
  
endmodule

//------------------------------------------------
// flopr.v
//------------------------------------------------
module flopr #(parameter WIDTH = 8)(
  input               clk,
  input               reset,
  input               enable,
  input  [WIDTH-1:0]  d,
  output reg [WIDTH-1:0] q
);
  always @(posedge clk or posedge reset) begin
    if (reset)
      q <= {WIDTH{1'b0}};
    else if (enable)
      q <= d;
  end
endmodule

//------------------------------------------------
// maindec.v
//------------------------------------------------
module maindec(
  input         clk,
  input         reset,
  input  [5:0]  op,
  output        memtoreg,
  output        memwrite,
  output [1:0]  pcsrc,
  output        pcwrite,
  output        regdst,
  output        regwrite,
  output        iord,
  output        irwrite,
  output        branch,
  output        alusrca,
  output [1:0]  alusrcb,
  output [1:0]  aluop
);
  // State definitions using parameters.
  parameter S0  = 0,  // Fetch
            S1  = 1,  // Decode
            S2  = 2,  // MemAdr
            S3  = 3,  // MemRead
            S4  = 4,  // MemWriteBack
            S5  = 5,  // MemWrite
            S6  = 6,  // Execute
            S7  = 7,  // ALUWriteback
            S8  = 8,  // Branch
            S9  = 9,  // ADDIExecute
            S10 = 10, // ADDIWriteback
            S11 = 11; // Jump
  
  // Opcode definitions.
  localparam [5:0] OPLW    = 6'b100011,
                   OPSW    = 6'b101011,
                   OPRTYPE = 6'b000000,
                   OPBEQ   = 6'b000100,
                   OPADDI  = 6'b001000,
                   OPJ     = 6'b000010;
  
  reg [3:0] current_state, next_state;
  reg [14:0] controls;
  
  // Unpack the control bundle.
  assign {pcwrite, memwrite, irwrite, regwrite, 
          alusrca, branch, iord, memtoreg, 
          regdst, alusrcb, pcsrc, aluop} = controls;
  
  // State update using if–else style.
  always @(posedge clk or posedge reset) begin
    if (reset)
      current_state <= S0;
    else
      current_state <= next_state;
  end
  
  // Next-state logic (if–else instead of pure case).
  always @(*) begin
    if (current_state == S0)
      next_state = S1;
    else if (current_state == S1) begin
      if (op == OPLW || op == OPSW)
        next_state = S2;
      else if (op == OPRTYPE)
        next_state = S6;
      else if (op == OPBEQ)
        next_state = S8;
      else if (op == OPADDI)
        next_state = S9;
      else if (op == OPJ)
        next_state = S11;
      else
        next_state = S0;
    end
    else if (current_state == S2)
      next_state = (op == OPLW) ? S3 : S5;
    else if (current_state == S3)
      next_state = S4;
    else if (current_state == S4)
      next_state = S0;
    else if (current_state == S5)
      next_state = S0;
    else if (current_state == S6)
      next_state = S7;
    else if (current_state == S7)
      next_state = S0;
    else if (current_state == S8)
      next_state = S0;
    else if (current_state == S9)
      next_state = S10;
    else if (current_state == S10)
      next_state = S0;
    else if (current_state == S11)
      next_state = S0;
    else
      next_state = S0;
  end
  
  // Output control signal logic using if–else.
  always @(*) begin
    if (current_state == S0)
      controls = 15'b101_0000_0001_0000;
    else if (current_state == S1)
      controls = 15'b000_0000_0011_0000;
    else if (current_state == S2)
      controls = 15'b000_0100_0010_0000;
    else if (current_state == S3)
      controls = 15'b000_0001_0000_0000;
    else if (current_state == S4)
      controls = 15'b000_1000_1000_0000;
    else if (current_state == S5)
      controls = 15'b010_0001_0000_0000;
    else if (current_state == S6)
      controls = 15'b000_0100_0000_0010;
    else if (current_state == S7)
      controls = 15'b000_1000_0100_0000;
    else if (current_state == S8)
      controls = 15'b000_0110_0000_0101;
    else if (current_state == S9)
      controls = 15'b000_0100_0010_0000;
    else if (current_state == S10)
      controls = 15'b000_1000_0000_0000;
    else if (current_state == S11)
      controls = 15'b100_0000_0000_1000;
    else
      controls = 15'b0;
  end
endmodule

//------------------------------------------------
// mem.v
//------------------------------------------------
module mem(
  input         clk,
  input         reset,
  input         memwrite,
  input  [31:0] adr,
  input  [31:0] writedata,
  output [31:0] readdata
);
  reg [31:0] RAM[63:0];
  
  initial begin
    $readmemh("memfile.dat", RAM);
  end
  
  assign readdata = RAM[adr[31:2]];
  
  always @(posedge clk) begin
    if (memwrite)
      RAM[adr[31:2]] <= writedata;
  end
endmodule

//------------------------------------------------
// mips.v
//------------------------------------------------
module mips(
  input         clk,
  input         reset,
  input  [31:0] readdata,
  output [31:0] adr,
  output [31:0] writedata,
  output        memwrite
);
  wire zero, pcen, irwrite, regwrite, alusrca, iord, memtoreg, regdst;
  wire [1:0] alusrcb, pcsrc;
  wire [2:0] alucontrol;
  wire [5:0] op, funct;
  
  controller ctrl(
    .clk(clk),
    .reset(reset),
    .op(op),
    .funct(funct),
    .zero(zero),
    .iord(iord),
    .memwrite(memwrite),
    .irwrite(irwrite),
    .regdst(regdst),
    .memtoreg(memtoreg),
    .regwrite(regwrite),
    .alusrca(alusrca),
    .alusrcb(alusrcb),
    .alucontrol(alucontrol),
    .pcsrc(pcsrc),
    .pcen(pcen)
  );
  
  datapath dp(
    .clk(clk),
    .reset(reset),
    .pcen(pcen),
    .iord(iord),
    .irwrite(irwrite),
    .regdst(regdst),
    .memtoreg(memtoreg),
    .regwrite(regwrite),
    .alusrca(alusrca),
    .alusrcb(alusrcb),
    .alucontrol(alucontrol),
    .pcsrc(pcsrc),
    .readdata(readdata),
    .op(op),
    .funct(funct),
    .zero(zero),
    .adr(adr),
    .writedata(writedata)
  );
endmodule

//------------------------------------------------
// mux2.v
//------------------------------------------------
module mux2 #(parameter WIDTH = 8)(
  input  [WIDTH-1:0] d0,
  input  [WIDTH-1:0] d1,
  input              s,
  output [WIDTH-1:0] y
);
  assign y = s ? d1 : d0;
endmodule

//------------------------------------------------
// mux3.v
//------------------------------------------------
module mux3 #(parameter WIDTH = 8)(
  input  [WIDTH-1:0] d0,
  input  [WIDTH-1:0] d1,
  input  [WIDTH-1:0] d2,
  input  [1:0]       select,
  output [WIDTH-1:0] result
);
  assign result = (select == 2'b00) ? d0 :
                  (select == 2'b01) ? d1 :
                  (select == 2'b10) ? d2 : d0;
endmodule

//------------------------------------------------
// mux4.v
//------------------------------------------------
module mux4 #(parameter WIDTH = 8)(
  input  [WIDTH-1:0] d0,
  input  [WIDTH-1:0] d1,
  input  [WIDTH-1:0] d2,
  input  [WIDTH-1:0] d3,
  input  [1:0]       select,
  output [WIDTH-1:0] result
);
  assign result = (select == 2'b00) ? d0 :
                  (select == 2'b01) ? d1 :
                  (select == 2'b10) ? d2 :
                  (select == 2'b11) ? d3 : {WIDTH{1'b0}};
endmodule

//------------------------------------------------
// regfile.v
//------------------------------------------------
module regfile(
  input         clk,
  input         we3,
  input  [4:0]  ra1,
  input  [4:0]  ra2,
  input  [4:0]  wa3,
  input  [31:0] wd3,
  output [31:0] rd1,
  output [31:0] rd2
);
  reg [31:0] rf[31:0];
  
  // Register write on rising edge.
  always @(posedge clk)
    if (we3)
      rf[wa3] <= wd3;
      
  // Continuous reads (with register 0 hardwired to 0).
  assign rd1 = (ra1 != 0) ? rf[ra1] : 32'd0;
  assign rd2 = (ra2 != 0) ? rf[ra2] : 32'd0;
endmodule

//------------------------------------------------
// signext.v
//------------------------------------------------
module signext(
  input  [15:0] a,
  output [31:0] y
);
  assign y = {{16{a[15]}}, a};
endmodule

//------------------------------------------------
// sl2.v
//------------------------------------------------
module sl2(
  input  [31:0] a,
  output [31:0] y
);
  // Shift left by 2 bits.
  assign y = {a[25:0], 2'b00};
endmodule

//------------------------------------------------
// testbench.v
//------------------------------------------------
module testbench();
  reg clk;
  reg reset;
  wire [31:0] writedata, dataadr;
  wire memwrite;
  
  // Instantiate top-level design.
  top DUT(
    .clk(clk),
    .reset(reset),
    .writedata(writedata),
    .adr(dataadr),
    .memwrite(memwrite)
  );
  
  // Generate reset.
  initial begin
    reset = 1;
    #22;
    reset = 0;
  end
  
  // Clock generation (10 time units period).
  always begin
    clk = 1; #5;
    clk = 0; #5;
  end
  
  // Monitor memory writes.
  always @(negedge clk) begin
    if (memwrite) begin
      if (dataadr === 84 && writedata === 7) begin
        $display("Simulation succeeded");
        #5 $stop;
      end else if (dataadr !== 80) begin
        $display("Simulation failed");
        $stop;
      end
    end
  end
endmodule

//------------------------------------------------
// top.v
//------------------------------------------------
module top(
  input         clk,
  input         reset,
  output [31:0] writedata,
  output [31:0] adr,
  output        memwrite
);
  wire [31:0] readdata;
  
  // Instantiate processor and memory.
  mips PROC(
    .clk(clk),
    .reset(reset),
    .readdata(readdata),
    .adr(adr),
    .writedata(writedata),
    .memwrite(memwrite)
  );
  
  mem MEMORY(
    .clk(clk),
    .reset(reset),
    .memwrite(memwrite),
    .adr(adr),
    .writedata(writedata),
    .readdata(readdata)
  );
endmodule
