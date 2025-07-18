module maindec (input [5:0] op, output memtoreg, memwrite, output branch, alusrc,
output regdst, regwrite, output jump, output jal, output [1:0] aluop);
reg [8:0] controls;
assign {regwrite, regdst, alusrc, branch, memwrite, memtoreg, jump, aluop}  = controls;
// new jal controls
assign jal = controls[8] & controls[2];
always @ (* )
 case(op)
6'b000000 :  controls <= 9'b110000010; 		//Rtyp
6'b100011 :  controls <= 9'b101001000; 		//LW
6'b101011 :  controls <= 9'b001010000; 		//SW
6'b000100 :  controls <= 9'b000100001; 		//BEQ
6'b001000 :  controls <= 9'b101000000; 		//ADDI
6'b000010 :  controls <= 9'b000000100; 		//J
6'b000011 :  controls <= 9'b100000100;		//new JAL opcode

default:  controls <= 9'bXXXXXXXXX; 		//???
endcase
endmodule



