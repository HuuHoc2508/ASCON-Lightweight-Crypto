`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Encryption Testbench for Ascon-128 and Ascon-128a
// Test with 160 bytes plaintext
// Mode: ENCRYPT (mode=0)
//////////////////////////////////////////////////////////////////////////////////
module tb_ascon_encrypt;

//Input address
    localparam SET_UP          = 32'h0000_0000;
    localparam KEY             = 32'h0000_0008;
    localparam NONCE           = 32'h0000_000C;
    localparam TAG             = 32'h0000_0010;
    localparam AD              = 32'h0000_0014;
    localparam PT              = 32'h0000_0018;
    localparam CT              = 32'h0000_001C;
    localparam STARTNOW        = 32'h0000_0020;
//Output address    

    localparam ADDR_STATUS          = 32'h0000_0004;
    localparam ADDR_EN_RESULT       = 32'h0000_0024;
    localparam ADDR_TAG_RESULT      = 32'h0000_0028;
    
	// Clock & reset
	// 1. Khai báo tín hiệu clock
    reg  clk;      // Clock gốc
    wire clk_in_p;      // Chân dương
    wire clk_in_n;      // Chân âm
	reg reset;

	// Wishbone interface
	reg         wb_cyc_i;
	reg         wb_stb_i;
	reg         wb_we_i;
	reg [31:0]  wb_adr_i;
	reg [31:0]  wb_dat_i;
	reg [3:0]   wb_sel_i;
	wire        wb_ack_o;
	wire [31:0] wb_dat_o;
	/*
	wire [127:0]  e_ciphertext; // for encrypt mode
    wire [127:0]  e_tag;
    
	wire [159:0] secret_key;
    wire [127:0] nonce;
    wire [127:0] ad_din;
    wire [127:0] pt_din;

	// Debug
	wire wb_active_pulse;
	wire wb_cycle_active;
	
	wire          read_CT_output;
    wire [31:0]  data_en_out;
	
    wire          read_tag_output;
    wire [31:0]  data_tag_out;
    
    wire         mode;
    wire [1:0]   crypt_variant;
    wire [5:0]   padding_miss;
    
//input data section
    wire [31:0]  input_data_ad;
    wire         ad_we;
    wire [31:0]  input_data_pt;
    wire         pt_we;
    wire [31:0]  input_data_key;
    wire         key_we;
    wire [31:0]  input_data_nonce;
    wire         nonce_we;
    
    wire         done_status;
    wire        no_PT_data;
    */
    wire        start;
    wire        done;
    
    // 2. Tạo dao động (Ví dụ 200MHz -> chu kỳ 5ns -> đảo trạng thái mỗi 2.5ns)
    initial begin
        clk = 0;
        forever #2.5 clk = ~clk; 
    end

    // 3. Gán giá trị cho cặp vi sai
    assign clk_in_p = clk;
    assign clk_in_n = ~clk;
    
	// DUT instance
	ascon_wb uut (
		//.clk(clk),
		.clk_in_p(clk_in_p),    
        .clk_in_n(clk_in_n),
		.reset(reset),
		.wb_cyc_i(wb_cyc_i),
		.wb_stb_i(wb_stb_i),
		.wb_we_i(wb_we_i),
		.wb_adr_i(wb_adr_i),
		.wb_dat_i(wb_dat_i),
		.wb_sel_i(wb_sel_i),
		.wb_ack_o(wb_ack_o),
		.wb_dat_o(wb_dat_o),
		.start(start),
	    .done(done)	
	);

	// Task: reset DUT
	task do_reset;
	begin
		reset = 1;
		wb_cyc_i = 0;
		wb_stb_i = 0;
		wb_we_i  = 0;
		wb_adr_i = 0;
		wb_dat_i = 0;
		wb_sel_i = 4'b1111;
		#50;
		reset = 0;
	end
	endtask

	// Task: Wishbone write
	task wb_write(input [31:0] addr, input [31:0] data);
	begin
		
		wb_cyc_i <= 1;
		wb_stb_i <= 1;
		wb_we_i  <= 1;
		wb_adr_i <= addr;
		wb_dat_i <= data;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
		wb_cyc_i <= 0;
		wb_stb_i <= 0;
		@(posedge clk);
        @(posedge clk);
		wb_we_i  <= 0;
	end
	endtask

	// Task: Wishbone read
	task wb_read(input [31:0] addr);
	begin
		@(posedge clk);
		wb_cyc_i <= 1;
		wb_stb_i <= 1;
		wb_we_i  <= 0;
		wb_adr_i <= addr;
		wb_sel_i <= 4'b1111;

		wait (wb_ack_o);
		$display("[%0t] Read @%h = %h", $time, addr, wb_dat_o);
		@(posedge clk);
		wb_cyc_i <= 0;
		wb_stb_i <= 0;
	end
	endtask
    
    task load_key;
        input [159:0] key_value;
        begin
            wb_write(KEY, key_value[159:128]);
            repeat (10) begin 
                @(posedge clk); 
            end
            wb_write(KEY, key_value[127:96]);
            repeat (10) begin 
                @(posedge clk); 
            end
            wb_write(KEY, key_value[95:64]);
            repeat (10) begin 
                @(posedge clk); 
            end
            wb_write(KEY, key_value[63:32]);
            repeat (10) begin 
                @(posedge clk); 
            end
            wb_write(KEY, key_value[31:0]);
            repeat (10) begin 
                @(posedge clk); 
            end
        end
    endtask
    
    task load_nonce;
        input [127:0] key_value;
        begin
            wb_write(NONCE, key_value[127:96]);
            repeat (10) begin 
                @(posedge clk); 
            end
            wb_write(NONCE, key_value[95:64]);
            repeat (10) begin 
                @(posedge clk); 
            end
            wb_write(NONCE, key_value[63:32]);
            repeat (10) begin 
                @(posedge clk); 
            end
            wb_write(NONCE, key_value[31:0]);
            repeat (10) begin 
                @(posedge clk); 
            end
        end
    endtask

    task load_ad;
        input [127:0] key_value;
        begin
            wb_write(AD, key_value[127:96]);
            repeat (10) begin 
                @(posedge clk); 
            end
            wb_write(AD, key_value[95:64]);
            repeat (10) begin 
                @(posedge clk); 
            end
            wb_write(AD, key_value[63:32]);
            repeat (10) begin 
                @(posedge clk); 
            end
            wb_write(AD, key_value[31:0]);
            repeat (10) begin 
                @(posedge clk); 
            end
        end
    endtask
    
    task load_ad_64bit;
        input [63:0] key_value;
        begin
            wb_write(AD, key_value[63:32]);
            repeat (10) begin 
                @(posedge clk); 
            end
            wb_write(AD, key_value[31:0]);
            repeat (10) begin 
                @(posedge clk); 
            end
        end
    endtask

    task load_pt;
        input [127:0] key_value;
        begin
            wb_write(PT, key_value[127:96]);
            repeat (10) begin 
                @(posedge clk); 
            end
            wb_write(PT, key_value[95:64]);
            repeat (10) begin 
                @(posedge clk); 
            end
            wb_write(PT, key_value[63:32]);
            repeat (10) begin 
                @(posedge clk); 
            end
            wb_write(PT, key_value[31:0]);
            repeat (10) begin 
                @(posedge clk); 
            end
        end
    endtask
    
    task load_pt_64bit;
        input [63:0] key_value;
        begin
            wb_write(PT, key_value[63:32]);
            repeat (10) begin 
                @(posedge clk); 
            end
            wb_write(PT, key_value[31:0]);
            repeat (10) begin 
                @(posedge clk); 
            end
        end
    endtask

	// Main test sequence - ENCRYPT MODE
	initial begin
		do_reset();
		#100;
        
        $display("========== ASCON-128 ENCRYPT MODE TEST ==========");
        wb_write(SET_UP, 32'h00000000);  // Mode=0 (ENCRYPT), Variant=00 (Ascon-128)
        repeat (10) @(posedge clk);
        
        // Test Case 1: Ascon-128 with 160 bytes plaintext
        load_key(160'h0000000000123456789012345678901234567890);                        
        load_nonce(128'h00123456789012345678901234567890);
        load_ad(128'h11111111111111112222222222222222);
        load_ad(128'h33333333333333338000000000000000);
        load_pt(128'h44444444444444445555555555555555);
        load_pt(128'hdeadbeefdeadbeefaaaabbbbccccdddd);
        load_pt(128'h12345678deadbeef1122334455667788);
        load_pt(128'hdeadbeefdeadbeefaaaabbbbccccdddd);
        load_pt(128'h80000000000000000000000000000000);
        
        repeat (10) @(posedge clk);
        wb_write(STARTNOW, 32'h00000000);
        repeat (10) @(posedge clk);
        
        repeat (2) begin
            wb_read(ADDR_STATUS);
            repeat (10) begin
                @(posedge clk); 
            end
        end        
        @(posedge done);
        repeat (5) begin
            wb_read(ADDR_STATUS);
            repeat (10) begin
                @(posedge clk); 
            end
        end
        
        // Read TAG (5 words for 160 bits, with padding)
        repeat (5) begin
            wb_read(ADDR_TAG_RESULT);
            repeat (10) begin 
                @(posedge clk); 
            end
        end  
        
        // Read CIPHERTEXT (160 bytes = 40 words of 32-bit)
        repeat (40) begin
            wb_read(ADDR_EN_RESULT);
            repeat (10) begin 
                @(posedge clk); 
            end
        end  
        
        $display("========== ASCON-128a ENCRYPT MODE TEST ==========");
        wb_write(SET_UP, 32'h00000002);  // Mode=0 (ENCRYPT), Variant=10 (Ascon-128a)
        repeat (10) @(posedge clk);
        
        // Test Case 2: Ascon-128a with 160 bytes plaintext
        load_key(160'h0000000083fb365424a829892d3b0abb905e1cf1);                        
        load_nonce(128'h314123de0b210413c35ba311bef9ce54);
        load_ad(128'h11112222333344448888777766665555);
        load_ad(128'h80000000000000000000000000000000);
        
        load_pt(128'h12345678deadbeef1122334455667788);
        load_pt(128'hdeadbeefdeadbeefaaaabbbbccccdddd);
        load_pt(128'h12345678deadbeef1122334455667788);
        load_pt(128'hdeadbeefdeadbeefaaaabbbbccccdddd);
        load_pt(128'h80000000000000000000000000000000);
        
        repeat (10) @(posedge clk);
        wb_write(STARTNOW, 32'h00000000);
        repeat (10) @(posedge clk);
        
        repeat (2) begin
            wb_read(ADDR_STATUS);
            repeat (10) begin
                @(posedge clk); 
            end
        end        
        @(posedge done);
        repeat (5) begin
            wb_read(ADDR_STATUS);
            repeat (10) begin
                @(posedge clk); 
            end
        end
        
        repeat (5) begin
            wb_read(ADDR_TAG_RESULT);
            repeat (10) begin 
                @(posedge clk); 
            end
        end  
        
        repeat (40) begin
            wb_read(ADDR_EN_RESULT);
            repeat (10) begin 
                @(posedge clk); 
            end
        end  
        
        repeat (10) @(posedge clk);
        $display("=== Encryption Test Completed ===");
        $finish;
	end

endmodule