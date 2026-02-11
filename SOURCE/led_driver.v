module led_driver #(
    parameter NUM_LEDS = 4,                     // Number of LEDs
    parameter ENABLE_PWM = 0,                   // 0=direct, 1=PWM dimming
    parameter PWM_RESOLUTION = 8,               // PWM resolution in bits
    parameter CLK_FREQ_HZ = 100_000_000         // Clock frequency
) (
    // Clock and reset
    input  wire                  clk,
    input  wire                  rst_n,
    
    // LED control input from register bank
    input  wire [NUM_LEDS-1:0]   led_ctrl,
    
    // PWM brightness control (0-255, only used if ENABLE_PWM=1)
    input  wire [PWM_RESOLUTION-1:0] pwm_duty,
    
    // Physical LED outputs
    output wire [NUM_LEDS-1:0]   LED
);

    generate
        if (ENABLE_PWM == 1) begin : gen_pwm
            localparam integer PWM_PERIOD = (1 << PWM_RESOLUTION) - 1;
            
            reg [PWM_RESOLUTION-1:0] pwm_counter;
            reg                       pwm_active;
            reg [NUM_LEDS-1:0]       led_out_reg;
            
            // PWM counter
            always @(posedge clk) begin
                if (!rst_n) begin
                    pwm_counter <= {PWM_RESOLUTION{1'b0}};
                end else begin
                    if (pwm_counter == PWM_PERIOD[PWM_RESOLUTION-1:0]) begin
                        pwm_counter <= {PWM_RESOLUTION{1'b0}};
                    end else begin
                        pwm_counter <= pwm_counter + 1'b1;
                    end
                end
            end
            
            // PWM comparator
            always @(posedge clk) begin
                if (!rst_n) begin
                    pwm_active <= 1'b0;
                end else begin
                    pwm_active <= (pwm_counter < pwm_duty) ? 1'b1 : 1'b0;
                end
            end
            
            // Apply PWM to LEDs
            always @(posedge clk) begin
                if (!rst_n) begin
                    led_out_reg <= {NUM_LEDS{1'b0}};
                end else begin
                    led_out_reg <= led_ctrl & {NUM_LEDS{pwm_active}};
                end
            end
            
            assign LED = led_out_reg;
            
        end else begin : gen_direct

            reg [NUM_LEDS-1:0] led_out_reg;
            
            always @(posedge clk) begin
                if (!rst_n) begin
                    led_out_reg <= {NUM_LEDS{1'b0}};
                end else begin
                    led_out_reg <= led_ctrl;
                end
            end
            
            assign LED = led_out_reg;
        end
    endgenerate

endmodule
