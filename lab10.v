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
reg  [31:0] snake_x_clock, snake_y_clock;
wire [9:0]  p_x, p_y;
wire        snake_region;

// declare SRAM control signals
wire [16:0] sram_addr;
wire [11:0] data_in;
wire [11:0] data_out;
wire        sram_we, sram_en;

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
reg  [17:0] pixel_addr;

wire [3:0]  btn_level, btn_pressed;
reg  [3:0]  prev_btn_level;
reg x_dir, y_dir, dir;
// Declare the video buffer size
localparam VBUF_W = 320; // video buffer width
localparam VBUF_H = 240; // video buffer height

// Set parameters for the fish images
localparam SNAKE_W      = 8; // Width of the fish.
localparam SNAKE_H      = 8; // Height of the fish.



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

debounce btn_db0(
  .clk(clk),
  .btn_input(usr_btn[0]),
  .btn_output(btn_level[0])
);

debounce btn_db1(
  .clk(clk),
  .btn_input(usr_btn[1]),
  .btn_output(btn_level[1])
);

debounce btn_db2(
  .clk(clk),
  .btn_input(usr_btn[2]),
  .btn_output(btn_level[2])
);

debounce btn_db3(
  .clk(clk),
  .btn_input(usr_btn[3]),
  .btn_output(btn_level[3])
);
// ------------------------------------------------------------------------
// The following code describes an initialized SRAM memory block that
// stores a 320x240 12-bit seabed image, plus two 64x32 fish images.
sram #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(VBUF_W*VBUF_H))
  ram0 (.clk(clk), .we(sram_we), .en(sram_en),
          .addr(sram_addr), .data_i(data_in), .data_o(data_out));

assign sram_we = &usr_btn; // In this demo, we do not write the SRAM. However, if
                             // you set 'sram_we' to 0, Vivado fails to synthesize
                             // ram0 as a BRAM -- this is a bug in Vivado.
assign sram_en = 1;          // Here, we always enable the SRAM block.
assign sram_addr = pixel_addr;
assign data_in = 12'h000; // SRAM is read-only so we tie inputs to zeros.
// End of the SRAM memory block.
// ------------------------------------------------------------------------

// VGA color pixel generator
assign {VGA_RED, VGA_GREEN, VGA_BLUE} = rgb_reg;

// ------------------------------------------------------------------------
// An animation clock for the motion of the fish, upper bits of the
// fish clock is the x position of the fish on the VGA screen.
// Note that the fish will move one screen pixel every 2^20 clock cycles,
// or 10.49 msec
integer cnt;
reg slow_clk;
always @(posedge clk) begin
    cnt <= (cnt<49999999)?cnt+1:0;
    if(cnt==0) slow_clk<=1;
    else if(cnt==25000000) slow_clk<=0;
end

always @(posedge clk) begin
  if (~reset_n)
    prev_btn_level <= 4'b0000;
  else
    prev_btn_level <= btn_level;
end

assign btn_pressed = (btn_level & ~prev_btn_level);

always @(posedge clk) begin
  if (~reset_n) begin
    x_dir <= 0;
    y_dir <= 0;
    dir <= 0;
  end
  else if(btn_pressed[0] && dir) begin
    x_dir <= 0;
    dir <= 0;
  end
  else if(btn_pressed[1] && dir)begin
    x_dir <= 1;
    dir <= 0;
  end
  else if(btn_pressed[2] && !dir)begin
    y_dir <= 0;
    dir <= 1;
  end
  else if(btn_pressed[3] && !dir)begin
    y_dir <= 1;
    dir <= 1;
  end
end

assign p_x = snake_x_clock[31:20]; // the x position of the right edge of the fish image
                                // in the 640x480 VGA screen
assign p_y = snake_y_clock[31:20]; // the x position of the right edge of the fish image
                                // in the 640x480 VGA screen

always @(posedge slow_clk) begin
  if (~reset_n) begin
    snake_x_clock[31:20] <= 24;
    snake_y_clock[31:20] <= 120;
  end
  else if(dir==0 && x_dir==0)
    snake_x_clock[31:20] <= (snake_x_clock[31:21]==VBUF_W) ? snake_x_clock[31:20] : snake_x_clock[31:20] + 16;
  else if(dir==0 && x_dir==1)
    snake_x_clock[31:20] <= (snake_x_clock[31:21]<SNAKE_W) ? snake_x_clock[31:20] : snake_x_clock[31:20] - 16;
  else if(dir==1 && y_dir==0)
    snake_y_clock[31:20] <= (snake_y_clock[31:21]==VBUF_H) ? snake_y_clock[31:20] : snake_y_clock[31:20] + 16;
  else if(dir==1 && y_dir==1)
    snake_y_clock[31:20] <= (snake_y_clock[31:21]<SNAKE_H) ? snake_y_clock[31:20] : snake_y_clock[31:20] - 16;
end

// End of the animation clock code.
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// Video frame buffer address generation unit (AGU) with scaling control
// Note that the width x height of the fish image is 64x32, when scaled-up
// on the screen, it becomes 128x64. 'pos' specifies the right edge of the
// fish image.
assign snake_region =
           pixel_y >= (p_y<<1) && pixel_y < (p_y+SNAKE_H)<<1 &&
           (pixel_x + 16) >= p_x && pixel_x < p_x + 1;

always @ (posedge clk) begin
  if (~reset_n) begin
    pixel_addr <= 0;
  end
  else
    // Scale up a 320x240 image for the 640x480 display.
    // (pixel_x, pixel_y) ranges from (0,0) to (639, 479)
    pixel_addr <= (pixel_y >> 1) * VBUF_W + (pixel_x >> 1);
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
  else if(snake_region)
    rgb_next = 12'h000;
  else
    rgb_next = data_out; // RGB value at (pixel_x, pixel_y)
end
// End of the video data display code.
// ------------------------------------------------------------------------

endmodule
