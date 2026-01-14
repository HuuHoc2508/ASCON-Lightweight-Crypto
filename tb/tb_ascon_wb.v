`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/22/2025
// Design Name: 
// Module Name: tb_ascon_wb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Testbench skeleton for ascon_wb
// 
//////////////////////////////////////////////////////////////////////////////////
module tb_ascon_wb;

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
    localparam ADDR_DE_RESULT       = 32'h0000_002C;
    
	// Clock & reset
	//reg clk;
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
	wire [127:0]  e_ciphertext; // for encrypt mode
    wire [127:0]  e_tag;
    
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
    
    
    wire             perm_start;
     wire             perm_done;
     wire [319:0]        perm_out;
     wire  [319:0]        state;
     
    wire        done;
    wire        no_PT_data;
    wire        no_CT_data;
    wire        no_tag_data;
	// DUT instance
	
	// 1. Khai báo tín hiệu clock
    reg  clk;      // Clock gốc
    wire clk_in_p;      // Chân dương
    wire clk_in_n;      // Chân âm

    // 2. Tạo dao động (Ví dụ 200MHz -> chu kỳ 5ns -> đảo trạng thái mỗi 2.5ns)
    initial begin
        clk = 0;
        forever #2.5 clk = ~clk; 
    end

    // 3. Gán giá trị cho cặp vi sai
    assign clk_in_p = clk;
    assign clk_in_n = ~clk;
	
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
		.wb_active_pulse(wb_active_pulse),
		.wb_cycle_active(wb_cycle_active),
		
        .mode(mode),
        .crypt_variant(crypt_variant),
        .padding_miss(padding_miss),
        
        .read_PT_output(read_PT_output),
	   .read_CT_output(read_CT_output),
        .read_tag_output(read_tag_output),
        
        .data_de_out(data_de_out),
        .data_en_out(data_en_out),
        .data_tag_out(data_tag_out),
    
        .input_data_ad(input_data_ad),
        .ad_we(ad_we),
        .input_data_pt(input_data_pt),
        .pt_we(pt_we),
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
        
                .perm_start(perm_start),
    .perm_done(perm_done),
    .perm_out(perm_out),
    .state(state),
        
        .e_ciphertext(e_ciphertext),
        .e_tag(e_tag),        
        .d_received_text(d_received_text),
        .secret_key(secret_key),
        .nonce(nonce),
        .tag_din(tag_din),
        .ad_din(ad_din),
        .ct_din(ct_din),    
        
        .done(done),
        .no_tag_data(no_tag_data),
        .no_CT_data(no_CT_data),
        .no_PT_data(no_PT_data)

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
//mode            <= wb_dat_i[0:0];     1 DE / 0 EN
//crypt_variant   <= wb_dat_i[2:1];     00  01  10
//padding_miss    <= wb_dat_i[8:3];   //use hex
//32'h00000011
//Ruler
//thisis128bit00000000000000000000
//
//thisis64bit00000
//
	// Main test sequence
	initial begin
		do_reset();
		#100;
        wb_write(SET_UP,32'h00000000);
        repeat (10) begin 
            @(posedge clk); 
        end
        load_key(160'h0000000000123456789012345678901234567890);                        
        load_nonce(128'h00123456789012345678901234567890);
        load_ad(128'h11111111111111112222222222222222);
        load_ad(128'h33333333333333338000000000000000);
        load_pt(128'h4444444444444444Aabbccdd66666666);
        load_pt_64bit(64'h8000000000000000);
        repeat (10) @(posedge clk);
        wb_write(STARTNOW,32'h00000000);
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
			
		repeat (5)	begin
			wb_read(ADDR_TAG_RESULT);
			repeat (10) begin 
					@(posedge clk); 
			  end
		end  
		repeat (12)	begin
			wb_read(ADDR_EN_RESULT);
			repeat (10) begin 
					@(posedge clk); 
			  end
		end  
		
        wb_write(SET_UP,32'h00000001);
        repeat (10) @(posedge clk);
        load_tag(128'h85be3484f05b2a2b1420df4eb1b3df90);
        load_ct_64bit(64'hce04a018e92a1e07);
        load_ct_64bit(64'h5375000c6e7054f2);
        load_ct_64bit(64'h8000000000000000);
        
        load_ad_64bit(64'h11111111_11111111);
        load_ad_64bit(64'h22222222_22222222);
        load_ad_64bit(64'h33333333_33333333);
        load_ad_64bit(64'h80000000_00000000);
        repeat (10) @(posedge clk);
        wb_write(STARTNOW,32'h00000000);
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
		repeat(5) begin
			wb_read(ADDR_DE_RESULT);
			repeat (10) begin 
					@(posedge clk); 
			 end
		end
		  
		  wb_write(SET_UP,32'h00000002);
        repeat (10) begin 
            @(posedge clk); 
        end
			load_key(160'h0000000083fb365424a829892d3b0abb905e1cf1);                        
					load_nonce(128'h314123de0b210413c35ba311bef9ce54);
        
			load_ad(128'h11112222333344448888777766665555);
			load_ad(128'h80000000000000000000000000000000);

			load_pt(128'h12345678deadbeef1122334455667788);
			
			load_pt(128'hdeadbeefdeadbeefaaaabbbbccccdddd);
			load_pt(128'h12345678deadbeef1122334455667788);
			load_pt(128'h80000000000000000000000000000000);
			repeat (10) @(posedge clk);
			wb_write(STARTNOW,32'h00000000);
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
		repeat (5)	begin
			wb_read(ADDR_TAG_RESULT);
			repeat (10) begin 
					@(posedge clk); 
			  end
		end  
		repeat (13)	begin
			wb_read(ADDR_EN_RESULT);
			repeat (10) begin 
					@(posedge clk); 
			  end
		end  
		
			wb_write(SET_UP,32'h00000003);
        repeat (10) begin 
            @(posedge clk); 
        end
			load_key(160'h0000000083fb365424a829892d3b0abb905e1cf1);                        
			load_nonce(128'h314123de0b210413c35ba311bef9ce54);
			load_tag(128'h5c0a50cf36bbf11b12096c3ea1a0a3f8);
			
			load_ad(128'h11112222333344448888777766665555);
			load_ad(128'h80000000000000000000000000000000);

			load_ct(128'h8ed9d546ebc7192b7fc584fa7cc1fe81);
			load_ct(128'hfc8246fd104165b6a464d2b0152aaf43);
			load_ct(128'h09d21bc707e844ec77242db17580fc34);
			load_ct(128'h80000000000000000000000000000000);
			repeat (10) @(posedge clk);
			wb_write(STARTNOW,32'h00000000);
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
				repeat (13)	begin
			wb_read(ADDR_DE_RESULT);
			repeat (10) begin 
					@(posedge clk); 
			  end
		end

		wb_write(SET_UP,32'h00000002);
        repeat (10) begin 
            @(posedge clk); 
        end
			load_key(160'h0000000083fb365424a829892d3b0abb905e1cf1);                        
					load_nonce(128'h314123de0b210413c35ba311bef9ce54);

			load_ad(128'hc0f6f41cfc970ad2fbb116e9c53fc939);
			load_ad(128'hcd074b7b17b40c34f58828a07ef569e5);
			load_ad(128'h80000000000000000000000000000000);
							 
			load_pt(128'ha83b2ff674feb6d4adb8fa6ab7575155);
			load_pt(128'h83fb365424a829892d3b0abb905e1cf1);
			load_pt(128'h314123de0b210413c35ba311bef9ce54);
			load_pt(128'h54fe60e29c9475db3af250b40f08535e);
			load_pt(128'h80000000000000000000000000000000);
			repeat (10) @(posedge clk);
			wb_write(STARTNOW,32'h00000000);
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
		repeat (5)	begin
			wb_read(ADDR_TAG_RESULT);
			repeat (10) begin 
					@(posedge clk); 
			  end
		end  
		repeat (17)	begin
			wb_read(ADDR_EN_RESULT);
			repeat (10) begin 
					@(posedge clk); 
			  end
		end  

		wb_write(SET_UP,32'h00000002);
        repeat (10) begin 
            @(posedge clk); 
        end
			load_key(160'h0000000083fb365424a829892d3b0abb905e1cf1);                        
					load_nonce(128'h314123de0b210413c35ba311bef9ce54);
			load_ad(128'ha6b2325cf3f93996d17496caf6d4004f);
			load_ad(128'h7c8d4a598aeb26bea2ef73942df8b342);
			load_ad(128'h80000000000000000000000000000000);
			
			load_pt(128'h3012f7015dac83065b8af94788631cb1);
			load_pt(128'h1c0fd37ef98da3b3d93fdd132a69d6ce);
			load_pt(128'hdc062acdee30453ea0507292004f1e17);
			load_pt(128'ha3f9e89b4e833dbaaaf7373a1b8b390d);
			load_pt(128'h80000000000000000000000000000000);
			repeat (10) @(posedge clk);
			wb_write(STARTNOW,32'h00000000);
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
		repeat (5)	begin
			wb_read(ADDR_TAG_RESULT);
			repeat (10) begin 
					@(posedge clk); 
			  end
		end  
		repeat (17)	begin
			wb_read(ADDR_EN_RESULT);
			repeat (10) begin 
					@(posedge clk); 
			  end
		end  
		
		
		wb_write(SET_UP,32'h00000003);
        repeat (10) begin 
            @(posedge clk); 
        end
			load_key(160'h0000000083fb365424a829892d3b0abb905e1cf1);                        
					load_nonce(128'h314123de0b210413c35ba311bef9ce54);
			load_tag(128'ha6b2325cf3f93996d17496caf6d4004f);
			
			load_ad(128'hc0f6f41cfc970ad2fbb116e9c53fc939);
			load_ad(128'hcd074b7b17b40c34f58828a07ef569e5);
			load_ad(128'h80000000000000000000000000000000);
							 
			load_ct(128'h3012f7015dac83065b8af94788631cb1);
			load_ct(128'h1c0fd37ef98da3b3d93fdd132a69d6ce);
			load_ct(128'hdc062acdee30453ea0507292004f1e17);
			load_ct(128'ha3f9e89b4e833dbaaaf7373a1b8b390d);
			load_ct(128'h80000000000000000000000000000000);
			repeat (10) @(posedge clk);
			wb_write(STARTNOW,32'h00000000);
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
			repeat (17)	begin
			wb_read(ADDR_DE_RESULT);
			repeat (10) begin 
					@(posedge clk); 
			  end
		end
		
				wb_write(SET_UP,32'h00000003);
        repeat (10) begin 
            @(posedge clk); 
        end
			load_key(160'h0000000083fb365424a829892d3b0abb905e1cf1);                        
					load_nonce(128'h314123de0b210413c35ba311bef9ce54);
			load_tag(128'hf20c2880b0e12048a240b3f364ea32d1);
			
			load_ad(128'ha6b2325cf3f93996d17496caf6d4004f);
			load_ad(128'h7c8d4a598aeb26bea2ef73942df8b342);
			load_ad(128'h80000000000000000000000000000000);
			
			load_ct(128'h7538169f73ddf62d7640c1b48ff05468);
			load_ct(128'h92602a7639137a85626fbdf5887f5453);
			load_ct(128'h4041baa65b29fa26b0084ddbfcfbcfa2);
			load_ct(128'h7aaa04a4fd5f506da087048ddbc24128);
			load_ct(128'h80000000000000000000000000000000);
			repeat (10) @(posedge clk);
			wb_write(STARTNOW,32'h00000000);
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
						
		    repeat (17)	begin
			wb_read(ADDR_DE_RESULT);
			repeat (10) begin 
					@(posedge clk); 
			  end
		end
        repeat (10) @(posedge clk);
		$display("=== Simulation done ===");
		$finish;
	end
	//44444444_44444444
        //55555555_5555558f
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
endmodule

