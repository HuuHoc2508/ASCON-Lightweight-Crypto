`timescale 1ns / 1ps

module tb_ascon_top();

parameter DATA_WIDTH = 32;
parameter ADDR_WIDTH_WB = 32;
parameter DATA_WIDTH_WB = 32;

// --- Khai báo tín hiệu Testbench ---
reg                      clk;
reg                      rst_n;
reg [1:0]                crypt_variant;
reg                      mode;
reg [5:0]                padding_missed;
reg                      start;
//Input data
reg [31:0]               input_data_ad;
reg                      ad_we;
reg [31:0]               input_data_pt;
reg                      pt_we;
reg [31:0]               input_data_ct;
reg                      ct_we;
reg [31:0]               input_data_key;
reg                      key_we;
reg [31:0]               input_data_nonce;
reg                      nonce_we;
reg [31:0]               input_data_tag;
reg                      tag_we;

reg                      ad_hollow;
reg                      pt_hollow;
reg                      ct_hollow;
reg                      r_tag;

wire                     ad_req;
wire                     pt_req;
wire                     ct_req;

    wire         ad_valid;
    wire [127:0] ad_din;
    wire         ad_last;
    
    wire         pt_valid;
    wire [127:0] pt_din;
    wire         pt_last;
    
    wire         ct_valid;
    wire [127:0] ct_din;
    wire         ct_last;
// outputs
wire [127:0]             e_ciphertext;
wire [127:0]             e_tag;
wire [127:0]             d_received_text;
wire                     data_out_to_fifo_en;
wire                     done;
    wire          valid_d_rt;
    wire          valid_e_ct;
    wire 	e_ct;
    wire	d_rt;
wire [159:0] secret_key;   // key loaded from gateway
wire [127:0] nonce;
wire [127:0] tag_din;

wire             perm_start;
wire             perm_done;
wire [319:0]        perm_out;
wire  [319:0]        state;
wire  [319:0]        state_next;
    


wire         out_de_valid;
wire [31:0]  data_de_out;
reg          read_PT_output;
wire         no_PT_data;
    
wire         out_en_valid;
wire [31:0]  data_en_out;
reg          read_CT_output;
wire         no_CT_data;
    
wire         out_tag_valid;
wire [31:0]  data_tag_out;
reg          read_tag_output;
wire         no_tag_data;
ascon_top #(
    .DATA_WIDTH(32),
    .ADDR_WIDTH_WB(32),
    .DATA_WIDTH_WB(32)
) dut (
    .clk(clk),
    .rst_n(rst_n),
    .crypt_variant(crypt_variant),
    .mode(mode),
    .valid_d_rt(valid_d_rt),
    .valid_e_ct(valid_e_ct),
    .e_ct(e_ct),
    .d_rt(d_rt),
    .padding_missed(padding_missed),
    .start(start),
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
    .ad_req(ad_req),
    .ad_hollow(ad_hollow),
    .pt_req(pt_req),
    .pt_hollow(pt_hollow),
    .ct_req(ct_req),
    .ct_hollow(ct_hollow),
    .r_tag(r_tag),
    .e_ciphertext(e_ciphertext),
    .e_tag(e_tag),
    .d_received_text(d_received_text),
    .data_out_to_fifo_en(data_out_to_fifo_en),
    .done(done),
    .secret_key(secret_key),
    .nonce(nonce),
    .tag_din(tag_din),
    
    .ct_din(ct_din),
    .ct_valid(ct_valid),
    .ct_last(ct_last),
    
    .ad_valid(ad_valid),
    .ad_din(ad_din),
    .ad_last(ad_last),
    
    .pt_valid(pt_valid),
    .pt_din(pt_din),
    .pt_last(pt_last),
    
    .perm_start(perm_start),
    .perm_done(perm_done),
    .perm_out(perm_out),
    .state(state),
    .state_next(state_next),
   
    
    .out_de_valid(out_de_valid),
    .data_de_out(data_de_out),
    .read_PT_output(read_PT_output),
    .no_PT_data(no_PT_data),

    .out_en_valid(out_en_valid),
    .data_en_out(data_en_out),
    .read_CT_output(read_CT_output),
    .no_CT_data(no_CT_data),

    .out_tag_valid(out_tag_valid),
    .data_tag_out(data_tag_out),
    .read_tag_output(read_tag_output),
    .no_tag_data(no_tag_data)



);

initial begin
    clk = 0;
    forever #10 clk = ~clk; // 50 MHz clock
end



initial begin
        rst_n = 0;
        mode = 0;
        start = 0;
        crypt_variant = 2'b00;
        read_PT_output = 0;
        read_CT_output = 0;
        read_tag_output = 0;
        ad_hollow = 0;
        pt_hollow = 0;
        ct_hollow = 0;
        r_tag = 0;
        input_data_ad = 0;
        ad_we = 0;
        input_data_pt = 0;
        pt_we = 0;
        input_data_ct = 0;
        ct_we = 0;
        input_data_key = 0;
        key_we = 0;
        input_data_nonce = 0;
        nonce_we = 0;
        input_data_tag = 0;
        tag_we = 0;
        
        #20
        rst_n = 1;
        @(posedge clk);
        //padding_missed = 6'd2;
        
        load_key(160'h0000000000123456789012345678901234567890);
        load_nonce(128'h00123456789012345678901234567890);
        
        load_ad_64bit(64'h11111111_11111111);
        load_ad_64bit(64'h22222222_22222222);
        load_ad_64bit(64'h33333333_33333333);
        load_ad_64bit(64'h80000000_00000000);
        
        load_pt_64bit(64'h44444444_44444444);
        load_pt_64bit(64'haabbccdd_66666666);
        load_pt_64bit(64'h80000000_00000000);
        
            // --- Tạo xung ad_hollow và pt_hollow ---


        
        start = 1;
        @(posedge clk);
        start = 0;
        
//        @(posedge ad_req);
//        @(posedge ad_req);
//        @(posedge ad_req);
//        @(posedge ad_req);
//        @(posedge clk);
//        @(posedge clk);
//        ad_hollow = 1;
//        @(posedge clk);
//        ad_hollow = 0;
        
        @(posedge pt_req);
        @(posedge pt_req);
        @(posedge pt_req);

        
        wait(done);
        
        @(posedge clk);
        read_CT_output = 1;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        read_CT_output = 0;
        
        @(posedge clk);
        read_tag_output = 1;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        read_tag_output = 0;
        
        
        #100;
        mode = 1;
        //padding_missed = 6'd16;
        @(posedge clk);
        load_tag(128'h85be3484f05b2a2b1420df4eb1b3df90);
        load_ct_64bit(64'hce04a018e92a1e07);
        load_ct_64bit(64'h5375000c6e7054f2);
        load_ct_64bit(64'h8000000000000000);
        
        load_ad_64bit(64'h11111111_11111111);
        load_ad_64bit(64'h22222222_22222222);
        load_ad_64bit(64'h33333333_33333333);
        load_ad_64bit(64'h80000000_00000000);
        start = 1;
        @(posedge clk);
        start = 0;
        
        @(posedge ct_req);
        @(posedge ct_req);
        @(posedge ct_req);
        
        wait(done);
        read_PT_output = 1;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        read_PT_output = 0;
        
        #100;
        mode = 0;
        crypt_variant = 2'b01;
        load_key(160'h0000000000123456789012345678901234567890);
        load_nonce(128'h00123456789012345678901234567890);
        
        load_ad_64bit(64'h11111111_11111111);
        load_ad_64bit(64'h22222222_22222222);
        load_ad_64bit(64'h33333333_33333333);
        load_ad_64bit(64'h80000000_00000000);

        
        load_pt_64bit(64'h44444444_44444444);
        load_pt_64bit(64'haabbccdd_66666666);
        load_pt_64bit(64'h80000000_00000000);
        load_pt_64bit(64'h00000000_00000000);
        
        start = 1;
        @(posedge clk);

        start = 0;
        
        @(posedge pt_req);
        @(posedge pt_req);
        
//        pt_hollow = 1;
//        @(posedge clk);
//        pt_hollow = 0;
        wait(done);
        read_CT_output = 1;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        read_CT_output = 0;
        
        
        #100;
        mode = 1;
        load_tag(128'h4ea8d8b4d4dbdad6f64960c896139b72);
        load_ct_64bit(64'h4125a3dcceabb574);
        load_ct_64bit(64'hc4ba44f8b4a46207);
        load_ct_64bit(64'h8000000000000000);
        load_ct_64bit(64'h0000000000000000);

        
        load_ad_64bit(64'h11111111_11111111);
        load_ad_64bit(64'h22222222_22222222);
        load_ad_64bit(64'h33333333_33333333);
        load_ad_64bit(64'h44444444_44444444);
        load_ad_64bit(64'h80000000_00000000);
        load_ad_64bit(64'h00000000_00000000);
        
        start = 1;
        @(posedge clk);
        start = 0;
        wait(done);
        read_PT_output = 1;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        read_PT_output = 0;
        
        
        
        $finish;
    end
    
task load_ad_64bit;
    input [63:0] ad_value;
    begin
        @(posedge clk);
        input_data_ad = ad_value[63:32];
        ad_we         = 1'b1;
        @(posedge clk);
        ad_we         = 1'b0;
        repeat(3) @(posedge clk);
        input_data_ad = ad_value[31:0];
        ad_we         = 1'b1;
        @(posedge clk);
        ad_we         = 1'b0;
        input_data_ad = 32'b0; 
        repeat(4) @(posedge clk);
    end
endtask

task load_ct_64bit;
    input [63:0] ct_value;
    begin
        @(posedge clk);
        input_data_ct = ct_value[63:32];
        ct_we         = 1'b1;
        @(posedge clk);
        ct_we         = 1'b0;
        repeat(3) @(posedge clk);
        input_data_ct = ct_value[31:0];
        ct_we         = 1'b1;
        @(posedge clk);
        ct_we         = 1'b0;
        input_data_ct = 32'b0; 
        repeat(4) @(posedge clk);
    end
endtask

task load_pt_64bit;
    input [63:0] pt_value;
    begin
        @(posedge clk);
        input_data_pt = pt_value[63:32];
        pt_we         = 1'b1;
        @(posedge clk);
        pt_we         = 1'b0;
        repeat(3) @(posedge clk);
        input_data_pt = pt_value[31:0];
        pt_we         = 1'b1;
        @(posedge clk);
        pt_we         = 1'b0;
        input_data_pt = 32'b0; 
        repeat(4) @(posedge clk);
    end
endtask

task load_nonce;
    input [127:0] nonce_value;
    begin
        @(posedge clk);
        input_data_nonce = nonce_value[127:96];
        nonce_we         = 1'b1;
        @(posedge clk);
        nonce_we         = 1'b0;
        repeat(3) @(posedge clk);
        input_data_nonce = nonce_value[95:64];
        nonce_we         = 1'b1;
        @(posedge clk);
        nonce_we         = 1'b0;
        repeat(3) @(posedge clk);
        input_data_nonce = nonce_value[63:32];
        nonce_we         = 1'b1;
        @(posedge clk);
        nonce_we         = 1'b0;
        repeat(3) @(posedge clk);
        input_data_nonce = nonce_value[31:0];
        nonce_we         = 1'b1;
        @(posedge clk);
        nonce_we         = 1'b0;
        input_data_nonce = 32'b0; 
        repeat(3) @(posedge clk);
    end
endtask
    
task load_tag;
    input [127:0] tag_value;
    begin
        @(posedge clk);
        input_data_tag = tag_value[127:96];
        tag_we         = 1'b1;
        @(posedge clk);
        tag_we         = 1'b0;
        repeat(3) @(posedge clk);
        input_data_tag = tag_value[95:64];
        tag_we         = 1'b1;
        @(posedge clk);
        tag_we         = 1'b0;
        repeat(3) @(posedge clk);
        input_data_tag = tag_value[63:32];
        tag_we         = 1'b1;
        @(posedge clk);
        tag_we         = 1'b0;
        repeat(3) @(posedge clk);
        input_data_tag = tag_value[31:0];
        tag_we         = 1'b1;
        @(posedge clk);
        tag_we         = 1'b0;
        input_data_tag = 32'b0; 
        repeat(3) @(posedge clk);
    end
endtask
    
task load_key;
    input [159:0] key_value;
    begin
        @(posedge clk);
        input_data_key = key_value[160:128];
        key_we         = 1'b1;
        @(posedge clk);
        key_we         = 1'b0;
        repeat(3) @(posedge clk);
        input_data_key = key_value[127:96];
        key_we         = 1'b1;
        @(posedge clk);
        key_we         = 1'b0;
        repeat(3) @(posedge clk);
        input_data_key = key_value[95:64];
        key_we         = 1'b1;
        @(posedge clk);
        key_we         = 1'b0;
        repeat(3) @(posedge clk);
        input_data_key = key_value[63:32];
        key_we         = 1'b1;
        @(posedge clk);
        key_we         = 1'b0;
        repeat(3) @(posedge clk);
        input_data_key = key_value[31:0];
        key_we         = 1'b1;
        @(posedge clk);
        key_we         = 1'b0;
        input_data_key = 32'b0; 
        repeat(3) @(posedge clk);
    end
endtask


endmodule
