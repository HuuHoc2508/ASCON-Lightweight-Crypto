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
// Module Name: mcu
// Project Name: RISC-V WISHBONE BUS
//////////////////////////////////////////////////////////////////////////////////
// CPU wrapper wishbone bus                                                     //
// RISCV_CPU <-> CPU2WB <-> WB_inter <-> WB_Device                              //
//////////////////////////////////////////////////////////////////////////////////

`timescale 10ns / 1ns
module mcu #(
    // Frequency of 'clk_i' signal
    parameter CLOCK_FREQUENCY = 50000000  ,
    // Desired baud rate for UART unit
    parameter UART_BAUD_RATE = 9600       ,
    // Memory size in bytes - must be a power of 2
    parameter MEMORY_SIZE = 8192          ,
    // Text file with program and data (one hex value per line)
    parameter MEMORY_INIT_FILE = ""       ,
    // Address of the first instruction to fetch from memory
    parameter BOOT_ADDRESS = 32'h00000000 ,
    // Number of available I/O ports
    parameter GPIO_WIDTH = 32              ,
    // Number of CS (Chip Select) pins for the SPI controller
    parameter SPI_NUM_CHIP_SELECT = 1
    
    ) (
    input   wire                            clk_i         ,
    input   wire                            rst_i         ,
    input   wire                            halt          ,
    // UART physical
    input   wire                            uart_rx       ,
    output  wire                            uart_tx       ,
    // SPI physical
    output  wire                            sclk          ,
    output  wire                            pico          ,
    input   wire                            poci          ,
    output  wire  [SPI_NUM_CHIP_SELECT-1:0] cs            ,    
	 // GPIO physical
	 input   wire  [GPIO_WIDTH-1:0]          gpio_input    ,
	 output  wire  [GPIO_WIDTH-1:0]          gpio_oe       ,
	 output  wire  [GPIO_WIDTH-1:0]          gpio_output
    
    );
    
    
    localparam NUM_WB_DEVICES   = 6;
    localparam D0_RAM           = 0;
    localparam D1_UART          = 1;
    localparam D2_TIMER         = 2;
    localparam D3_GPIO          = 3;
    localparam D4_SPI           = 4;
    localparam D5_ACCE          = 5;
    
    // RVX 32-bit Processor (Manager Device) <=> System Bus
    
    wire  [31:0]                manager_rw_address      ;
    wire  [31:0]                manager_read_data       ;
    wire                        manager_read_request    ;
    wire                        manager_read_response   ;
    wire  [31:0]                manager_write_data      ;
    wire  [3:0 ]                manager_write_strobe    ;
    wire                        manager_write_request   ;
    wire                        manager_write_response  ;
    
    // Wishbone System Bus <=> Managed Devices
    
    wire [31:0]                     wb_adr_o, wb_dat_i, wb_dat_o;
    wire [3:0]                      wb_sel_o;
    wire                            wb_we_o, wb_stb_o, wb_cyc_o, wb_ack_i;
    wire [31:0]                     s_adr_o, s_dat_o;
    wire [NUM_WB_DEVICES*32-1:0]    s_dat_i;
    wire [3:0]                      s_sel_o;
    wire [NUM_WB_DEVICES-1:0]       s_stb_o, s_cyc_o, s_ack_i;
	 wire										s_we_o;
    wire [NUM_WB_DEVICES*32-1:0]    wb_device_base_addr;
    wire [NUM_WB_DEVICES*32-1:0]    wb_device_region_mask;
    
    wire 							      s_stb_o_ram, s_cyc_o_ram, s_ack_i_ram;
	 wire 								   s_stb_o_uart, s_cyc_o_uart, s_ack_i_uart;
	 wire 								   s_stb_o_spi, s_cyc_o_spi, s_ack_i_spi;
	 wire 								   s_stb_o_gpio, s_cyc_o_gpio, s_ack_i_gpio;
	 wire 								   s_stb_o_timer, s_cyc_o_timer, s_ack_i_timer;
    wire 								   s_stb_o_acce, s_cyc_o_acce, s_ack_i_acce;
    //wb_interconnect
    assign wb_device_base_addr[32*D0_RAM   +: 32]      = 32'h0000_0000;
    assign wb_device_region_mask[32*D0_RAM +: 32]      = MEMORY_SIZE; //32768
    assign wb_device_base_addr[32*D1_UART   +: 32]     = 32'h8000_0000;
    assign wb_device_region_mask[32*D1_UART +: 32]     = 256;
    assign wb_device_base_addr[32*D2_TIMER +: 32]      = 32'h8001_0000;
    assign wb_device_region_mask[32*D2_TIMER +: 32]    = 32;
    assign wb_device_base_addr[32*D3_GPIO   +: 32]     = 32'h8002_0000;
    assign wb_device_region_mask[32*D3_GPIO +: 32]     = 32;
    assign wb_device_base_addr[32*D4_SPI    +: 32]     = 32'h8003_0000;
    assign wb_device_region_mask[32*D4_SPI  +: 32]     = 32;
    assign wb_device_base_addr[32*D5_ACCE    +: 32]     = 32'h8004_0000;
    assign wb_device_region_mask[32*D5_ACCE  +: 32]     = 32; 
     
    // Real-time clock (unused)
    
    wire  [63:0] real_time_clock;
    
    assign real_time_clock = 64'b0;
    
    // Interrupt signals
    
    wire  [15:0] irq_fast;
    wire         irq_external;
    wire         irq_timer;
    wire         irq_software;
    
    wire  [15:0] irq_fast_response;
    wire         irq_external_response;
    wire         irq_timer_response;
    wire         irq_software_response;
    
    wire         irq_uart;
    wire         irq_uart_response;
    
    // Interrupt signals map
    
    assign irq_fast               = {15'b0, irq_uart}; // Give UART interrupts the highest priority
    assign irq_uart_response      = irq_fast_response[0];
    
    assign irq_external           = 1'b0; // unused
    assign irq_software           = 1'b0; // unused

    // Instantiate rvx_core
    rvx_core_wb #(
        .BOOT_ADDRESS(BOOT_ADDRESS)
    ) rvx_core_inst (
    
    // Global Signal       
    .clk_i                          (clk_i                              ),
    .rst_i                          (rst_i                              ),
    .halt                           (halt                               ),
    
    // IO interface
    
    .rw_address                     (manager_rw_address                 ),
    .read_data                      (manager_read_data                  ),
    .read_request                   (manager_read_request               ),
    .read_response                  (manager_read_response              ),
    .write_data                     (manager_write_data                 ),
    .write_strobe                   (manager_write_strobe               ),
    .write_request                  (manager_write_request              ),
    .write_response                 (manager_write_response             ),
    
    // Interrupt request signals
    
    .irq_fast                       (irq_fast                           ),
    .irq_external                   (irq_external                       ),
    .irq_timer                      (irq_timer                          ),
    .irq_software                   (irq_software                       ),
    
    // Interrupt response signals
    
    .irq_fast_response              (irq_fast_response                  ),
    .irq_external_response          (irq_external_response              ),
    .irq_timer_response             (irq_timer_response                 ),
    .irq_software_response          (irq_software_response              ),
    
    // Real Time clk_i
    
    .real_time_clock                (real_time_clock                    )
    
    );
    
    // Instantiate cpu2wb
    cpu2wb cpu2wb (
    .clk_i                          (clk_i                              ),
    .rst_i                          (rst_i                              ),
    // CPU IO interface
    .rw_address                     (manager_rw_address                 ),
    .read_data                      (manager_read_data                  ),
    .read_request                   (manager_read_request               ),
    .read_response                  (manager_read_response              ),
    .write_data                     (manager_write_data                 ),
    .write_strobe                   (manager_write_strobe               ),
    .write_request                  (manager_write_request              ),
    .write_response                 (manager_write_response             ),
    
    //CPU WB interface
    .wb_adr_o                       (wb_adr_o                           ),
    .wb_dat_o                       (wb_dat_o                           ),
    .wb_dat_i                       (wb_dat_i                           ),
    .wb_we_o                        (wb_we_o                            ),
    .wb_sel_o                       (wb_sel_o                           ),
    .wb_stb_o                       (wb_stb_o                           ),
    .wb_cyc_o                       (wb_cyc_o                           ),
    .wb_ack_i                       (wb_ack_i                           )
    );
    
    // Instantiate wb_interconnect
    wb_interconnect #(
        .NUM_DEVICES(NUM_WB_DEVICES)
    ) wb_intercon_inst (
    .clk_i                      (clk_i                              ),
    .rst_i                      (rst_i                              ),
    // Master IO    
    .m_adr_i                    (wb_adr_o                           ),
    .m_dat_i                    (wb_dat_o                           ),
    .m_dat_o                    (wb_dat_i                           ),
    .m_we_i                     (wb_we_o                            ),
    .m_sel_i                    (wb_sel_o                           ),
    .m_stb_i                    (wb_stb_o                           ),
    .m_cyc_i                    (wb_cyc_o                           ),
    .m_ack_o                    (wb_ack_i                           ),
    //Slave IO
    .s_adr_o                    (s_adr_o                            ),
    .s_dat_o                    (s_dat_o                            ),
    .s_dat_i                    (s_dat_i                            ),
    .s_we_o                     (s_we_o                             ),
    .s_sel_o                    (s_sel_o                            ),
    .s_stb_o                    (s_stb_o                            ),
    .s_cyc_o                    (s_cyc_o                            ),
    .s_ack_i                    (s_ack_i                            ),
    .device_base_addr           (wb_device_base_addr                ),
    .device_region_mask         (wb_device_region_mask              )
    );
    
    assign s_stb_o_ram = s_stb_o[D0_RAM];
    assign s_cyc_o_ram = s_cyc_o[D0_RAM];
    assign s_ack_i[D0_RAM] = s_ack_i_ram;
    
    // Instantiate wb_RAM
    wb_ram #(
    .MEMORY_SIZE                (MEMORY_SIZE                        ),
    .MEMORY_INIT_FILE           (MEMORY_INIT_FILE                   )
    ) wb_ram_inst (
    .clk_i                      (clk_i                              ),
    .rst_i                      (rst_i                              ),
    
    .adr_i                      (s_adr_o                            ),
    .dat_i                      (s_dat_o                            ),
    .dat_o                      (s_dat_i[32*D0_RAM +: 32]           ),
    .we_i                       (s_we_o                             ),
    .sel_i                      (s_sel_o                            ),
    .stb_i                      (s_stb_o_ram                        ),
    .cyc_i                      (s_cyc_o_ram                        ),
    .ack_o                      (s_ack_i_ram                        )
    );
    
    // UART signals
    assign s_stb_o_uart = s_stb_o[D1_UART];
    assign s_cyc_o_uart = s_cyc_o[D1_UART];
    assign s_ack_i[D1_UART] = s_ack_i_uart;
    
    // Instantiate wb_uart_bau
    wb_uart_bau #                   (
    .CLOCK_FREQUENCY            (CLOCK_FREQUENCY                    ),
    .UART_BAUD_RATE             (UART_BAUD_RATE                     )
    ) wb_uart_inst (
    .uart_rx                    (uart_rx                            ),
    .uart_tx                    (uart_tx                            ),
    .clk_i                      (clk_i                              ),
    .rst_i                      (rst_i                              ),
    .adr_i                      (s_adr_o[4:0]                       ),
    .dat_i                      (s_dat_o                            ),
    .dat_o                      (s_dat_i[32*D1_UART +: 32]          ),
    .we_i                       (s_we_o                             ),
    .sel_i                      (s_sel_o                            ),
    .stb_i                      (s_stb_o_uart                       ),
    .cyc_i                      (s_cyc_o_uart                       ),
    .ack_o                      (s_ack_i_uart                       ),
    
    // Interrupt signaling
    .uart_irq                   (irq_uart                           ),
    .uart_irq_response          (irq_uart_response                  )
    );
    
    // Timer signals
    assign s_stb_o_timer = s_stb_o[D2_TIMER];
    assign s_cyc_o_timer = s_cyc_o[D2_TIMER];
    assign s_ack_i[D2_TIMER] = s_ack_i_timer;
    // Instantiate wb_timer
    wb_timer wb_timer_inst (
    .clk_i                          (clk_i                                  ),
    .rst_i                          (rst_i                                  ),
    .adr_i                          (s_adr_o[4:0]                           ),
    .dat_i                          (s_dat_o                                ),
    .dat_o                          (s_dat_i[32*D2_TIMER +: 32]             ),
    .we_i                           (s_we_o                                 ),
    .sel_i                          (s_sel_o                                ),
    .stb_i                          (s_stb_o_timer                          ),
    .cyc_i                          (s_cyc_o_timer                          ),
    .ack_o                          (s_ack_i_timer                          ),
    
    // Interrupt signaling
    .irq                            (irq_timer                              )
    
    ); 
    // GPIO signals
    assign s_stb_o_gpio = s_stb_o[D3_GPIO];
    assign s_cyc_o_gpio = s_cyc_o[D3_GPIO];
    assign s_ack_i[D3_GPIO] = s_ack_i_gpio;   
    // Instantiate wb_gpio
    wb_gpio #                           (
    .GPIO_WIDTH                     (GPIO_WIDTH                             )
    ) wb_gpio_inst                      (
    .clk_i                          (clk_i                                  ),
    .rst_i                          (rst_i                                  ),
    .adr_i                          (s_adr_o[4:0]                           ),
    .dat_i                          (s_dat_o                                ),
    .dat_o                          (s_dat_i[32*D3_GPIO +: 32]              ),
    .we_i                           (s_we_o                                 ),
    .sel_i                          (s_sel_o                                ),
    .stb_i                          (s_stb_o_gpio                           ),
    .cyc_i                          (s_cyc_o_gpio                           ),
    .ack_o                          (s_ack_i_gpio                           ),
    .gpio_input                     (gpio_input                             ),
    .gpio_oe                        (gpio_oe                                ),
    .gpio_output                    (gpio_output                            )
    );
    
     assign s_stb_o_spi = s_stb_o[D4_SPI];
     assign s_cyc_o_spi = s_cyc_o[D4_SPI];
     assign s_ack_i[D4_SPI] = s_ack_i_spi;
    
    // Instantiate wb_spi
    wb_spi #(
    .SPI_NUM_CHIP_SELECT(SPI_NUM_CHIP_SELECT)
    ) wb_spi_inst (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .adr_i(s_adr_o[4:0]),
    .dat_i(s_dat_o[7:0]),
    .dat_o(s_dat_i[32*D4_SPI +: 32]),
    .we_i(s_we_o),
    .sel_i(s_sel_o),
    .stb_i(s_stb_o_spi),
    .cyc_i(s_cyc_o_spi),
    .ack_o(s_ack_i_spi),
    .sclk(sclk),
    .pico(pico),
    .poci(poci),
    .cs(cs)
    );
    
    
     assign s_stb_o_acce = s_stb_o[D5_ACCE];
     assign s_cyc_o_acce = s_cyc_o[D5_ACCE];
     assign s_ack_i[D5_ACCE] = s_ack_i_acce;
     
    //ADD your device
    ascon_wb accelerator_wisbone_inst(
    // System Inputs
    .clk(clk_i),
    .reset(rst_i), // System reset (active high)

    // Wishbone Slave Interface (B4 compliant)
    .wb_cyc_i(s_cyc_o_acce),    // Cycle valid
    .wb_stb_i(s_stb_o_acce),    // Strobe (address/data valid)
    .wb_ack_o(s_ack_i_acce),   // Acknowledge
    
    .wb_we_i(s_we_o),     // Write enable (1=write, 0=read)
    .wb_adr_i({26'b0,s_adr_o[5:0]}), // Address
    .wb_dat_i(s_dat_o), // Write data
    .wb_sel_i(s_sel_o), // Byte select (assuming 32-bit data bus)
    .wb_dat_o(s_dat_i[32*D5_ACCE +: 32]) // Read data
);
    
    // Avoid warnings about intentionally unused pins/wires
    wire unused_ok =
    &{1'b0,
    irq_external,
    irq_software,
    irq_external_response,
    irq_software_response,
    irq_timer_response,
    irq_fast_response[15:1],
    1'b0};
    
 endmodule
