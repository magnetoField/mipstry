/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none


module tt_um_magnetofield_mips (
    input  wire [7:0] ui_in,     // 8-bit external IMEM data input
    output wire [7:0] uo_out,    // 8-bit external IMEM addr output (serialized)
    input  wire [7:0] uio_in,    // general-purpose input (unused)
    output wire [7:0] uio_out,   // general-purpose output (unused)
    output wire [7:0] uio_oe,    // direction (unused)
    input  wire       ena,       // design enable (ignore for core)
    input  wire       clk,       // main clock
    input  wire       rst_n      // async active-low reset
);
    assign uio_out = 0;
    assign uio_oe  = 0;

  // List all unused inputs to prevent warnings
    wire _unused = &{ena, clk, rst_n, 1'b0};
    // -----------------------------------------------------------
    // Internal wires between top and MIPS core
    // -----------------------------------------------------------
    wire [31:0] imem_addr;
    wire [31:0] imem_data;

    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;
    wire [31:0] dmem_rdata = 32'b0;   // DMEM not yet implemented externally
    wire        dmem_we;

    // -----------------------------------------------------------
    // FSM for 4-byte IMEM address serialization + data load
    // -----------------------------------------------------------
    reg [1:0] fetch_state;       // 0..3
    reg [31:0] imem_data_reg;    // 32-bit instruction buffer

    // Serialize 32-bit address onto 8 output pins
    reg [7:0] addr_byte;

    always @(*) begin
        case (fetch_state)
            2'd0: addr_byte = imem_addr[7:0];
            2'd1: addr_byte = imem_addr[15:8];
            2'd2: addr_byte = imem_addr[23:16];
            2'd3: addr_byte = imem_addr[31:24];
        endcase
    end

    assign uo_out = addr_byte;

    // -----------------------------------------------------------
    // 4-phase instruction fetch FSM
    // -----------------------------------------------------------
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
            fetch_state    <= 0;
            imem_data_reg  <= 32'h00000000;
        end
        else begin
            case (fetch_state)
                2'd0: begin
                    // output addr[7:0], wait for next byte
                    fetch_state <= 2'd1;
                end

                2'd1: begin
                    imem_data_reg[7:0] <= ui_in;
                    fetch_state <= 2'd2;
                end

                2'd2: begin
                    imem_data_reg[15:8] <= ui_in;
                    fetch_state <= 2'd3;
                end

                2'd3: begin
                    imem_data_reg[23:16] <= ui_in;
                    // instruction complete on next cycle
                    imem_data_reg[31:24] <= ui_in;
                    fetch_state <= 2'd0;
                end
            endcase
        end
    end

    assign imem_data = imem_data_reg;

    // -----------------------------------------------------------
    // Instantiate the CPU core
    // -----------------------------------------------------------

    mips xmips_inst (
        .clk        (clk),
		.rst      (!rst_n),
        .imem_addr  (imem_addr),
        .imem_data  (imem_data),
        .dmem_addr  (dmem_addr),
        .dmem_rdata (dmem_rdata),
        .dmem_wdata (dmem_wdata),
        .dmem_we    (dmem_we)
    );

    dmem xdmem_inst ( 
	 .clk( clk ),
	 .we( dmem_we ),
	 .rdata( dmem_rdata ),
	 .addr( dmem_addr ),
	 .wdata( dmem_wdata )
    );

    // -----------------------------------------------------------
    // Keep GPIO unused (future DMEM/I/O expansion)
    // -----------------------------------------------------------
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

endmodule



// expanding   symbol:  mips_cpu/mips.sym # of pins=8
// sym_path: /opt/PDKs/open-pdks/share/pdk/sky130B/libs.tech/xschem/mips_cpu/mips.sym
// sch_path: /opt/PDKs/open-pdks/share/pdk/sky130B/libs.tech/xschem/mips_cpu/mips.sch
module mips
(
  output wire [31:0] imem_addr,
  input wire clk,
  output wire dmem_we,
  input wire rst,
  input wire [31:0] imem_data,
  output wire [31:0] dmem_addr,
  input wire [31:0] dmem_rdata,
  output wire [31:0] dmem_wdata
);
wire mem_to_reg ;
wire [2:0] alucontrol ;
wire alu_src ;
wire reg_write ;
wire branch ;
wire jump ;
wire reg_dst ;


controller
xcontroller_inst ( 
 .instr( imem_data[31:0] ),
 .branch( branch ),
 .jump( jump ),
 .mem_to_reg( mem_to_reg ),
 .mem_write( dmem_we ),
 .reg_dst( reg_dst ),
 .reg_write( reg_write ),
 .alucontrol( alucontrol ),
 .alu_src( alu_src )
);


datapath
xdatapath_inst ( 
 .clk( clk ),
 .rst( rst ),
 .alucontrol( alucontrol ),
 .alu_src( alu_src ),
 .branch( branch ),
 .jump( jump ),
 .mem_to_reg( mem_to_reg ),
 .mem_write( dmem_we ),
 .pc( imem_addr[31:0] ),
 .reg_dst( reg_dst ),
 .alu_result( dmem_addr[31:0] ),
 .reg_write( reg_write ),
 .write_data( dmem_wdata[31:0] ),
 .instr( imem_data[31:0] ),
 .read_data( dmem_rdata[31:0] )
);

// noconn clk
// noconn rst
// noconn imem_data[31:0]
// noconn dmem_rdata[31:0]
// noconn imem_addr[31:0]
// noconn dmem_we
// noconn dmem_addr[31:0]
// noconn dmem_wdata[31:0]
endmodule

// expanding   symbol:  mips_cpu/dmem.sym # of pins=5
// sym_path: /opt/PDKs/open-pdks/share/pdk/sky130B/libs.tech/xschem/mips_cpu/dmem.sym
// sch_path: /opt/PDKs/open-pdks/share/pdk/sky130B/libs.tech/xschem/mips_cpu/dmem.sch
module dmem
(
  input wire clk,
  input wire we,
  output wire [31:0] rdata,
  input wire [31:0] addr,
  input wire [31:0] wdata
);
// noconn rdata[31:0]
// noconn clk
// noconn we
// noconn addr[31:0]
// noconn wdata[31:0]
        reg [31:0] memdata[127:0];

        // always @(memdata[addr]) begin
        //        rdata = memdata[addr];
        // end

        always @(posedge clk) begin
                if(1'b1 == we) begin
                        memdata[addr] = wdata;
                end
        end


       assign rdata = memdata[addr];
endmodule


// expanding   symbol:  mips_cpu/controller.sym # of pins=9
// sym_path: /opt/PDKs/open-pdks/share/pdk/sky130B/libs.tech/xschem/mips_cpu/controller.sym
// sch_path: /opt/PDKs/open-pdks/share/pdk/sky130B/libs.tech/xschem/mips_cpu/controller.sch
module controller
(
  input wire [31:0] instr,
  output wire branch,
  output wire jump,
  output wire mem_to_reg,
  output wire mem_write,
  output wire reg_dst,
  output wire reg_write,
  output wire [2:0] alucontrol,
  output wire alu_src
);

maindec
xmaindec_inst ( 
 .instr( instr[31:0] ),
 .branch( branch ),
 .jump( jump ),
 .mem_to_reg( mem_to_reg ),
 .mem_write( mem_write ),
 .reg_dst( reg_dst ),
 .reg_write( reg_write ),
 .alu_src( alu_src )
);


aludec
xaludec_inst ( 
 .instr( instr[31:0] ),
 .alucontrol( alucontrol[2:0] )
);

// noconn branch
// noconn jump
// noconn mem_to_reg
// noconn mem_write
// noconn reg_dst
// noconn reg_write
// noconn alucontrol[2:0]
// noconn alu_src
// noconn instr[31:0]
endmodule

// expanding   symbol:  mips_cpu/datapath.sym # of pins=15
// sym_path: /opt/PDKs/open-pdks/share/pdk/sky130B/libs.tech/xschem/mips_cpu/datapath.sym
// sch_path: /opt/PDKs/open-pdks/share/pdk/sky130B/libs.tech/xschem/mips_cpu/datapath.sch
module datapath
(
  input wire clk,
  input wire rst,
  input wire [2:0] alucontrol,
  input wire alu_src,
  input wire branch,
  input wire jump,
  input wire mem_to_reg,
  input wire mem_write,
  output reg [31:0] pc,
  input wire reg_dst,
  output wire [31:0] alu_result,
  input wire reg_write,
  output wire [31:0] write_data,
  input wire [31:0] instr,
  input wire [31:0] read_data
);
wire [31:0] reg_data1 ;
wire [31:0] result ;
wire [4:0] write_reg ;
wire [31:0] src_a ;
wire [31:0] reg_data2 ;
wire zero ;
wire [31:0] imm_ext ;
wire [31:0] src_b ;
wire c_out ;
wire [31:0] alu_out ;


regfile
xregfile_inst ( 
 .clk( clk ),
 .addr1( instr[25:21] ),
 .addr2( instr[20:16] ),
 .data1( reg_data1 ),
 .rw( reg_write ),
 .data2( reg_data2 ),
 .addr3( write_reg ),
 .wdata( result )
);


alu
xalu_inst ( 
 .a_in( src_a ),
 .zero( zero ),
 .b_in( src_b ),
 .c_out( c_out ),
 .y_out( alu_out ),
 .f_in( alucontrol[2:0] )
);


sign_extend
xsign_extend_inst ( 
 .idata( instr[15:0] ),
 .odata( imm_ext )
);

// noconn clk
// noconn rst
// noconn alucontrol[2:0]
// noconn alu_src
// noconn branch
// noconn jump
// noconn mem_to_reg
// noconn mem_write
// noconn reg_dst
// noconn reg_write
// noconn instr[31:0]
// noconn read_data[31:0]
// noconn pc[31:0]
// noconn write_data[31:0]
// noconn alu_result[31:0]
// noconn alu_out[31:0]
// noconn src_a[31:0]
// noconn src_b[31:0]
// noconn imm_ext[31:0]
// noconn reg_data1[31:0]
// noconn reg_data2[31:0]
// noconn result[31:0]
// noconn c_out
// noconn zero
// noconn write_reg[4:0]

  wire [31:0] pc_plus_4;
  assign pc_plus_4 = pc + 4;
  wire [31:0] pc_jump;
  assign pc_jump = {pc_plus_4[31:28], instr[25:0], 2'b00};
  wire pc_src;
  assign pc_src = branch & zero;
  wire [31:0] pc_branch;
  assign pc_branch = pc_plus_4 + {imm_ext[29:0], 2'b00};
  wire [31:0] pc_next;
  assign pc_next = jump ? pc_jump : (pc_src ? pc_branch : pc_plus_4);
  always @(posedge clk) begin : proc_pc
    if(~rst) begin
      pc = pc_next;
    end else begin
      pc = 32'h00000000;
    end
  end
  wire [4:0] rt;
  assign rt = instr[20:16];
  wire [4:0] rd;
  assign rd = instr[15:11];
  assign write_reg = reg_dst ? rd : rt;
  assign result = mem_to_reg ? read_data : alu_result ;
  assign src_a = reg_data1;
  assign src_b = alu_src ? imm_ext : reg_data2;
  assign alu_result = alu_out;
  assign write_data = reg_data2;


endmodule

// expanding   symbol:  mips_cpu/maindec.sym # of pins=8
// sym_path: /opt/PDKs/open-pdks/share/pdk/sky130B/libs.tech/xschem/mips_cpu/maindec.sym
// sch_path: /opt/PDKs/open-pdks/share/pdk/sky130B/libs.tech/xschem/mips_cpu/maindec.sch
module maindec
(
  input wire [31:0] instr,
  output wire branch,
  output wire jump,
  output wire mem_to_reg,
  output wire mem_write,
  output wire reg_dst,
  output wire reg_write,
  output wire alu_src
);
// noconn branch
// noconn jump
// noconn mem_to_reg
// noconn mem_write
// noconn reg_dst
// noconn reg_write
// noconn alu_src
// noconn instr[31:0]
        wire [5:0] opcode;
        assign opcode = instr[31:26];

        wire [5:0] func;
        assign func = instr[5:0];

        wire is_add = ((opcode == 6'h00) & (func == 6'h20));
        wire is_sub = ((opcode == 6'h00) & (func == 6'h22));
        wire is_and = ((opcode == 6'h00) & (func == 6'h24));
        wire is_or  = ((opcode == 6'h00) & (func == 6'h25));
        wire is_slt = ((opcode == 6'h00) & (func == 6'h2A));

        wire is_lw = (opcode == 6'h23);
        wire is_sw = (opcode == 6'h2B);

        wire is_beq  = (opcode == 6'h04);
        wire is_addi = (opcode == 6'h08);
        wire is_j    = (opcode == 6'h02);

        assign branch     = is_beq;
        assign jump       = is_j;
        assign mem_to_reg = is_lw;
        assign mem_write  = is_sw;
        assign reg_dst    = is_add | is_sub | is_and | is_or | is_slt;
        assign reg_write  = is_add | is_sub | is_and | is_or | is_slt | is_addi | is_lw;
        assign alu_src    = is_addi | is_lw | is_sw;

endmodule

// expanding   symbol:  mips_cpu/aludec.sym # of pins=2
// sym_path: /opt/PDKs/open-pdks/share/pdk/sky130B/libs.tech/xschem/mips_cpu/aludec.sym
// sch_path: /opt/PDKs/open-pdks/share/pdk/sky130B/libs.tech/xschem/mips_cpu/aludec.sch
module aludec
(
  input wire [31:0] instr,
  output reg [2:0] alucontrol
);
// noconn alucontrol[2:0]
// noconn instr[31:0]

   always @(instr) begin
    case (instr[31:26])
        6'b000000: begin
            // R-type: decode funct
            case (instr[5:0])
                6'b100000: alucontrol = 3'b010; // ADD
                6'b100010: alucontrol = 3'b110; // SUB
                6'b100100: alucontrol = 3'b000; // AND
                6'b100101: alucontrol = 3'b001; // OR
                6'b101010: alucontrol = 3'b111; // SLT
                default:   alucontrol = 3'bxxx;
            endcase
        end

        6'b000100: alucontrol = 3'b110; // BEQ
        6'b001010: alucontrol = 3'b111; // SLTI
        6'b001000: alucontrol = 3'b010; // ADDI

        default: alucontrol = 3'b010;     // default
    endcase
   end


endmodule

// expanding   symbol:  mips_cpu/regfile.sym # of pins=8
// sym_path: /opt/PDKs/open-pdks/share/pdk/sky130B/libs.tech/xschem/mips_cpu/regfile.sym
// sch_path: /opt/PDKs/open-pdks/share/pdk/sky130B/libs.tech/xschem/mips_cpu/regfile.sch
module regfile
(
  input wire clk,
  input wire [4:0] addr1,
  input wire [4:0] addr2,
  output reg [31:0] data1,
  input wire rw,
  output reg [31:0] data2,
  input wire [4:0] addr3,
  input wire [31:0] wdata
);
// noconn clk
// noconn addr1[4:0]
// noconn addr2[4:0]
// noconn rw
// noconn addr3[4:0]
// noconn wdata[31:0]
// noconn data1[31:0]
// noconn data2[31:0]
        reg [31:0] regmem[31:0];

        always @(addr1 or regmem[addr1]) begin
                if (0 == addr1) begin
                        data1 = 0;
                end else begin
                        data1 = regmem[addr1];
                end
        end

        always @(addr2 or regmem[addr2]) begin
                if (0 == addr2) begin
                        data2 = 0;
                end else begin
                        data2 = regmem[addr2];
                end
        end

        always@ (posedge clk) begin
                if(1'b1 == rw) begin
                        regmem[addr3] = wdata;
                end
        end

endmodule

// expanding   symbol:  mips_cpu/alu.sym # of pins=6
// sym_path: /opt/PDKs/open-pdks/share/pdk/sky130B/libs.tech/xschem/mips_cpu/alu.sym
// sch_path: /opt/PDKs/open-pdks/share/pdk/sky130B/libs.tech/xschem/mips_cpu/alu.sch
module alu
(
  input wire [31:0] a_in,
  output wire zero,
  input wire [31:0] b_in,
  output wire c_out,
  output wire [31:0] y_out,
  input wire [2:0] f_in
);
// noconn zero
// noconn a_in[31:0]
// noconn b_in[31:0]
// noconn f_in[2:0]
// noconn c_out
// noconn y_out[31:0]
    wire [31:0] not_b_in;
    assign not_b_in = ~ b_in;

    wire [31:0] b_mux_not_b;
    assign b_mux_not_b = (1'b0 == f_in[2]) ? b_in : not_b_in;

    wire [31:0] fx00;
    assign fx00 = a_in & b_mux_not_b;

    wire [31:0] fx01;
    assign fx01 = a_in | b_mux_not_b;

    wire [31:0] fx10;
    assign {c_out, fx10} = a_in + b_mux_not_b + f_in[2];

    wire [31:0] fx11;
    assign fx11 = {{31{1'b0}}, ((a_in[31] == not_b_in[31]) && (fx10[31] != a_in[31])) ? ~(fx10[31]) : fx10[31]};

    assign zero = ~| y_out;

    assign y_out = 2'b00 == f_in[1:0] ? fx00 : (2'b01 == f_in[1:0] ? fx01 : (2'b10 == f_in[1:0] ? fx10 : fx11 ));

endmodule

// expanding   symbol:  mips_cpu/sign_extend.sym # of pins=2
// sym_path: /opt/PDKs/open-pdks/share/pdk/sky130B/libs.tech/xschem/mips_cpu/sign_extend.sym
// sch_path: /opt/PDKs/open-pdks/share/pdk/sky130B/libs.tech/xschem/mips_cpu/sign_extend.sch
module sign_extend
(
  input wire [15:0] idata,
  output reg [31:0] odata
);
// noconn odata[31:0]
// noconn idata[15:0]
        always @(idata) begin : proc_sign_extend
                odata = {{16{idata[15]}}, idata};
        end
//  wire _unused = &{ena, clk, rst_n, 1'b0};
endmodule
