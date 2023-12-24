`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Dept. of Computer Science, National Chiao Tung University
// Engineer: Chun-Jen Tsai 
// 
// Create Date: 2018/12/11 16:04:41
// Design Name: 
// Module Name: lab9
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: A circuit that show the animation of a fish swimming in a seabed
//              scene on a screen through the VGA interface of the Arty I/O card.
// 
// Dependencies: vga_sync, clk_divider, sram 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module lab10(
    input  clk,
    input  reset_n,
    input  [3:0] usr_btn,
    output [3:0] usr_led,
    
    // VGA specific I/O ports
    output VGA_HSYNC,
    output VGA_VSYNC,
    output [3:0] VGA_RED,
    output [3:0] VGA_GREEN,
    output [3:0] VGA_BLUE
    );

// Declare system variables
wire [1:0] btn_level, btn_pressed;
reg  [1:0] prev_btn_level;
always @(posedge clk) begin
  if (~reset_n)
    prev_btn_level <= 0;
  else
    prev_btn_level <= btn_level;
end
assign btn_pressed = (btn_level & ~prev_btn_level);
reg  [31:0] fish_clock, fish2_clock, fish3_clock;
wire [9:0]  pos, pos2, pos3;
wire        fish_region, fish2_region, fish3_region ;

// declare SRAM control signals
wire [16:0] sram_addr, bgram_addr, f2_addr, f3_addr;
wire [11:0] data_in, data_in2;
wire [11:0] data_out, background_out, fish2_out, fish3_out;
wire        sram_we, sram_en, bgram_en;

// General VGA control signals
wire vga_clk;         // 50MHz clock for VGA control
wire video_on;        // when video_on is 0, the VGA controller is sending
                      // synchronization signals to the display device.
  
wire pixel_tick;      // when pixel tick is 1, we must update the RGB value
                      // based for the new coordinate (pixel_x, pixel_y)
  
wire [9:0] pixel_x;   // x coordinate of the next pixel (between 0 ~ 639) 
wire [9:0] pixel_y;   // y coordinate of the next pixel (between 0 ~ 479)
  
reg  [11:0] rgb_reg;  // RGB value for the current pixel
reg  [11:0] rgb_next; // RGB value for the next pixel
  
// Application-specific VGA signals
reg  [17:0] pixel_addr, background_addr, pixel2_addr, pixel3_addr;

reg [5:0] speedup = 0;
// Declare the video buffer size
localparam VBUF_W = 202; // video buffer width
localparam VBUF_H = 202; // video buffer height

// Set parameters for the fish images
localparam FISH_VPOS   = 64; // Vertical location of the fish in the sea image.
localparam FISH3_VPOS   = 100;
localparam FISH2_VPOS = 150;
localparam FISH2_W = 64;
localparam FISH2_H = 44;
localparam FISH3_W = 64;
localparam FISH3_H = 72;
localparam FISH_W  = 64; // Width of the fish.
localparam FISH_H  = 32; // Height of the fish.
reg [17:0] fish_addr[0:7];   // Address array for up to 8 fish images.
reg [17:0] fish2_addr[0:7];
reg [17:0] fish3_addr[0:7];
// Initializes the fish images starting addresses.
// Note: System Verilog has an easier way to initialize an array,
//       but we are using Verilog 2001 :(
initial begin
  fish_addr[0] = 18'd0;         /* Addr for fish image #1 */
  fish_addr[1] = FISH_W*FISH_H; /* Addr for fish image #2 */
  fish_addr[2] = FISH_W*FISH_H*2; /* Addr for fish image #2 */
  fish_addr[3] = FISH_W*FISH_H*3; /* Addr for fish image #2 */
  fish_addr[4] = FISH_W*FISH_H*4; /* Addr for fish image #2 */
  fish_addr[5] = FISH_W*FISH_H*5; /* Addr for fish image #2 */
  fish_addr[6] = FISH_W*FISH_H*6; /* Addr for fish image #2 */
  fish_addr[7] = FISH_W*FISH_H*7; /* Addr for fish image #2 */
end

debounce btn_db2(
  .clk(clk),
  .btn_input(usr_btn[0]),
  .btn_output(btn_level[1])
);
debounce btn_db1(
  .clk(clk),
  .btn_input(usr_btn[1]),
  .btn_output(btn_level[0])
);
initial begin
  fish2_addr[0] = 18'd0;         /* Addr for fish image #1 */
  fish2_addr[1] = FISH2_W*FISH2_H; /* Addr for fish image #2 */
end
initial begin
  fish3_addr[0] = 18'd0;         /* Addr for fish image #1 */
  fish3_addr[1] = FISH3_W*FISH3_H; /* Addr for fish image #2 */
end
// Instiantiate the VGA sync signal generator
vga_sync vs0(
  .clk(vga_clk), .reset(~reset_n), .oHS(VGA_HSYNC), .oVS(VGA_VSYNC),
  .visible(video_on), .p_tick(pixel_tick),
  .pixel_x(pixel_x), .pixel_y(pixel_y)
);

clk_divider#(2) clk_divider0(
  .clk(clk),
  .reset(~reset_n),
  .clk_out(vga_clk)
);
always @(posedge clk) begin
if (~reset_n)
   speedup = 0;
  else if (btn_pressed[0] == 1)
    speedup = speedup + 1;
  else if (btn_pressed[1] == 1)
    speedup = speedup - 1;
end
// ------------------------------------------------------------------------
// The following code describes an initialized SRAM memory block that
// stores a 320x240 12-bit seabed image, plus two 64x32 fish images.
f3ram #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(FISH3_W*FISH3_H*3))
  ram3 (.clk(clk), .we(sram_we), .en(sram_en),
          .addr(f3_addr), .data_i(data_in), .data_o(fish3_out));
          
fram #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(FISH2_W*FISH2_H*2))
  ram2 (.clk(clk), .we(sram_we), .en(sram_en),
          .addr(f2_addr), .data_i(data_in), .data_o(fish2_out));
          
sram #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(FISH_W*FISH_H*8))
  ram0 (.clk(clk), .we(sram_we), .en(sram_en),
          .addr(sram_addr), .data_i(data_in), .data_o(data_out));
bgram #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(VBUF_W*VBUF_H))
  ram1 (.clk(clk), .we(sram_we), .en(bgram_en),                   
          .addr(bgram_addr), .data_i(data_in2), .data_o(background_out));
assign sram_we = usr_btn[3]; // In this demo, we do not write the SRAM. However, if
                             // you set 'sram_we' to 0, Vivado fails to synthesize
                             // ram0 as a BRAM -- this is a bug in Vivado.
assign sram_en = 1;          // Here, we always enable the SRAM block.
assign bgram_en = 1;
assign sram_addr = pixel_addr;
assign f2_addr = pixel2_addr;
assign f3_addr = pixel3_addr;
assign bgram_addr = background_addr;
assign data_in = 12'h0f0; // SRAM is read-only so we tie inputs to zeros.
assign data_in2 = 12'h0f0;
// End of the SRAM memory block.
// ------------------------------------------------------------------------

// VGA color pixel generator
assign {VGA_RED, VGA_GREEN, VGA_BLUE} = rgb_reg;

// ------------------------------------------------------------------------
// An animation clock for the motion of the fish, upper bits of the
// fish clock is the x position of the fish on the VGA screen.
// Note that the fish will move one screen pixel every 2^20 clock cycles,
// or 10.49 msec
assign pos = fish_clock[31:20]; // the x position of the right edge of the fish image
                                // in the 640x480 VGA screen
assign pos2 = fish2_clock[31:20];   

assign pos3 = (VBUF_W + FISH3_W) - fish3_clock[31:20];   
always @(posedge clk) begin
  if (~reset_n || fish_clock[31:21] > VBUF_W + FISH_W)
    fish_clock <= 0;
  else
    fish_clock <= fish_clock + 2 + speedup;
end

always @(posedge clk) begin
  if (~reset_n || fish2_clock[31:21] > VBUF_W + FISH2_W)
    fish2_clock <= 0;
  else
    fish2_clock <= fish2_clock + 1 + speedup;
end
always @(posedge clk) begin
  if (~reset_n || fish3_clock[31:21] < 0)
    fish3_clock[31:21] <= VBUF_W + FISH3_W;
  else
    fish3_clock <= fish3_clock + 1 + speedup;
end
// End of the animation clock code.
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// Video frame buffer address generation unit (AGU) with scaling control
// Note that the width x height of the fish image is 64x32, when scaled-up
// on the screen, it becomes 128x64. 'pos' specifies the right edge of the
// fish image.
assign fish_region =
           pixel_y >= (FISH_VPOS<<1) && pixel_y < (FISH_VPOS+FISH_H)<<1 &&
           (pixel_x + 127) >= pos && pixel_x < pos + 1;
assign fish2_region =
           pixel_y >= (FISH2_VPOS<<1) && pixel_y < (FISH2_VPOS+FISH2_H)<<1 &&
           (pixel_x + 127) >= pos2 && pixel_x < pos2 + 1;
assign fish3_region =
           pixel_y >= (FISH3_VPOS<<1) && pixel_y < (FISH3_VPOS+FISH3_H)<<1 &&
           (pixel_x + 127) >= pos3 && pixel_x < pos3 + 1;
always @ (posedge clk) begin
  if (~reset_n) begin
    pixel_addr <= 0;
  end else if (fish_region) begin 
    pixel_addr <= fish_addr[fish_clock[23]] +
                  ((pixel_y>>1)-FISH_VPOS)*FISH_W +
                  ((pixel_x +(FISH_W*2-1)-pos)>>1);
  end
  else begin
    // Scale up a 320x240 image for the 640x480 display.
    // (pixel_x, pixel_y) ranges from (0,0) to (639, 479)
    pixel_addr <= (pixel_y >> 1) * VBUF_W + (pixel_x >> 1);
  end
end
always @ (posedge clk) begin
  if (~reset_n) begin
    pixel2_addr <= 0;
  end else if (fish2_region) begin 
    pixel2_addr <= fish2_addr[fish2_clock[23]] +
                  ((pixel_y>>1)-FISH2_VPOS)*FISH2_W +
                  ((pixel_x +(FISH2_W*2-1)-pos2)>>1);
  end
  else begin
    // Scale up a 320x240 image for the 640x480 display.
    // (pixel_x, pixel_y) ranges from (0,0) to (639, 479)
    pixel2_addr <= (pixel_y >> 1) * VBUF_W + (pixel_x >> 1);
  end
end
always @ (posedge clk) begin
  if (~reset_n) begin
    pixel3_addr <= 0;
  end else if (fish3_region) begin 
    pixel3_addr <= fish3_addr[fish3_clock[23]] +
                  ((pixel_y>>1)-FISH3_VPOS)*FISH3_W +
                  ((pixel_x +(FISH3_W*2-1)-pos3)>>1);
  end
  else begin
    // Scale up a 320x240 image for the 640x480 display.
    // (pixel_x, pixel_y) ranges from (0,0) to (639, 479)
    pixel3_addr <= (pixel_y >> 1) * VBUF_W + (pixel_x >> 1);
  end
end
always @ (posedge clk) begin
  if (~reset_n)
    background_addr <= 0;
  else
    // Scale up a 320x240 image for the 640x480 display.
    // (pixel_x, pixel_y) ranges from (0,0) to (639, 479)
    background_addr <= (pixel_y >> 1) * VBUF_W + (pixel_x >> 1);
end
// End of the AGU code.
// ------------------------------------------------------------------------
// ------------------------------------------------------------------------
// Send the video data in the sram to the VGA controller
always @(posedge clk) begin
  if (pixel_tick) rgb_reg <= rgb_next;
end

always @(*) begin
  if (~video_on)
    rgb_next = 12'h000; // Synchronization period, must set RGB values to zero.
  else
    if (fish_region) 
        rgb_next =(data_out == 12'h0f0)?background_out:data_out;
    else if (fish2_region)
        if (fish3_region)
            rgb_next = (fish3_out == 12'h0f0)?(fish2_out == 12'h0f0)?background_out:fish2_out:fish3_out;
        else
            rgb_next = (fish2_out == 12'h0f0)?background_out:fish2_out;
    else if (fish3_region)
        rgb_next = (fish3_out == 12'h0f0)?background_out:fish3_out;
    else
        rgb_next = background_out;
end
// End of the video data display code.
// ------------------------------------------------------------------------

endmodule
