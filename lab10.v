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
reg  [12:0] snake_x_clock, snake_y_clock;
reg  [9:0]  p_x, p_y;
reg  [9:0]  p_x1, p_y1;
reg  [9:0]  p_x2, p_y2;
reg  [9:0]  p_x3, p_y3;
reg  [9:0]  p_x4, p_y4;
reg  [9:0]  apple_x, apple_y;
reg  [9:0]  tmp_apple_x, tmp_apple_y;
wire        snake_region, snake_region1, snake_region2, snake_region3, snake_region4;
wire        obstacle1_region;
wire        black_region;
wire        apple_region;

/////////////score parameter
reg [5:0]   now_score = 0;
wire        score_region;
wire [16:0] sram_score_addr;
reg [16:0] score_addr[9:0];
reg  [16:0] pixel_score_addr;
wire [11:0] score_out;
localparam SCORE_W = 50;
localparam SCORE_H = 50;
localparam SCORE_ORIGY = 100;
localparam SCORE_ORIGX = 240;
initial begin
    score_addr[0] = 0;                
    score_addr[1] = SCORE_W*SCORE_H  ;
    score_addr[2] = SCORE_W*SCORE_H*2;
    score_addr[3] = SCORE_W*SCORE_H*3;
    score_addr[4] = SCORE_W*SCORE_H*4;
    score_addr[5] = SCORE_W*SCORE_H*5;
    score_addr[6] = SCORE_W*SCORE_H*6;
    score_addr[7] = SCORE_W*SCORE_H*7;
    score_addr[8] = SCORE_W*SCORE_H*8;
    score_addr[9] = SCORE_W*SCORE_H*9;
end
////////////
// declare SRAM control signals
wire [16:0] sram_addr, applesram_addr;
wire [11:0] data_in;
wire [11:0] data_out, data_out_apple;
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
reg  [17:0] pixel_addr, apple_addr;

wire [3:0]  btn_level, btn_pressed;
reg  [3:0]  prev_btn_level;
reg x_dir, y_dir, dir;
// Declare the video buffer size
localparam VBUF_W = 240; // video buffer width
localparam VBUF_H = 240; // video buffer height

// Set parameters for the fish images
localparam SNAKE_W      = 8; // Width of the fish.
localparam SNAKE_H      = 8; // Height of the fish.

reg [2:0] P, P_next;
localparam [2:0] S_MAIN_INIT = 0, S_MAIN_WAIT = 1, S_MAIN_MOVE = 2, S_MAIN_IDLE = 3, S_MAIN_FINI = 4;
reg died, start;
integer cnt;
reg slow_clk;
reg hit;
wire ob1_right, ob1_left, ob1_down, ob1_up;
wire apple_right, apple_left, apple_up, apple_down;
wire apple_hit;
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
applesram #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(64))
  ram1 (.clk(clk), .we(sram_we), .en(sram_en),
          .addr(applesram_addr), .data_i(data_in), .data_o(data_out_apple));
score_ram #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(SCORE_W*SCORE_H*10))
  ram2 (.clk(clk), .we(sram_we), .en(sram_en),
          .addr(sram_score_addr), .data_i(data_in), .data_o(score_out));
assign sram_we = &usr_btn; // In this demo, we do not write the SRAM. However, if
                             // you set 'sram_we' to 0, Vivado fails to synthesize
                             // ram0 as a BRAM -- this is a bug in Vivado.
assign sram_en = 1;          // Here, we always enable the SRAM block.
assign sram_addr = pixel_addr;
assign applesram_addr = apple_addr;
assign sram_score_addr = pixel_score_addr;
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
// ------------------------------------------------------------------------

always @(posedge clk) begin
  if (~reset_n) begin
    P <= S_MAIN_INIT;
  end
  else begin
    P <= P_next;
  end
end

always @(*) begin // FSM next-state logic
  case (P)
    S_MAIN_INIT:
        P_next = S_MAIN_WAIT;
    S_MAIN_WAIT:
        if(btn_pressed[0]) P_next = S_MAIN_MOVE;
        else if(btn_pressed[2]) P_next = S_MAIN_MOVE;
        else if(btn_pressed[3]) P_next = S_MAIN_MOVE;
        else P_next = S_MAIN_WAIT;
    S_MAIN_MOVE:
        P_next = S_MAIN_IDLE;
    S_MAIN_IDLE:
        if(cnt==2) P_next = S_MAIN_MOVE;
        else if(died) P_next = S_MAIN_FINI;
        else P_next = S_MAIN_IDLE;
    S_MAIN_FINI:
        P_next = S_MAIN_FINI;
    default:
      P_next = S_MAIN_IDLE;
  endcase
end

// ------------------------------------------------------------------------

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

//assign p_x = snake_x_clock[11:0]; // the x position of the right edge of the fish image
//                                // in the 640x480 VGA screen
//assign p_y = snake_y_clock[11:0]; // the x position of the right edge of the fish image
//                                // in the 640x480 VGA screen
assign ob1_right = ((snake_x_clock[11:0]==80) || (snake_x_clock[11:0]==(5+8+4)*16)) && (snake_y_clock[11:0] >= 40) && (snake_y_clock[11:0] < (40+64));
assign ob1_left = ((snake_x_clock[11:0]==(5+8+1)*16) || (snake_x_clock[11:0]==(5+8+4+8+1)*16)) && (snake_y_clock[11:0] >= 40) && (snake_y_clock[11:0] < (40+64));
assign ob1_down = (snake_y_clock[11:0]==32) && ((snake_x_clock[11:0] >= 96 && snake_x_clock[11:0] <= (5+8)*16) || (snake_x_clock[11:0] >= (5+8+4+1)*16 && snake_x_clock[11:0] <= (5+8+4+8)*16));
assign ob1_up = (snake_y_clock[11:0]==(5+8)*8) && ((snake_x_clock[11:0] >= 96 && snake_x_clock[11:0] <= (5+8)*16) || (snake_x_clock[11:0] >= (5+8+4+1)*16 && snake_x_clock[11:0] <= (5+8+4+8)*16));

always @(posedge slow_clk) begin
  if (~reset_n) begin
    snake_x_clock[11:0] <= 96;
    snake_y_clock[11:0] <= 120;
    start<=0;
    hit <= 0;
  end
  else if(P == S_MAIN_WAIT) begin
    snake_x_clock[11:0] <= 96;
    snake_y_clock[11:0] <= 120;
    start<=0;
    hit <= 0;
  end
//  else if(P == S_MAIN_MOVE || S_MAIN_IDLE) begin
//      start<=1;
//      if(dir==0 && x_dir==0)
//        snake_x_clock[11:0] <= (snake_x_clock[11:1]>=VBUF_W) ? snake_x_clock[11:0] : snake_x_clock[11:0] + 16;
//      else if(dir==0 && x_dir==1)
//        snake_x_clock[11:0] <= (snake_x_clock[11:1]<=SNAKE_W) ? snake_x_clock[11:0] : snake_x_clock[11:0] - 16;
//      else if(dir==1 && y_dir==0)
//        snake_y_clock[11:0] <= (snake_y_clock[11:1]>=VBUF_H) ? snake_y_clock[11:0] : snake_y_clock[11:0] + 8;
//      else if(dir==1 && y_dir==1)
//        snake_y_clock[11:0] <= (snake_y_clock[11:1]<=SNAKE_H) ? snake_y_clock[11:0] : snake_y_clock[11:0] - 8;
//  end
  else if(P == S_MAIN_MOVE || S_MAIN_IDLE) begin
      start<=1;
      hit<=1;
      if(dir==0 && x_dir==0) begin
        if(snake_x_clock[11:1]>=VBUF_W)
            start<=0;
        else if(ob1_right)
            hit<=0;
        else
            snake_x_clock[11:0] <= snake_x_clock[11:0] + 16;
      end
      else if(dir==0 && x_dir==1) begin
        if(snake_x_clock[11:1]<=SNAKE_W)
            start<=0;
        else if(ob1_left)
            hit<=0;
        else
            snake_x_clock[11:0] <= snake_x_clock[11:0] - 16;
      end
      else if(dir==1 && y_dir==0) begin
        if(snake_y_clock[11:0]>=VBUF_H-8)
            start<=0;
        else if(ob1_down)
            hit<=0;
        else
            snake_y_clock[11:0] <= snake_y_clock[11:0] + 8;
      end
      else if(dir==1 && y_dir==1) begin
        if(snake_y_clock[11:1]<=0)
            start<=0;
        else if(ob1_up)
            hit<=0;
        else
            snake_y_clock[11:0] <= snake_y_clock[11:0] - 8;
      end
  end
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
           (pixel_x + 16) >= p_x && pixel_x < p_x;
assign snake_region1 =
           pixel_y >= (p_y1<<1) && pixel_y < (p_y1+SNAKE_H)<<1 &&
           (pixel_x + 16) >= p_x1 && pixel_x < p_x1;
assign snake_region2 =
           pixel_y >= (p_y2<<1) && pixel_y < (p_y2+SNAKE_H)<<1 &&
           (pixel_x + 16) >= p_x2 && pixel_x < p_x2;
assign snake_region3 =
           pixel_y >= (p_y3<<1) && pixel_y < (p_y3+SNAKE_H)<<1 &&
           (pixel_x + 16) >= p_x3 && pixel_x < p_x3;
assign snake_region4 =
           pixel_y >= (p_y4<<1) && pixel_y < (p_y4+SNAKE_H)<<1 &&
           (pixel_x + 16) >= p_x4 && pixel_x < p_x4;
assign obstacle1_region = 
           (pixel_y >= (40<<1) && pixel_y < (40+64)<<1 &&
           (pixel_x) >= 80 && pixel_x < (5+8) * 16) ||
           (pixel_y >= (40<<1) && pixel_y < (40+64)<<1 &&
           (pixel_x) >= (5+8+4)*16 && pixel_x < (5+8+8+4) * 16);
assign black_region = (pixel_x >= 480);
assign apple_region = pixel_y >= (apple_y<<1) && pixel_y < ((apple_y+8)<<1) && (pixel_x) >= (apple_x<<1) && pixel_x < ((apple_x+8)<<1);
assign score_region = 
            (pixel_y >= (SCORE_ORIGY<<1) && pixel_y < (SCORE_ORIGY+SCORE_H)<<1 &&
           (pixel_x) >= 480 && pixel_x < 580);
always @ (posedge clk) begin
  if (~reset_n) begin
    p_x <= 96;
    p_y <= 120;
    p_y1 <= 120;
    p_y2 <= 120;
    p_y3 <= 120;
    p_y4 <= 120;
    p_x1 <= 80;
    p_x2 <= 64;
    p_x3 <= 48;
    p_x4 <= 32;    
  end
  else if(P == S_MAIN_WAIT) begin
    p_x <= 96;
    p_y <= 120;
    p_y1 <= 120;
    p_y2 <= 120;
    p_y3 <= 120;
    p_y4 <= 120;
    p_x1 <= 80;
    p_x2 <= 64;
    p_x3 <= 48;
    p_x4 <= 32;   
  end
  else if(P == S_MAIN_MOVE && start && hit) begin
    p_x <= snake_x_clock[11:0];
    p_y <= snake_y_clock[11:0];
    p_y1 <= p_y;
    p_y2 <= p_y1;
    p_y3 <= p_y2;
    p_y4 <= p_y3;
    p_x1 <= p_x;
    p_x2 <= p_x1;
    p_x3 <= p_x2;
    p_x4 <= p_x3;
  end
  else begin
    p_x <= p_x;
    p_y <= p_y;
    p_y1 <= p_y1;
    p_y2 <= p_y2;
    p_y3 <= p_y3;
    p_y4 <= p_y4;
    p_x1 <= p_x1;
    p_x2 <= p_x2;
    p_x3 <= p_x3;
    p_x4 <= p_x4;
  end
end

always @ (posedge clk) begin
  if (~reset_n) begin
    pixel_addr <= 0;
  end
  else
    // Scale up a 320x240 image for the 640x480 display.
    // (pixel_x, pixel_y) ranges from (0,0) to (639, 479)
    pixel_addr <= (pixel_y >> 1) * VBUF_W + (pixel_x >> 1);
end
always @ (posedge clk) begin
  if (~reset_n) begin
    pixel_score_addr <= 0;
  end
  else if (score_region)
    // Scale up a 320x240 image for the 640x480 display.
    // (pixel_x, pixel_y) ranges from (0,0) to (639, 479)
    pixel_score_addr <= score_addr[now_score] +
                      ((pixel_y>>1)-SCORE_ORIGY)*SCORE_W +
                      ((pixel_x +SCORE_W-SCORE_ORIGX)>>1);
  else
    pixel_score_addr <= 0;
end
always @ (posedge clk) begin
  if (~reset_n) 
    apple_addr <= 0;
  else if(apple_region)
    apple_addr <= ((pixel_y>>1)-apple_y)*8 + ((pixel_x>>1)-apple_x);
    
  else 
    apple_addr <= 0;
end
// End of the AGU code.
// ------------------------------------------------------------------------
// ------------------------------------------------------------------------
//apple
integer cntx = 1, cnty = 10;
always @(posedge clk) begin
    if (~reset_n) begin
        cntx <= 1;
        cnty <= 10;
    end else begin
        cntx <= cntx >= 30? 0 : cntx+1;
        cnty <= cnty >= 17? 0: cnty + 1;
    end       
end
assign apple_hit = (snake_x_clock[11:0]==(apple_x+8)<<1) && (snake_y_clock[11:0] == apple_y);
always @(posedge clk) begin
    if(~reset_n) begin
        apple_x <= 120;
        apple_y <= 120;
        now_score <= 0;
    end 
    else if (apple_hit) begin
        now_score <= now_score == 9 ? 9:now_score+1;
        apple_x <= cntx*8;
        apple_y <= cnty*8+104;
    end
end
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// Send the video data in the sram to the VGA controller
always @(posedge clk) begin
  if (pixel_tick) rgb_reg <= rgb_next;
end

always @(*) begin
  if (~video_on)
    rgb_next = 12'h000; // Synchronization period, must set RGB values to zero.
  else if(obstacle1_region)
    rgb_next = 12'h000;
  else if(snake_region)
    rgb_next = 12'h707;
  else if(snake_region1)
    rgb_next = 12'h0ff;
  else if(snake_region2)
    rgb_next = 12'h707;
  else if(snake_region3)
    rgb_next = 12'h0ff;
  else if(snake_region4)
    rgb_next = 12'h707;
  else if(black_region)
    //rgb_next = 12'h000;
    rgb_next = (score_region && score_out != 12'h0f0) ? score_out : 12'h000;
  else
    rgb_next = (apple_region && data_out_apple != 12'h0f0) ? data_out_apple : data_out; // RGB value at (pixel_x, pixel_y)
end
// End of the video data display code.
// ------------------------------------------------------------------------

endmodule
