// ----------------------------------------------------------------------------
// Copyright (c) 2020-2025 RVX contributors
//
// This work is licensed under the MIT License, see LICENSE file for details.
// SPDX-License-Identifier: MIT
// ----------------------------------------------------------------------------

//////////////////////////////////////////////////////////////////////////////////
// Company: ASIC LAB - UIT
// Engineer: Thinh Tran 
//
// Design Name: 
// Module Name: cpu2wb
// Project Name: RISC-V WISHBONE BUS
//////////////////////////////////////////////////////////////////////////////////
`timescale 10ns / 1ns
module cpu2wb (
    input  wire        clk_i,
    input  wire        rst_i,

    // CPU interface
    input  wire [31:0] rw_address,
    input  wire        read_request,
    output reg  [31:0] read_data,
    output reg         read_response,
    input  wire [31:0] write_data,
    input  wire [3:0]  write_strobe,
    input  wire        write_request,
    output reg         write_response,

    // Wishbone Master interface
    output reg  [31:0] wb_adr_o,
    output reg  [31:0] wb_dat_o,
    input  wire [31:0] wb_dat_i,
    output reg         wb_we_o,
    output reg  [3:0]  wb_sel_o,
    output reg         wb_stb_o,
    output reg         wb_cyc_o,
    input  wire        wb_ack_i
);

    // FSM states using parameter
    parameter STATE_IDLE     = 2'b00;
    parameter STATE_REQ_SENT = 2'b01;
    parameter STATE_WAIT_ACK = 2'b10;

    reg [1:0] state = 2'b00;

    // Latches for request info
    reg [31:0] latched_address = 32'b0;
    reg [31:0] latched_wdata   = 32'b0;
    reg [3:0]  latched_strobe  = 4'b0;
    reg        latched_we      = 1'b0;

    always @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            state           <= STATE_IDLE;
            wb_adr_o        <= 32'b0;
            wb_dat_o        <= 32'b0;
            wb_we_o         <= 1'b0;
            wb_sel_o        <= 4'b0;
            wb_stb_o        <= 1'b0;
            wb_cyc_o        <= 1'b0;
            read_data       <= 32'b0;
            read_response   <= 1'b0;
            write_response  <= 1'b0;
            latched_address <= 1'b0;
            latched_wdata   <= 1'b0;
            latched_strobe  <= 1'b0;
            latched_we      <= 1'b0;
        end else begin
            // Default pulse clearing
            read_response   <= 1'b0;
            write_response  <= 1'b0;

            case (state)
                STATE_IDLE: begin
                    wb_stb_o <= 1'b0;
                    wb_cyc_o <= 1'b0;
                    if (read_request) begin
                        latched_address <= rw_address;
                        latched_we      <= 1'b0;
                        state           <= STATE_REQ_SENT;
                    end else if (write_request) begin
                        latched_address <= rw_address;
                        latched_wdata   <= write_data;
                        latched_strobe  <= write_strobe;
                        latched_we      <= 1'b1;
                        state           <= STATE_REQ_SENT;
                    end
                end

                STATE_REQ_SENT: begin
                    wb_adr_o <= latched_address;
                    wb_we_o  <= latched_we;
                    wb_cyc_o <= 1'b1;
                    wb_stb_o <= 1'b1;
                    if (latched_we) begin
                        wb_dat_o <= latched_wdata;
                        wb_sel_o <= latched_strobe;
                    end else begin
                        wb_sel_o <= 4'b1111;
                    end
                    state <= STATE_WAIT_ACK;
                end

                STATE_WAIT_ACK: begin
                    if (wb_ack_i) begin
                        wb_stb_o <= 1'b0;
                        wb_cyc_o <= 1'b0;
                        if (wb_we_o == 1'b0) begin
                            read_data     <= wb_dat_i;
                            read_response <= 1'b1;
                        end else begin
                            write_response <= 1'b1;
                        end
                        state <= STATE_IDLE;
                    end
                end

                default: begin
                    state <= STATE_IDLE;
                end
            endcase
        end
    end

endmodule
