//****************************************Copyright (c)***********************************//
//原子哥在线教学平台：www.yuanzige.com
//技术支持：www.openedv.com
//淘宝店铺：http://openedv.taobao.com
//关注微信公众平台微信号："正点原子"，免费获取ZYNQ & FPGA & STM32 & LINUX资料。
//版权所有，盗版必究。
//Copyright(C) 正点原子 2018-2028
//All rights reserved
//----------------------------------------------------------------------------------------
// File name:           hdmi_top
// Last modified Date:  2020/05/04 9:19:08
// Last Version:        V1.0
// Descriptions:        HDMI显示顶层模块
//                      
//----------------------------------------------------------------------------------------
// Created by:          正点原子
// Created date:        2019/05/04 9:19:08
// Version:             V1.0
// Descriptions:        The original version
//
//----------------------------------------------------------------------------------------
//****************************************************************************************//

module  hdmi_top1(
    input           pixel_clk,
    input           pixel_clk_5x,    
    input           sys_rst_n,
   //hdmi接口 
    output          tmds_clk_p,     // TMDS 时钟通道
    //output          tmds_clk_n,
    output [2:0]    tmds_data_p,    // TMDS 数据通道
    //output [2:0]    tmds_data_n,
   //用户接口 
    output          video_vs,       //HDMI场信号      
    output  [10:0]  pixel_xpos,     //像素点横坐标
    output  [10:0]  pixel_ypos,     //像素点纵坐标      
    input   [15:0]  data_in,        //输入数据
    output          data_req        //请求数据输入   
);

//wire define
wire          clk_locked;
wire          video_hs;
wire          video_de;
wire  [23:0]  video_rgb;
wire  [23:0]  video_rgb_565;


localparam BITS = 16;      // Assuming 8-bit pixel depth
localparam WIDTH = 1920;  // Image width
localparam HEIGHT = 1080;  // Image height
localparam BAYER_PATTERN = 2; // RGGB pattern by default //0:RGGB 1:GRBG 2:GBRG 3:BGGR
wire out_href,out_vsync;
wire [BITS-1:0] out_raw;

//wire  [11:0]  video_rgb;
//*****************************************************
//**                    main code
//*****************************************************

//将摄像头16bit数据转换为24bit的hdmi数据
// assign video_rgb = {video_rgb_565[15:11],3'b000,video_rgb_565[10:5],2'b00,
//                     video_rgb_565[4:0],3'b000};  

//转化RGB444数据
assign video_rgb = {out_raw[14:11],out_raw[8:5],
                   out_raw[3:0]};  

//例化视频显示驱动模块
video_driver u_video_driver(
    .pixel_clk      (pixel_clk),
    .sys_rst_n      (sys_rst_n),

    .video_hs       (video_hs),
    .video_vs       (video_vs),
    .video_de       (video_de),
    .video_rgb      (video_rgb_565),
   
    .data_req       (data_req),
    .pixel_xpos     (pixel_xpos),
    .pixel_ypos     (pixel_ypos),
    .pixel_data     (data_in)
    );


   isp_dpc  #(.BITS(BITS),
            .WIDTH(WIDTH),
            .HEIGHT(HEIGHT),
            .BAYER (BAYER_PATTERN) )  dpc
   (
        .pclk(pixel_clk),
        .rst_n(sys_rst_n),

        .threshold(0), //阈值越小,检测越松,坏点检测数越多

        .in_href(video_hs),
        .in_vsync(video_vs),
        .in_raw(video_rgb_565),

        .out_href(out_href),
        .out_vsync(out_vsync),
        .out_raw(out_raw)
   );

//例化HDMI驱动模块
hdmi_tx #(.FAMILY("EG4"))	//EF2、EF3、EG4、AL3、PH1

 u3_hdmi_tx(
    .PXLCLK_I        (pixel_clk),
    .PXLCLK_5X_I        (pixel_clk_5x),
    .RST_N        (sys_rst_n),
                
    .VGA_RGB      (video_rgb),
    .VGA_HS    (video_hs), 
    .VGA_VS    (video_vs),
    .VGA_DE       (video_de),
                
    .HDMI_CLK_P     (tmds_clk_p),
    //.tmds_clk_n     (tmds_clk_n),
    .HDMI_D2_P (tmds_data_p[2] ),
	.HDMI_D1_P (tmds_data_p[1] ),
	.HDMI_D0_P (tmds_data_p[0] )	
    // .tmds_data_p    (tmds_data_p),
    //.tmds_data_n    (tmds_data_n)
    );

endmodule 