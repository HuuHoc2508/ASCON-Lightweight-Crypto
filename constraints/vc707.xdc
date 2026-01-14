######################################################################################################
##  Benchmark Constraints cho ASCON_WB trên Virtex-7 VC707
######################################################################################################

# ----------------------------------------------------------------------------
# 1. CLOCK INPUTS (Quan trọng nhất)
# ----------------------------------------------------------------------------
# Gán chân E19/E18 (System Clock 200MHz trên board VC707) vào port của module bạn
set_property PACKAGE_PIN E19 [get_ports clk_in_p]
set_property PACKAGE_PIN E18 [get_ports clk_in_n]

# Thiết lập chuẩn giao tiếp là LVDS (Low Voltage Differential Signaling)
set_property IOSTANDARD LVDS [get_ports clk_in_p]
set_property IOSTANDARD LVDS [get_ports clk_in_n]

# ----------------------------------------------------------------------------
# 2. TIMING CONSTRAINTS (Để Vivado tính toán Fmax/Slack)
# ----------------------------------------------------------------------------
# Board VC707 có thạch anh 200MHz (chu kỳ 5.0ns) nối vào E19/E18.
# Dòng lệnh này báo cho Vivado biết clock đầu vào là 200MHz.
# Vivado sẽ tự động tính timing qua bộ đệm IBUFDS vào bên trong logic.
create_clock -period 5.000 -name sys_clk_pin -waveform {0.000 2.500} [get_ports clk_in_p]

# ----------------------------------------------------------------------------
# 3. SYSTEM RESET (Tùy chọn)
# ----------------------------------------------------------------------------
# Nếu module của bạn có dùng chân "reset", bạn cần nối nó vào một nút bấm trên board.
# Trên VC707, nút bấm "CPU_RESET" là chân AV40.
# (Lưu ý: File cũ dùng AV35 là reset từ khe PCIe, không dùng được khi chạy độc lập)
set_property PACKAGE_PIN AV40 [get_ports reset]
set_property IOSTANDARD LVCMOS18 [get_ports reset]

# ----------------------------------------------------------------------------
# 4. CÁC CỔNG KHÁC (Wishbone)
# ----------------------------------------------------------------------------
# Lưu ý: Nếu ascon_wb là Top-Module, bạn không thể để lửng các dây Wishbone (wb_ack_o, wb_dat_i...).
# Vivado sẽ tối ưu hóa (opt_design) và xóa sạch mạch của bạn vì nghĩ nó "không làm gì cả".
#
# GIẢI PHÁP ĐỂ BENCHMARK KHÔNG BỊ XÓA MẠCH:
# Bạn cần đặt thuộc tính DONT_TOUCH hoặc gán các chân Output vào một đèn LED giả nào đó
# để đánh lừa Vivado giữ lại mạch.
# Ví dụ: Gán wb_ack_o ra một đèn LED (AM39 trên VC707)
# set_property PACKAGE_PIN AM39 [get_ports wb_ack_o]
# set_property IOSTANDARD LVCMOS18 [get_ports wb_ack_o]