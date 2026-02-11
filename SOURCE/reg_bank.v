endmodule


`timescale 1ns / 1ps

// Memory Map:
//   0x00: LED Control Register    [7:0] - LED control (bits [3:0] used)
//   0x04: 7-Segment Data Register [15:0] - Four hex digits
//   0x08: IRQ Status Register     [0] - Interrupt status (write 1 to clear)
//   0x0C: Reserved


module reg_bank #(
    parameter ADDR_WIDTH = 4,    // 16 bytes of address space
    parameter DATA_WIDTH = 32    // 32-bit registers
)(
    // Clock and Reset
    input  wire                     clk,
    input  wire                     rst_n,
    
    // Register Write Interface
    input  wire                     wr_en,
    input  wire [ADDR_WIDTH-1:0]    wr_addr,
    input  wire [DATA_WIDTH-1:0]    wr_data,
    input  wire [DATA_WIDTH/8-1:0]  wr_strb,    // Byte enable strobes
    
    // Register Read Interface
    input  wire                     rd_en,
    input  wire [ADDR_WIDTH-1:0]    rd_addr,
    output reg  [DATA_WIDTH-1:0]    rd_data,
    output reg                      rd_valid,
    
    // Peripheral Outputs
    output wire [7:0]               led_ctrl_reg,
    output wire [15:0]              sevenseg_data_reg,
    output wire                     irq_status_reg,
    
    // Interrupt Input (from irq_ctrl)
    input  wire                     irq_set
);

    //=========================================================================
    // Register Definitions
    //=========================================================================
    reg [31:0] reg_0x00;  // LED Control Register
    reg [31:0] reg_0x04;  // 7-Segment Data Register
    reg [31:0] reg_0x08;  // IRQ Status Register
    reg [31:0] reg_0x0C;  // Reserved Register

    //=========================================================================
    // Register Write Logic with Byte Enable
    //=========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers to 0
            reg_0x00 <= 32'h0;
            reg_0x04 <= 32'h0;
            reg_0x08 <= 32'h0;
            reg_0x0C <= 32'h0;
        end else begin
            // IRQ set has priority (hardware sets the bit)
            if (irq_set) begin
                reg_0x08[0] <= 1'b1;
            end
            
            // Handle register writes with byte enables
            if (wr_en) begin
                case (wr_addr[3:2])  // Word-aligned addressing
                    2'b00: begin  // Address 0x00 - LED Control
                        if (wr_strb[0]) reg_0x00[7:0]   <= wr_data[7:0];
                        if (wr_strb[1]) reg_0x00[15:8]  <= wr_data[15:8];
                        if (wr_strb[2]) reg_0x00[23:16] <= wr_data[23:16];
                        if (wr_strb[3]) reg_0x00[31:24] <= wr_data[31:24];
                    end
                    
                    2'b01: begin  // Address 0x04 - 7-Segment Data
                        if (wr_strb[0]) reg_0x04[7:0]   <= wr_data[7:0];
                        if (wr_strb[1]) reg_0x04[15:8]  <= wr_data[15:8];
                        if (wr_strb[2]) reg_0x04[23:16] <= wr_data[23:16];
                        if (wr_strb[3]) reg_0x04[31:24] <= wr_data[31:24];
                    end
                    
                    2'b10: begin  // Address 0x08 - IRQ Status (write 1 to clear)
                        if (wr_strb[0] && wr_data[0]) begin
                            reg_0x08[0] <= 1'b0;  // Clear interrupt on write-1
                        end
                        // Other bits are reserved, ignore writes
                    end
                    
                    2'b11: begin  // Address 0x0C - Reserved
                        if (wr_strb[0]) reg_0x0C[7:0]   <= wr_data[7:0];
                        if (wr_strb[1]) reg_0x0C[15:8]  <= wr_data[15:8];
                        if (wr_strb[2]) reg_0x0C[23:16] <= wr_data[23:16];
                        if (wr_strb[3]) reg_0x0C[31:24] <= wr_data[31:24];
                    end
                endcase
            end
        end
    end

    //=========================================================================
    // Register Read Logic
    //=========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_data  <= 32'h0;
            rd_valid <= 1'b0;
        end else begin
            rd_valid <= rd_en;  // Read valid one cycle after read enable
            
            if (rd_en) begin
                case (rd_addr[3:2])  // Word-aligned addressing
                    2'b00:   rd_data <= reg_0x00;  // LED Control
                    2'b01:   rd_data <= reg_0x04;  // 7-Segment Data
                    2'b10:   rd_data <= reg_0x08;  // IRQ Status
                    2'b11:   rd_data <= reg_0x0C;  // Reserved
                    default: rd_data <= 32'hDEADBEEF;  // Invalid address
                endcase
            end
        end
    end

    //=========================================================================
    // Output Assignments to Peripherals
    //=========================================================================
    assign led_ctrl_reg       = reg_0x00[7:0];   // Only lower 8 bits used
    assign sevenseg_data_reg  = reg_0x04[15:0];  // Only lower 16 bits used
    assign irq_status_reg     = reg_0x08[0];     // Only bit 0 used

endmodule
