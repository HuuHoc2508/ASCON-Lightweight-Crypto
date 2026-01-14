`timescale 1ns / 1ps
`default_nettype none

module tb_data_assembler_128;

    reg         clk;
    reg         rst_n;
    reg  [31:0] data_in;
    reg         wr_en;
    reg         rd_en;
    wire [127:0] data_out;

    // Instantiate DUT
    data_assembler_128 uut (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(data_in),
        .wr_en(wr_en),
        .rd_en(rd_en),
        .data_out(data_out)
    );

    // Clock generation
    always #5 clk = ~clk;

    // Task ghi 1 word
    task write_word(input [31:0] value);
    begin
        @(negedge clk);
        wr_en  = 1;
        data_in = value;
        @(negedge clk);
        wr_en  = 0;
    end
    endtask

    // Task đọc data_out
    task read_data;
    begin
        @(negedge clk);
        rd_en = 1;
        @(negedge clk);
        rd_en = 0;
    end
    endtask

    initial begin
        $display("=== Testbench start ===");
        clk = 0;
        rst_n = 0;
        wr_en = 0;
        rd_en = 0;
        data_in = 32'h0;
        #20;
        rst_n = 1;
        #10;

        // ------------------------------------------------------
        // 1. Ghi chưa đủ 4 word mà đã đọc
        $display("\n[CASE 1] Ghi chưa đủ 4 word rồi đọc");
        write_word(32'hAAAA0001);
        write_word(32'hAAAA0002);
        read_data();  // đọc sớm
        #10;
        $display("Data_out = %h", data_out);

        // ------------------------------------------------------
        // 2. Ghi đủ và đọc bình thường
        $display("\n[CASE 2] Ghi đủ 4 word rồi đọc");
        write_word(32'hBBBB0001);
        write_word(32'hBBBB0002);
        write_word(32'hBBBB0003);
        write_word(32'hBBBB0004);
        read_data();
        #10;
        $display("Data_out = %h", data_out);

        // ------------------------------------------------------
        // 3. Ghi tràn (ghi >4 lần)
        $display("\n[CASE 3] Ghi tràn (5 lần)");
        write_word(32'hCCCC0001);
        write_word(32'hCCCC0002);
        write_word(32'hCCCC0003);
        write_word(32'hCCCC0004);
        write_word(32'hCCCC0005); // tràn, word_count vượt 3
        read_data();
        #10;
        $display("Data_out = %h", data_out);

        // ------------------------------------------------------
        // 4. Xuất xong ghi tiếp và xuất tiếp
        $display("\n[CASE 4] Xuất xong, ghi bộ dữ liệu mới rồi xuất tiếp");
        write_word(32'hDDDD0001);
        write_word(32'hDDDD0002);
        write_word(32'hDDDD0003);
        write_word(32'hDDDD0004);
        read_data();
        #10;
        $display("Data_out = %h", data_out);

        // ------------------------------------------------------
        $display("\n=== Testbench finish ===");
        #50;
        $stop;
    end

endmodule

`default_nettype wire
