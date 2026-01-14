`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Decryption Testbench for Ascon-128 and Ascon-128a
// Test with 160 bytes plaintext and authentication tag
// Mode: DECRYPT (mode=1)
//////////////////////////////////////////////////////////////////////////////////
module tb_ascon_decrypt;

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
    localparam ADDR_DE_RESULT       = 32'h0000_002C;
    
	// Clock & reset
	reg clk;
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
	wire [127:0]  d_received_text;
    
	wire [159:0] secret_key;
    wire [127:0] nonce;
    wire [127:0] tag_din;
    wire [127:0] ad_din;
    wire [127:0] ct_din;

	// Debug
	wire wb_active_pulse;
	wire wb_cycle_active;
	
	wire          read_PT_output;
	wire [31:0]  data_de_out;
    
    wire         mode;
    wire [1:0]   crypt_variant;
    wire [5:0]   padding_miss;
    
//input data section
    wire [31:0]  input_data_ad;
    wire         ad_we;
    wire [31:0]  input_data_ct;
    wire         ct_we;    
    wire [31:0]  input_data_key;
    wire         key_we;
    wire [31:0]  input_data_nonce;
    wire         nonce_we;
    wire [31:0]  input_data_tag;
    wire         tag_we;
    wire         start;
    wire         done_status;
    
    wire        done;
    wire        no_CT_data;
    wire        no_tag_data;
    
	// DUT instance
	ascon_wb uut (
		.clk(clk),
		.reset(reset),
		.wb_cyc_i(wb_cyc_i),
		.wb_stb_i(wb_stb_i),
		.wb_we_i(wb_we_i),
		.wb_adr_i(wb_adr_i),
		.wb_dat_i(wb_dat_i),
		.wb_sel_i(wb_sel_i),
		.wb_ack_o(wb_ack_o),
		.wb_dat_o(wb_dat_o),
		.wb_active_pulse(wb_active_pulse),
		.wb_cycle_active(wb_cycle_active),
		
        .mode(mode),
        .crypt_variant(crypt_variant),
        .padding_miss(padding_miss),
        
        .read_PT_output(read_PT_output),
        
        .data_de_out(data_de_out),
    
        .input_data_ad(input_data_ad),
        .ad_we(ad_we),
        .input_data_ct(input_data_ct),
        .ct_we(ct_we),
        .input_data_key(input_data_key),
        .key_we(key_we),
        .input_data_nonce(input_data_nonce),
        .nonce_we(nonce_we),
        .input_data_tag(input_data_tag),
        .tag_we(tag_we),
        .start(start),
        .done_status(done_status),
        
        .d_received_text(d_received_text),
        .secret_key(secret_key),
        .nonce(nonce),
        .tag_din(tag_din),
        .ad_din(ad_din),
        .ct_din(ct_din),
        
        .done(done),
        .no_tag_data(no_tag_data),
        .no_CT_data(no_CT_data)
	);

	// Clock generation
	initial begin
		clk = 0;
		forever #10 clk = ~clk; // 50 MHz
	end

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
    
    task load_tag;
        input [127:0] key_value;
        begin
            wb_write(TAG, key_value[127:96]);
            repeat (10) begin 
                @(posedge clk); 
            end
            wb_write(TAG, key_value[95:64]);
            repeat (10) begin 
                @(posedge clk); 
            end
            wb_write(TAG, key_value[63:32]);
            repeat (10) begin 
                @(posedge clk); 
            end
            wb_write(TAG, key_value[31:0]);
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

    task load_ct;
        input [127:0] key_value;
        begin
            wb_write(CT, key_value[127:96]);
            repeat (10) begin 
                @(posedge clk); 
            end
            wb_write(CT, key_value[95:64]);
            repeat (10) begin 
                @(posedge clk); 
            end
            wb_write(CT, key_value[63:32]);
            repeat (10) begin 
                @(posedge clk); 
            end
            wb_write(CT, key_value[31:0]);
            repeat (10) begin 
                @(posedge clk); 
            end
        end
    endtask
        
    task load_ct_64bit;
        input [63:0] key_value;
        begin
            wb_write(CT, key_value[63:32]);
            repeat (10) begin 
                @(posedge clk); 
            end
            wb_write(CT, key_value[31:0]);
            repeat (10) begin
                @(posedge clk); 
            end
        end
    endtask

	// Main test sequence - DECRYPT MODE
	initial begin
		do_reset();
		#100;
        
        $display("========== ASCON-128 DECRYPT MODE TEST ==========");
        wb_write(SET_UP, 32'h00000001);  // Mode=1 (DECRYPT), Variant=00 (Ascon-128)
        repeat (10) @(posedge clk);
        
        // Test Case 1: Ascon-128 Decryption with 160 bytes ciphertext
        load_key(160'h0000000000123456789012345678901234567890);                        
        load_nonce(128'h00123456789012345678901234567890);
        load_tag(128'h85be3484f05b2a2b1420df4eb1b3df90);  // Expected tag
        
        load_ad(128'h11111111111111112222222222222222);
        load_ad(128'h33333333333333338000000000000000);
        
        load_ct(128'hce04a018e92a1e075375000c6e7054f2);
        load_ct(128'h8ed9d546ebc7192b7fc584fa7cc1fe81);
        load_ct(128'hfc8246fd104165b6a464d2b0152aaf43);
        load_ct(128'h09d21bc707e844ec77242db17580fc34);
        load_ct(128'h80000000000000000000000000000000);
        
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
        
        // Read PLAINTEXT (160 bytes = 40 words of 32-bit)
        repeat (40) begin
            wb_read(ADDR_DE_RESULT);
            repeat (10) begin 
                @(posedge clk); 
            end
        end
        
        $display("========== ASCON-128a DECRYPT MODE TEST ==========");
        wb_write(SET_UP, 32'h00000003);  // Mode=1 (DECRYPT), Variant=10 (Ascon-128a)
        repeat (10) @(posedge clk);
        
        // Test Case 2: Ascon-128a Decryption with 160 bytes ciphertext
        load_key(160'h0000000083fb365424a829892d3b0abb905e1cf1);                        
        load_nonce(128'h314123de0b210413c35ba311bef9ce54);
        load_tag(128'h5c0a50cf36bbf11b12096c3ea1a0a3f8);  // Expected tag
        
        load_ad(128'h11112222333344448888777766665555);
        load_ad(128'h80000000000000000000000000000000);
        
        load_ct(128'h8ed9d546ebc7192b7fc584fa7cc1fe81);
        load_ct(128'hfc8246fd104165b6a464d2b0152aaf43);
        load_ct(128'h09d21bc707e844ec77242db17580fc34);
        load_ct(128'h7aaa04a4fd5f506da087048ddbc24128);
        load_ct(128'h80000000000000000000000000000000);
        
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
        
        repeat (40) begin
            wb_read(ADDR_DE_RESULT);
            repeat (10) begin 
                @(posedge clk); 
            end
        end
        
        repeat (10) @(posedge clk);
        $display("=== Decryption Test Completed ===");
        $finish;
	end

endmodule