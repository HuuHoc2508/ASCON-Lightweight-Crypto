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
// Module Name: wb_interconnect
// Project Name: RISC-V WISHBONE BUS
//////////////////////////////////////////////////////////////////////////////////
`timescale 10ns / 1ns
module wb_interconnect #(
  parameter NUM_DEVICES = 5
)(
  input  wire                         clk_i,                // clk_i input
  input  wire                         rst_i,                // rst_i input

  // Master interface
  input  wire [31:0]                  m_adr_i,             // Master address input
  input  wire [31:0]                  m_dat_i,             // Master data input
  output reg  [31:0]                  m_dat_o,             // Master data output
  input  wire                         m_we_i,              // Master write enable
  input  wire [3:0]                   m_sel_i,             // Master byte select
  input  wire                         m_stb_i,             // Master strobe input
  input  wire                         m_cyc_i,             // Master cycle input
  output reg                          m_ack_o,             // Master acknowledge output

  // Slaves interface
  output wire [31:0]                  s_adr_o,             // Slave address output
  output wire [31:0]                  s_dat_o,             // Slave data output
  input  wire [NUM_DEVICES*32-1:0]    s_dat_i,             // Slave data input
  output wire                         s_we_o,              // Slave write enable
  output wire [3:0]                   s_sel_o,             // Slave byte select
  output wire [NUM_DEVICES-1:0]       s_stb_o,             // Slave strobe output
  output wire [NUM_DEVICES-1:0]       s_cyc_o,             // Slave cycle output
  input  wire [NUM_DEVICES-1:0]       s_ack_i,             // Slave acknowledge input

  // Device base address and size
  input  wire [NUM_DEVICES*32-1:0]    device_base_addr,    // Device base addresses
  input  wire [NUM_DEVICES*32-1:0]    device_region_mask   // Device region sizes
);

  integer i;

  reg [NUM_DEVICES*32-1:0] device_mask_address = {NUM_DEVICES*32{1'b0}};
  reg [NUM_DEVICES-1:0]    device_sel = {NUM_DEVICES{1'b0}};
  reg [NUM_DEVICES-1:0]    device_sel_save = {NUM_DEVICES{1'b0}};
  reg [NUM_DEVICES-1:0]    ack_i_reg = {NUM_DEVICES{1'b0}};

  // Master to slave signal assignments
  assign s_adr_o = m_adr_i;
  assign s_dat_o = m_dat_i;
  assign s_we_o  = m_we_i;
  assign s_sel_o = m_sel_i;
  assign s_stb_o = device_sel & {NUM_DEVICES{m_stb_i}};
  assign s_cyc_o = device_sel & {NUM_DEVICES{m_cyc_i}};

  // Address decoding
  always @(*) begin
    for (i = 0; i < NUM_DEVICES; i = i + 1) begin
      device_mask_address[i*32 +: 32] = ~(device_region_mask[i*32 +: 32] - 1);
      if ((m_adr_i & device_mask_address[i*32 +: 32]) == device_base_addr[i*32 +: 32])
        device_sel[i] = 1'b1;
      else
        device_sel[i] = 1'b0;
    end
  end

  // Save device selection on valid transaction
  always @(posedge clk_i) begin
    if (rst_i) begin
      device_sel_save <= {NUM_DEVICES{1'b0}};
      ack_i_reg <= 0;
    end
    else 
        if ((m_stb_i && m_cyc_i) && (|device_sel)) begin
          device_sel_save <= device_sel;
          ack_i_reg <= s_ack_i; 
        end
    else
      device_sel_save <= {NUM_DEVICES{1'b0}};
  end

  // Slave response selection
  always @(*) begin
    m_dat_o <= 32'b0;
    m_ack_o <= 1'b0;
    for (i = 0; i < NUM_DEVICES; i = i + 1) begin
      if (device_sel_save[i]) begin
        m_dat_o <= s_dat_i[i*32 +: 32];
        m_ack_o <= ack_i_reg[i];
      end
    end
  end

endmodule