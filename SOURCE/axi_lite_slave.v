module axi_lite_slave #(
    parameter ADDR_WIDTH = 4,                   // 16 bytes address space
    parameter DATA_WIDTH = 32,                  // 32-bit data bus
    parameter CLK_FREQ_HZ = 100_000_000,        // 100 MHz
    parameter NUM_LEDS = 4                      // Number of LEDs
) (
    //==========================================================================
    // AXI4-Lite Slave Interface
    //==========================================================================
    // Global signals
    input  wire                     S_AXI_ACLK,
    input  wire                     S_AXI_ARESETN,
    
    // Write address channel
    input  wire [ADDR_WIDTH-1:0]    S_AXI_AWADDR,
    input  wire [2:0]               S_AXI_AWPROT,
    input  wire                     S_AXI_AWVALID,
    output wire                     S_AXI_AWREADY,
    
    // Write data channel
    input  wire [DATA_WIDTH-1:0]    S_AXI_WDATA,
    input  wire [DATA_WIDTH/8-1:0]  S_AXI_WSTRB,
    input  wire                     S_AXI_WVALID,
    output wire                     S_AXI_WREADY,
    
    // Write response channel
    output wire [1:0]               S_AXI_BRESP,
    output wire                     S_AXI_BVALID,
    input  wire                     S_AXI_BREADY,
    
    // Read address channel
    input  wire [ADDR_WIDTH-1:0]    S_AXI_ARADDR,
    input  wire [2:0]               S_AXI_ARPROT,
    input  wire                     S_AXI_ARVALID,
    output wire                     S_AXI_ARREADY,
    
    // Read data channel
    output wire [DATA_WIDTH-1:0]    S_AXI_RDATA,
    output wire [1:0]               S_AXI_RRESP,
    output wire                     S_AXI_RVALID,
    input  wire                     S_AXI_RREADY,
    
    //==========================================================================
    // External I/O Ports
    //==========================================================================
    // LED outputs
    output wire [NUM_LEDS-1:0]      LED,
    
    // 7-segment display outputs
    output wire [6:0]               SEG_CATHODE,
    output wire [3:0]               SEG_ANODE,
    
    // Interrupt output to PS
    output wire                     IRQ_OUT,
    
    // External interrupt input (e.g., button)
    input  wire                     EXT_IRQ_IN
);

    //==========================================================================
    // Internal Wires - AXI Interface to Register Bank
    //==========================================================================
    wire                     reg_wr_en;
    wire [ADDR_WIDTH-1:0]    reg_wr_addr;
    wire [DATA_WIDTH-1:0]    reg_wr_data;
    wire [DATA_WIDTH/8-1:0]  reg_wr_strb;
    
    wire                     reg_rd_en;
    wire [ADDR_WIDTH-1:0]    reg_rd_addr;
    wire [DATA_WIDTH-1:0]    reg_rd_data;
    wire                     reg_rd_valid;
    
    //==========================================================================
    // Internal Wires - Register Bank to Peripherals
    //==========================================================================
    wire [7:0]               led_ctrl_reg;
    wire [15:0]              sevenseg_data_reg;
    wire                     irq_status_reg;
    
    // Interrupt pulse from IRQ controller
    wire                     irq_pulse;
    
    //==========================================================================
    // AXI4-Lite Interface Module
    //==========================================================================
    axi_lite_if #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_axi_if (
        // Global signals
        .S_AXI_ACLK     (S_AXI_ACLK),
        .S_AXI_ARESETN  (S_AXI_ARESETN),
        
        // Write address channel
        .S_AXI_AWADDR   (S_AXI_AWADDR),
        .S_AXI_AWPROT   (S_AXI_AWPROT),
        .S_AXI_AWVALID  (S_AXI_AWVALID),
        .S_AXI_AWREADY  (S_AXI_AWREADY),
        
        // Write data channel
        .S_AXI_WDATA    (S_AXI_WDATA),
        .S_AXI_WSTRB    (S_AXI_WSTRB),
        .S_AXI_WVALID   (S_AXI_WVALID),
        .S_AXI_WREADY   (S_AXI_WREADY),
        
        // Write response channel
        .S_AXI_BRESP    (S_AXI_BRESP),
        .S_AXI_BVALID   (S_AXI_BVALID),
        .S_AXI_BREADY   (S_AXI_BREADY),
        
        // Read address channel
        .S_AXI_ARADDR   (S_AXI_ARADDR),
        .S_AXI_ARPROT   (S_AXI_ARPROT),
        .S_AXI_ARVALID  (S_AXI_ARVALID),
        .S_AXI_ARREADY  (S_AXI_ARREADY),
        
        // Read data channel
        .S_AXI_RDATA    (S_AXI_RDATA),
        .S_AXI_RRESP    (S_AXI_RRESP),
        .S_AXI_RVALID   (S_AXI_RVALID),
        .S_AXI_RREADY   (S_AXI_RREADY),
        
        // Register interface
        .reg_wr_en      (reg_wr_en),
        .reg_wr_addr    (reg_wr_addr),
        .reg_wr_data    (reg_wr_data),
        .reg_wr_strb    (reg_wr_strb),
        
        .reg_rd_en      (reg_rd_en),
        .reg_rd_addr    (reg_rd_addr),
        .reg_rd_data    (reg_rd_data),
        .reg_rd_valid   (reg_rd_valid)
    );
    
    //==========================================================================
    // Register Bank Module
    //==========================================================================
    reg_bank #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_reg_bank (
        .clk                (S_AXI_ACLK),
        .rst_n              (S_AXI_ARESETN),
        
        // Write interface
        .wr_en              (reg_wr_en),
        .wr_addr            (reg_wr_addr),
        .wr_data            (reg_wr_data),
        .wr_strb            (reg_wr_strb),
        
        // Read interface
        .rd_en              (reg_rd_en),
        .rd_addr            (reg_rd_addr),
        .rd_data            (reg_rd_data),
        .rd_valid           (reg_rd_valid),
        
        // Peripheral outputs
        .led_ctrl_reg       (led_ctrl_reg),
        .sevenseg_data_reg  (sevenseg_data_reg),
        .irq_status_reg     (irq_status_reg),
        
        // Interrupt input
        .irq_set            (irq_pulse)
    );
    
    //==========================================================================
    // LED Driver Module
    //==========================================================================
    led_driver #(
        .NUM_LEDS       (NUM_LEDS),
        .ENABLE_PWM     (0),                    // Direct mode (no PWM)
        .PWM_RESOLUTION (8),
        .CLK_FREQ_HZ    (CLK_FREQ_HZ)
    ) u_led_driver (
        .clk            (S_AXI_ACLK),
        .rst_n          (S_AXI_ARESETN),
        .led_ctrl       (led_ctrl_reg[NUM_LEDS-1:0]),
        .pwm_duty       (8'd128),               // Unused in direct mode
        .LED            (LED)
    );
    
    //==========================================================================
    // Seven-Segment Multiplexer Module
    //==========================================================================
    sevenseg_mux #(
        .CLK_FREQ_HZ      (CLK_FREQ_HZ),
        .REFRESH_RATE_HZ  (1000)                // 1 kHz per digit
    ) u_sevenseg_mux (
        .clk              (S_AXI_ACLK),
        .rst_n            (S_AXI_ARESETN),
        .seg_data         (sevenseg_data_reg),
        .seg_cathode      (SEG_CATHODE),
        .seg_anode        (SEG_ANODE)
    );
    
    //==========================================================================
    // Interrupt Controller Module
    //==========================================================================
    irq_ctrl #(
        .CLK_FREQ_HZ  (CLK_FREQ_HZ),
        .DEBOUNCE_MS  (20)                      // 20ms debounce
    ) u_irq_ctrl (
        .clk            (S_AXI_ACLK),
        .rst_n          (S_AXI_ARESETN),
        .ext_irq_in     (EXT_IRQ_IN),
        .irq_pulse_out  (irq_pulse)
    );
    
    //==========================================================================
    // Interrupt Output Assignment
    //==========================================================================
    assign IRQ_OUT = irq_status_reg;

endmodule
