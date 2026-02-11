module axi_lite_if #(
    parameter ADDR_WIDTH = 4,
    parameter DATA_WIDTH = 32
)(
    // Global Signals
    input  wire                     S_AXI_ACLK,
    input  wire                     S_AXI_ARESETN,
    
    // Write Address Channel (AW)
    
    input  wire [ADDR_WIDTH-1:0]    S_AXI_AWADDR,
    input  wire [2:0]               S_AXI_AWPROT,   // Protection type (unused)
    input  wire                     S_AXI_AWVALID,
    output reg                      S_AXI_AWREADY,
    
    // Write Data Channel (W)
    
    input  wire [DATA_WIDTH-1:0]    S_AXI_WDATA,
    input  wire [DATA_WIDTH/8-1:0]  S_AXI_WSTRB,    // Byte strobes
    input  wire                     S_AXI_WVALID,
    output reg                      S_AXI_WREADY,
    
    // Write Response Channel (B)

    output reg  [1:0]               S_AXI_BRESP,
    output reg                      S_AXI_BVALID,
    input  wire                     S_AXI_BREADY,
    
    // Read Address Channel (AR)

    input  wire [ADDR_WIDTH-1:0]    S_AXI_ARADDR,
    input  wire [2:0]               S_AXI_ARPROT,   // Protection type (unused)
    input  wire                     S_AXI_ARVALID,
    output reg                      S_AXI_ARREADY,
    
    // Read Data Channel (R)

    output reg  [DATA_WIDTH-1:0]    S_AXI_RDATA,
    output reg  [1:0]               S_AXI_RRESP,
    output reg                      S_AXI_RVALID,
    input  wire                     S_AXI_RREADY,
    
    // Register Bank Interface

    output reg                      reg_wr_en,
    output reg  [ADDR_WIDTH-1:0]    reg_wr_addr,
    output reg  [DATA_WIDTH-1:0]    reg_wr_data,
    output reg  [DATA_WIDTH/8-1:0]  reg_wr_strb,
    
    output reg                      reg_rd_en,
    output reg  [ADDR_WIDTH-1:0]    reg_rd_addr,
    input  wire [DATA_WIDTH-1:0]    reg_rd_data,
    input  wire                     reg_rd_valid
);

    // AXI Response Types
    localparam [1:0] RESP_OKAY   = 2'b00;  // Successful transaction
    localparam [1:0] RESP_EXOKAY = 2'b01;  // Exclusive access okay (unused)
    localparam [1:0] RESP_SLVERR = 2'b10;  // Slave error
    localparam [1:0] RESP_DECERR = 2'b11;  // Decode error

    // Write FSM States
    localparam [2:0] W_IDLE    = 3'b000;
    localparam [2:0] W_ADDR    = 3'b001;
    localparam [2:0] W_DATA    = 3'b010;
    localparam [2:0] W_BOTH    = 3'b011;
    localparam [2:0] W_RESP    = 3'b100;
    
    reg [2:0] write_state;
    
    // Read FSM States
    localparam [1:0] R_IDLE    = 2'b00;
    localparam [1:0] R_ADDR    = 2'b01;
    localparam [1:0] R_DATA    = 2'b10;
    
    reg [1:0] read_state;
    

    // Internal Registers for Captured Write Transaction
    reg [ADDR_WIDTH-1:0] wr_addr_captured;
    reg [DATA_WIDTH-1:0] wr_data_captured;
    reg [DATA_WIDTH/8-1:0] wr_strb_captured;
    

    // Write Transaction State Machine

    always @(posedge S_AXI_ACLK or negedge S_AXI_ARESETN) begin
        if (!S_AXI_ARESETN) begin
            write_state      <= W_IDLE;
            S_AXI_AWREADY    <= 1'b0;
            S_AXI_WREADY     <= 1'b0;
            S_AXI_BVALID     <= 1'b0;
            S_AXI_BRESP      <= RESP_OKAY;
            reg_wr_en        <= 1'b0;
            reg_wr_addr      <= {ADDR_WIDTH{1'b0}};
            reg_wr_data      <= {DATA_WIDTH{1'b0}};
            reg_wr_strb      <= {DATA_WIDTH/8{1'b0}};
            wr_addr_captured <= {ADDR_WIDTH{1'b0}};
            wr_data_captured <= {DATA_WIDTH{1'b0}};
            wr_strb_captured <= {DATA_WIDTH/8{1'b0}};
        end else begin
            reg_wr_en <= 1'b0;
            
            case (write_state)
                
                W_IDLE: begin
                    S_AXI_AWREADY <= 1'b1;  // Ready to accept address
                    S_AXI_WREADY  <= 1'b1;  // Ready to accept data
                    S_AXI_BVALID  <= 1'b0;
                    
                    // Check which channel arrives first
                    if (S_AXI_AWVALID && S_AXI_WVALID) begin
                        // Both arrive together (common case)
                        wr_addr_captured <= S_AXI_AWADDR;
                        wr_data_captured <= S_AXI_WDATA;
                        wr_strb_captured <= S_AXI_WSTRB;
                        S_AXI_AWREADY    <= 1'b0;
                        S_AXI_WREADY     <= 1'b0;
                        write_state      <= W_BOTH;
                    end else if (S_AXI_AWVALID) begin
                        // Address arrives first
                        wr_addr_captured <= S_AXI_AWADDR;
                        S_AXI_AWREADY    <= 1'b0;
                        write_state      <= W_ADDR;
                    end else if (S_AXI_WVALID) begin
                        // Data arrives first
                        wr_data_captured <= S_AXI_WDATA;
                        wr_strb_captured <= S_AXI_WSTRB;
                        S_AXI_WREADY     <= 1'b0;
                        write_state      <= W_DATA;
                    end
                end
                
                W_ADDR: begin
                    // Waiting for write data
                    S_AXI_WREADY <= 1'b1;
                    
                    if (S_AXI_WVALID) begin
                        wr_data_captured <= S_AXI_WDATA;
                        wr_strb_captured <= S_AXI_WSTRB;
                        S_AXI_WREADY     <= 1'b0;
                        write_state      <= W_BOTH;
                    end
                end
                
                W_DATA: begin
                    // Waiting for write address
                    S_AXI_AWREADY <= 1'b1;
                    
                    if (S_AXI_AWVALID) begin
                        wr_addr_captured <= S_AXI_AWADDR;
                        S_AXI_AWREADY    <= 1'b0;
                        write_state      <= W_BOTH;
                    end
                end
                
                W_BOTH: begin
                    reg_wr_en   <= 1'b1;
                    reg_wr_addr <= wr_addr_captured;
                    reg_wr_data <= wr_data_captured;
                    reg_wr_strb <= wr_strb_captured;
                    
                    // Generate write response
                    S_AXI_BVALID <= 1'b1;
                    S_AXI_BRESP  <= RESP_OKAY;
                    write_state  <= W_RESP;
                end
                
                W_RESP: begin
                    // Wait for master to accept response
                    if (S_AXI_BREADY) begin
                        S_AXI_BVALID <= 1'b0;
                        write_state  <= W_IDLE;
                    end
                end
      
                default: begin
                    write_state <= W_IDLE;
                end
            endcase
        end
    end

    
    // Read Transaction State Machine
    always @(posedge S_AXI_ACLK or negedge S_AXI_ARESETN) begin
        if (!S_AXI_ARESETN) begin
            read_state    <= R_IDLE;
            S_AXI_ARREADY <= 1'b0;
            S_AXI_RVALID  <= 1'b0;
            S_AXI_RDATA   <= {DATA_WIDTH{1'b0}};
            S_AXI_RRESP   <= RESP_OKAY;
            reg_rd_en     <= 1'b0;
            reg_rd_addr   <= {ADDR_WIDTH{1'b0}};
        end else begin
            //deassert read enable
            reg_rd_en <= 1'b0;
            
            case (read_state)
                R_IDLE: begin
                    S_AXI_ARREADY <= 1'b1;  // Ready to accept read address
                    S_AXI_RVALID  <= 1'b0;
                    
                    if (S_AXI_ARVALID) begin
                        // Capture address and initiate read
                        reg_rd_addr   <= S_AXI_ARADDR;
                        reg_rd_en     <= 1'b1;
                        S_AXI_ARREADY <= 1'b0;
                        read_state    <= R_ADDR;
                    end
                end
                                
                R_ADDR: begin
                    // Wait for reg_bank to provide data
                    if (reg_rd_valid) begin
                        S_AXI_RDATA  <= reg_rd_data;
                        S_AXI_RRESP  <= RESP_OKAY;
                        S_AXI_RVALID <= 1'b1;
                        read_state   <= R_DATA;
                    end
                end
                
                R_DATA: begin
                    // Wait for master to accept data
                    if (S_AXI_RREADY) begin
                        S_AXI_RVALID <= 1'b0;
                        read_state   <= R_IDLE;
                    end
                end
                
                default: begin
                    read_state <= R_IDLE;
                end
            endcase
        end
    end

endmodule
