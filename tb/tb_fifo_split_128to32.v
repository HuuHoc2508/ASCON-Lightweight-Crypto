//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/22/2025 05:49:04 AM
// Design Name: 
// Module Name: tb_fifo_split_128to32
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
`timescale 1ns / 1ps
`default_nettype none

module tb_fifo_split_128to32();

	// =====================================================
	// Parameters & signals
	// =====================================================
	localparam FIFO_DEPTH = 12;

	reg clk, rst_n;
	reg [127:0] data_in;
	reg load;
	reg rd_en;
	wire [31:0] data_out;
	wire empty;
	wire full;
	wire valid;
	reg mode;

	// =====================================================
	// DUT
	// =====================================================
	fifo_split_128to32 #(
		.FIFO_DEPTH(FIFO_DEPTH)
	) dut (
		.clk(clk),
		.rst_n(rst_n),
		.data_in(data_in),
		.load(load),
		.rd_en(rd_en),
		.data_out(data_out),
		.empty(empty),
		.full(full),
		.valid(valid),
		.mode(mode)
	);

	// =====================================================
	// Clock
	// =====================================================
	initial clk = 0;
	always #5 clk = ~clk; // 100 MHz

	// =====================================================
	// Tasks
	// =====================================================

	task reset_dut;
	begin
		rst_n = 0;
		load = 0;
		rd_en = 0;
		data_in = 0;
		mode = 0;
		#20;
		rst_n = 1;
		mode = 1;
		#20;
	end
	endtask

	task load_word(input [127:0] din);
	begin
		@(posedge clk);
		if (full)
			$display("[%0t] WARNING: FIFO full, cannot load data", $time);
		load = 1;
		data_in = din;
		@(posedge clk);
		load = 0;
	end
	endtask

	task read_word(input integer count);
		integer i;
	begin
		for (i = 0; i < count; i = i + 1) begin
			@(posedge clk);
			rd_en = 1;
			@(negedge clk);
			if (valid)
				$display("[%0t] READ DATA = %h", $time, data_out);
			else if (empty)
				$display("[%0t] WARNING: FIFO empty, cannot read", $time);
		end
		@(posedge clk);
		rd_en = 0;
	end
	endtask

	// =====================================================
	// Test sequence
	// =====================================================
	initial begin
		$display("==== TESTBENCH START ====");
		reset_dut();

		// =====================================================
		// Test 1: Nạp đầy FIFO rồi đọc hết
		// =====================================================
		$display("\n[TEST 1] Nạp đầy FIFO rồi đọc hết");
		load_word(128'hA1A2A3A4_B1B2B3B4_C1C2C3C4_D1D2D3D4);
		load_word(128'hE1E2E3E4_F1F2F3F4_11121314_21222324);
		load_word(128'hAAAA0000_BBBB1111_CCCC2222_DDDD3333);
		#10;
		read_word(8);

		// =====================================================
		// Test 2: Nạp một phần, đọc ra, sau đó nạp tiếp
		// =====================================================
		$display("\n[TEST 2] Nạp 1 phần rồi đọc ra, sau đó nạp tiếp");
		load_word(128'h01020304_05060708_090A0B0C_0D0E0F10);
		load_word(128'hAABBCCDD_EEFF0011_22334455_66778899);
		#10;
		read_word(4);
		#10;
		read_word(8); // Đọc hết

		// =====================================================
		// Test 3: Nạp tràn FIFO (overfill)
		// =====================================================
		$display("\n[TEST 3] Nạp tràn FIFO");
		load_word(128'hDEADBEEF_11112222_33334444_55556666);
		load_word(128'hAAAA0000_BBBB1111_CCCC2222_DDDD3333);
		load_word(128'hEEEEFFFF_12345678_90ABCDEF_0000FFFF); // FIFO full sau 2 load đầu
		#10;
		read_word(12); // Cố đọc nhiều hơn lượng có sẵn

        #50;
        mode = 0;
		load_word(128'hA1A2A3A4_B1B2B3B4_C1C2C3C4_D1D2D3D4);
		load_word(128'hE1E2E3E4_F1F2F3F4_11121314_21222324);
        read_word(4);
		#50;
		$display("\n==== TESTBENCH DONE ====");
		$stop;
	end

endmodule

`default_nettype wire
