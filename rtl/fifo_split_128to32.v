`timescale 1ns / 1ps
`default_nettype none

module fifo_split_128to32 #(
    parameter FIFO_DEPTH = 16  // Số phần tử 32-bit tối đa
)(
    input  wire         clk,
    input  wire         rst_n,

    input  wire [127:0] data_in,  // Dữ liệu 128-bit cần tách
    input  wire         load,     // Kích hoạt nạp toàn bộ data_in
    input  wire         rd_en,    // Kích hoạt đọc FIFO
    input  wire         mode,     // 0 = chỉ nạp 64-bit MSB, 1 = nạp đủ 128-bit

    output reg  [31:0] data_out, // Dữ liệu đọc ra
    output wire        empty,
    output wire        full,
    output reg         valid      // Bật 1 chu kỳ khi data_out hợp lệ
);

    // =====================================================
    // FIFO memory (32-bit)
    // =====================================================
    reg [31:0] fifo_mem [0:FIFO_DEPTH-1];
    reg [$clog2(FIFO_DEPTH)-1:0] wr_ptr;
    reg [$clog2(FIFO_DEPTH)-1:0] rd_ptr;
    reg [$clog2(FIFO_DEPTH+1)-1:0] fifo_count;

    assign empty = (fifo_count == 0);
    // Logic Full nên xem xét kỹ hơn: Full khi không đủ chỗ nạp tiếp theo
    // Nhưng tạm thời giữ nguyên logic so sánh count của bạn
    assign full  = (fifo_count == FIFO_DEPTH); 

    // Biến tạm để tính toán số lượng thêm vào/bớt ra
    reg [2:0] push_count;
    reg       pop_count;

    // =====================================================
    // LOGIC GỘP (SINGLE PROCESS)
    // =====================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr     <= 0;
            rd_ptr     <= 0;
            fifo_count <= 0;
            data_out   <= 32'd0;
            valid      <= 1'b0;
            push_count <= 0;
            pop_count  <= 0;
        end else begin
            // -------------------------------------------------
            // 1. Xử lý WRITE (Nạp vào)
            // -------------------------------------------------
            push_count = 0; // Reset biến tạm
            if (load) begin
                if (mode == 1'b0) begin 
                    // --- Mode 0: Nạp 64-bit (2 từ) ---
                    if (fifo_count <= FIFO_DEPTH - 2) begin
                        fifo_mem[wr_ptr] <= data_in[127:96];
                        fifo_mem[(wr_ptr + 1) % FIFO_DEPTH] <= data_in[95:64];

                        // Cập nhật Write Pointer
                        if (wr_ptr + 2 >= FIFO_DEPTH)
                            wr_ptr <= (wr_ptr + 2) - FIFO_DEPTH;
                        else
                            wr_ptr <= wr_ptr + 2;

                        push_count = 2; // Đánh dấu là đã nạp 2
                    end
                end else begin
                    // --- Mode 1: Nạp 128-bit (4 từ) ---
                    if (fifo_count <= FIFO_DEPTH - 4) begin
                        fifo_mem[wr_ptr] <= data_in[127:96];
                        fifo_mem[(wr_ptr + 1) % FIFO_DEPTH] <= data_in[95:64];
                        fifo_mem[(wr_ptr + 2) % FIFO_DEPTH] <= data_in[63:32];
                        fifo_mem[(wr_ptr + 3) % FIFO_DEPTH] <= data_in[31:0];

                        // Cập nhật Write Pointer
                        if (wr_ptr + 4 >= FIFO_DEPTH)
                            wr_ptr <= (wr_ptr + 4) - FIFO_DEPTH;
                        else
                            wr_ptr <= wr_ptr + 4;

                        push_count = 4; // Đánh dấu là đã nạp 4
                    end
                end
            end

            // -------------------------------------------------
            // 2. Xử lý READ (Đọc ra)
            // Lưu ý: Đã chuyển về posedge clk để đồng bộ
            // -------------------------------------------------
            pop_count = 0; // Reset biến tạm
            valid <= 1'b0; // Default valid

            if (rd_en && fifo_count > 0) begin
                data_out <= fifo_mem[rd_ptr];
                valid <= 1'b1;

                // Cập nhật Read Pointer
                if (rd_ptr == FIFO_DEPTH - 1)
                    rd_ptr <= 0;
                else
                    rd_ptr <= rd_ptr + 1;
                
                pop_count = 1; // Đánh dấu là đã đọc 1
            end

            // -------------------------------------------------
            // 3. Cập nhật FIFO COUNT (QUAN TRỌNG NHẤT)
            // Logic: count_mới = count_cũ + số_lượng_nạp - số_lượng_đọc
            // -------------------------------------------------
            fifo_count <= fifo_count + push_count - pop_count;
        end
    end

endmodule