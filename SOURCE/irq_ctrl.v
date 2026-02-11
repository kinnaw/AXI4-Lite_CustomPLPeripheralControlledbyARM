module irq_ctrl #(
    parameter CLK_FREQ_HZ = 100_000_000,        // 100 MHz system clock
    parameter DEBOUNCE_MS = 20                  // Debounce time in milliseconds
) (
    // Clock and reset
    input  wire  clk,
    input  wire  rst_n,
    
    input  wire  ext_irq_in,
    
    // Interrupt output (clean, debounced, single-cycle pulse)
    output wire  irq_pulse_out
);

    localparam integer DEBOUNCE_COUNT = (CLK_FREQ_HZ / 1000) * DEBOUNCE_MS;
    localparam integer COUNTER_WIDTH = $clog2(DEBOUNCE_COUNT + 1);
    
    reg [COUNTER_WIDTH-1:0] debounce_counter;
    reg                      ext_irq_sync_1;     // First sync stage
    reg                      ext_irq_sync_2;     // Second sync stage
    reg                      ext_irq_stable;     // Debounced signal
    reg                      ext_irq_d1;         // Delayed by 1 cycle
    wire                     ext_irq_posedge;    // Positive edge detected
    reg                      irq_pulse_reg;
    
    assign irq_pulse_out = irq_pulse_reg;
    

    always @(posedge clk) begin
        if (!rst_n) begin
            ext_irq_sync_1 <= 1'b0;
            ext_irq_sync_2 <= 1'b0;
        end else begin
            ext_irq_sync_1 <= ext_irq_in;      // First stage
            ext_irq_sync_2 <= ext_irq_sync_1;  // Second stage (safe to use)
        end
    end
    
    always @(posedge clk) begin
        if (!rst_n) begin
            debounce_counter <= {COUNTER_WIDTH{1'b0}};
            ext_irq_stable   <= 1'b0;
        end else begin
            if (ext_irq_sync_2 != ext_irq_stable) begin
                // Input changed - start/restart counter
                if (debounce_counter == DEBOUNCE_COUNT[COUNTER_WIDTH-1:0]) begin
                    // Counter expired - accept new value as stable
                    ext_irq_stable   <= ext_irq_sync_2;
                    debounce_counter <= {COUNTER_WIDTH{1'b0}};
                end else begin
                    // Continue counting
                    debounce_counter <= debounce_counter + 1'b1;
                end
            end else begin
                // Input matches stable value - reset counter
                debounce_counter <= {COUNTER_WIDTH{1'b0}};
            end
        end
    end
    
    always @(posedge clk) begin
        if (!rst_n) begin
            ext_irq_d1 <= 1'b0;
        end else begin
            ext_irq_d1 <= ext_irq_stable;
        end
    end
    
    // Positive edge = current high AND previous low
    assign ext_irq_posedge = ext_irq_stable & ~ext_irq_d1;
    
    always @(posedge clk) begin
        if (!rst_n) begin
            irq_pulse_reg <= 1'b0;
        end else begin
            irq_pulse_reg <= ext_irq_posedge;
        end
    end

endmodule
