`timescale 1ns / 1ps


module imem_serial (
    input  logic        clk,
    input  logic        rst,
    input  logic        en,       // handshake from UUT
    input  logic [7:0]  addr_in,  // incoming byte of address
    output logic [7:0]  data_out  // outgoing byte of instruction
);

    // 32-bit instruction memory
    logic [31:0] mem [0:255];     // 256 words = 1 KB

    // internal 32-bit address and data buffers
    logic [31:0] imem_addr;
    logic [31:0] imem_data;

    // 2-bit cycle counters (0..3)
    logic [1:0] addr_cnt = 0;
    logic [1:0] data_cnt = 0;

    initial begin
        $display("LOading ROM");
        $readmemh("program.hex", mem);

        for (int i = 0; i < 16; i++) begin
            $display("mem[%0d] = %08h", i, mem[i]);
        end

    end
    always_ff @(negedge rst) begin
        addr_cnt <= 0;
        data_cnt <= 0; 
    end

    // Serial assembly of 32-bit address
    always_ff @(posedge clk) begin
        if (en && rst) begin
            case (addr_cnt)
                2'd0: imem_addr[31:24] <= addr_in;
                2'd1: imem_addr[23:16] <= addr_in;
                2'd2: imem_addr[15:8]  <= addr_in;
                2'd3: imem_addr[7:0]   = addr_in;
            endcase



            // after last byte — read memory word
            if (addr_cnt == 2'd3) begin
                $display("Addrs cnt is %4d", addr_cnt);
                imem_data = mem[imem_addr[31:0]];   // word aligned
                $displa4y("Loaded memory %08h at adress %08h",imem_data, imem_addr);
                data_cnt <= 0;                       // start data out
            end
            addr_cnt <= addr_cnt + 1'b1;
        end
    end

    // Serial output of 32-bit instruction
    always_ff @(posedge clk) begin
        case (data_cnt)
            2'd0: data_out <= imem_data[31:24];
            2'd1: data_out <= imem_data[23:16];
            2'd2: data_out <= imem_data[15:8];
            2'd3: data_out <= imem_data[7:0];
        endcase

        if (en && addr_cnt > 3) begin
            // cycle through output bytes only after a full address is accepted
            data_cnt <= data_cnt + 1'b1;
        end
    end

endmodule

module project_tb;
 
  localparam int N = 8;  // counter bit width
  localparam int T = 10;  // clock period in ns
 
  logic clk;
  logic rst;
  logic en;
  logic [N-1:0] ui_in;
  logic [N-1:0] uo_out;
  logic [N-1:0] uio_in;
  wire [N-1:0] uio_out;
  wire [N-1:0] uio_oe;
  


  tt_um_magnetofield_mips uut (
    
      .ui_in(ui_in),
      .uo_out(uo_out),
      .uio_in(uio_in),
      .uio_out(uio_out),
      .uio_oe(uio_oe),
      .ena(en),
      .clk(clk),
      .rst_n(rst)
  );


logic [N-1:0] imem_data;
logic [N-1:0] imem_addr_byte;

  imem_serial IMEM (
    .clk(clk),
    .rst(rst),
    .en(1'b1),              // always enabled for now
    .addr_in(uo_out[7:0]),  // your UUT outputs one byte per cycle
    .data_out(imem_data)
  );

// Your UUT reads one byte per cycle from this:
assign ui_in = imem_data;

 
  // Clock
  always begin
    clk = 1'b1;
    #(T / 2);
    clk = 1'b0;
    #(T / 2);
  end
 
  // Async reset (over the first half cycle)
  initial begin
    rst = 1'b0;
    #(T / 2);
    rst = 1'b1;
  end
 
  // Enable on the third cycle and count for 10 cycles
  initial begin
    en = 1;
    repeat (3) @(negedge clk);
    en = 1;
    #(100 * T) $finish;
  end
 
  initial begin
    $timeformat(-9, 1, " ns", 8);
    $monitor("time=%t clk=%b rst=%b en=%b count=%2d", $time, clk, rst, en, uo_out);
    $dumpfile("project_tb.vcd");
    $dumpvars(0, project_tb);
  end
  
 
endmodule  // project_tb

