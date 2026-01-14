`timescale 1ns/1ps

module ascon_d_tb;

    // Clock & reset
    reg clk;
    reg rst_n;

    // Control inputs
    reg [1:0] crypt_variant;
    reg mode; // 1 = decrypt

    // Key / nonce
    reg [159:0] secret_key;
    reg [127:0] nonce;
    reg [5:0] padding_missed;
    reg r_key, r_nonce;

    // Associated Data (AD)
    wire ad_req;
    reg  ad_valid;
    reg  ad_hollow;
    reg [127:0] ad_din;
    reg  ad_last;

    // Plaintext (PT)
    wire pt_req;
    reg  pt_valid;
    reg  pt_hollow;
    reg [127:0] pt_din;
    reg  pt_last;

    // Ciphertext (CT) - not used for encrypt
    wire ct_req;
    reg  ct_valid;
    reg  ct_hollow;
    reg [127:0] ct_din;
    reg  ct_last;
    reg [127:0] tag_din;
    reg r_tag;

    // Outputs
    wire [127:0] e_ciphertext, d_received_text;
    wire [127:0] e_tag;
    wire encrypt_done, decrypt_done;
    wire tag_match;
    wire [319:0] state;
    wire [319:0] state_next;
    wire perm_start; //<- debug
    wire perm_done; // <-- Khai báo wire để kết nối
    wire [319:0] perm_out;

    // Instantiate DUT
    ascon uut (
        .clk(clk),
        .rst_n(rst_n),
        .crypt_variant(crypt_variant),
        .mode(mode),
        .padding_missed(padding_missed),
        .secret_key(secret_key),
        .nonce(nonce),
        .r_key(r_key),
        .r_nonce(r_nonce),
        .ad_req(ad_req),
        .ad_valid(ad_valid),
        .ad_hollow(ad_hollow),
        .ad_din(ad_din),
        .ad_last(ad_last),
        .pt_req(pt_req),
        .pt_valid(pt_valid),
        .pt_hollow(pt_hollow),
        .pt_din(pt_din),
        .pt_last(pt_last),
        .ct_req(ct_req),
        .ct_valid(ct_valid),
        .ct_hollow(ct_hollow),
        .ct_din(ct_din),
        .ct_last(ct_last),
        .tag_din(tag_din),
        .r_tag(r_tag),
//        .perm_start(perm_start),
        .perm_done(perm_done), // <-- Kết nối port perm_done
//        .perm_out(perm_out),
//        .state(state),
//        .state_next(state_next),
        .e_ciphertext(e_ciphertext),
        .valid_e_ct(), // Giả sử port này có trong ascon core (top)
        .e_tag(e_tag),
        .encrypt_done(encrypt_done),
        .d_received_text(d_received_text),
        .valid_d_rt(), // Giả sử port này có trong ascon core (top)
        .tag_match(tag_match),
        .decrypt_done(decrypt_done)
    );

    // -----------------------------------------
    // Clock generation
    // -----------------------------------------
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100 MHz clock
    end

    // -----------------------------------------
    // Stimulus
    // -----------------------------------------
    initial begin
        // Initialize signals
        rst_n = 0;
        mode = 1; // decrypt
        crypt_variant = 2'b00; // Ascon-128

        r_key = 0;
        r_nonce = 0;
        r_tag = 0;

        ad_valid = 0;
        ad_hollow = 0;
        ad_din = 0;
        ad_last = 0;

        pt_valid = 0;
        pt_hollow = 1; // not used for decryption
        pt_din = 0;
        pt_last = 0;

        ct_valid = 0;
        ct_hollow = 0; 
        ct_din = 0;
        ct_last = 0;

        tag_din = 0;

        // Reset phase
        #20;
        rst_n = 1;
        $display("[%t] DUT Reset Released.", $time);

        // Load key and nonce
        @(posedge clk);
        tag_din    = 128'h334d_7f90_65bd_4724_8bf6_9e85_b6af_ef87; //need tag for tag_match (2 khoi)
        secret_key = 160'h0000_0000_0012_3456_7890_1234_5678_9012_3456_7890;
        nonce      = 128'h0012_3456_7890_1234_5678_9012_3456_7890;
        padding_missed = 6'd00; //miss 2 hex
        r_key   = 1;
        r_nonce = 1;
        @(posedge clk);
        r_key   = 0;
        r_nonce = 0;
        
        // =========================================================================
        // LOGIC CHỜ PERM_DONE (THAY ĐỔI CHÍNH Ở ĐÂY)
        // =========================================================================
        // Đợi cho lõi ASCON thực hiện hoán vị ban đầu xong.
        $display("[%t] Waiting for initial permutation to complete (perm_done)...", $time);
        @(posedge perm_done);
        $display("[%t] Initial permutation complete. Ready to provide Associated Data.", $time);

        // -------------------------------
        // Associated Data (2 blocks)
        // Sau khi perm_done, lõi sẽ sẵn sàng và kéo ad_req lên.
        // Giờ ta có thể bắt đầu handshake.
        // -------------------------------
        $display("[%t] Starting Associated Data phase...", $time);
        // Block 1
        wait(ad_req);
        ad_valid = 1;
        ad_din   = 128'h11111111_11111111_00000000_00000000; 
        ad_last  = 0;
        @(posedge clk);
        ad_valid = 0;

        // Block 2
        @(posedge perm_done);
        wait(ad_req);
        ad_valid = 1;
        ad_din   = 128'h22222222_22222222_00000000_00000000; 
        ad_last  = 0;
        @(posedge clk);
        ad_valid = 0;
        
        // Block 3
        @(posedge perm_done);
        wait(ad_req);
        ad_valid = 1;
        ad_din   = 128'h80000000_00000000_00000000_00000000; 
        ad_last  = 1;
        @(posedge clk);
        ad_valid = 0;
        ad_last  = 0;
        $display("[%t] Associated Data phase finished.", $time);


        // -------------------------------
        // Ciphertext (2 blocks)
        // -------------------------------
        $display("[%t] Starting Ciphertext phase...", $time);
        // Block 1
        wait(ct_req);
        ct_valid = 1;
        ct_din   = 128'h65478c1f_b7da7cf8_00000000_00000000; 
        ct_last  = 0;
        @(posedge clk);
        ct_valid = 0;
        
         // Block 2
        @(posedge perm_done);
        wait(ct_req);
        ct_valid = 1;
        ct_din   = 128'hdea0f64d_d28ba85a_00000000_00000000; //miss 2
        ct_last  = 0; //0 
        @(posedge clk);
        ct_valid = 0;
        ct_last  = 0; //
        $display("[%t] Ciphertext phase finished.", $time);//

        // Block 3
        @(posedge perm_done);
        wait(ct_req);
        ct_valid = 1;
        ct_din   = 128'h80000000_00000000_00000000_00000000; 
        ct_last  = 1;
        @(posedge clk);
        ct_valid = 0;
        ct_last  = 0;
        $display("[%t] Ciphertext phase finished.", $time);
        

        // -------------------------------
        // Wait for decryption done
        // -------------------------------
        $display("[%t] Waiting for decryption to complete...", $time);
        wait(decrypt_done);

        #20;
        $display("==== DECRYPTION COMPLETE ====");
        $display("Time: %t", $time);
        $display("Plaintext: %h", d_received_text);
        $display("Tag       : %h", e_tag);
        $display("Tag_match       : %h", tag_match);
        $display("=============================");
        #50;
        $finish;
    end

endmodule

