//****************************************Copyright (c)***********************************//
//??????????????www.yuanzige.com
//????????www.openedv.com
//????????http://openedv.taobao.com
//????????????????"???????"???????ZYNQ & FPGA & STM32 & LINUX?????
//??????��?????????
//Copyright(C) ??????? 2018-2028
//All rights reserved
//----------------------------------------------------------------------------------------
// File name:           hdmi_top
// Last modified Date:  2020/05/04 9:19:08
// Last Version:        V1.0
// Descriptions:        HDMI??????????
//                      
//----------------------------------------------------------------------------------------
// Created by:          ???????
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
   //hdmi??? 
    output          tmds_clk_p,     // TMDS ??????
    //output          tmds_clk_n,
    output [2:0]    tmds_data_p,    // TMDS ???????
    //output [2:0]    tmds_data_n,
   //?????? 
    output          video_vs,       //HDMI?????      
    output  [10:0]  pixel_xpos,     //??????????
    output  [10:0]  pixel_ypos,     //???????????      
    input   [15:0]  data_in,        //????????
    output          data_req        //????????????   
);

//wire define
wire          clk_locked;
wire          video_hs;
wire          video_de;
wire  [23:0]  video_rgb;
wire  [15:0]  video_rgb_565;


localparam BITS = 16;      // Assuming 8-bit pixel depth
localparam WIDTH = 1920;  // Image width
localparam HEIGHT = 1080;  // Image height
localparam BAYER_PATTERN = 2; // RGGB pattern by default //0:RGGB 1:GRBG 2:GBRG 3:BGGR
wire out_href,out_vsync,out_de;
wire [BITS-1:0] out_raw;

wire out_href2,out_vsync2,out_de2;
wire [BITS-1:0] out_raw2;
//wire  [11:0]  video_rgb;
//*****************************************************
//**                    main code
//*****************************************************

//???????16bit????????24bit??hdmi????
// assign video_rgb = {video_rgb_565[15:11],3'b000,video_rgb_565[10:5],2'b00,
//                     video_rgb_565[4:0],3'b000};  

//???RGB444????
// assign video_rgb = {out_raw[15:11],3'b000,out_raw[10:5],2'b00,
//                    out_raw[4:0],3'b000};  

//?????????????????
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

    // ISP_debayer #(.BITS(BITS),
    //          .WIDTH(WIDTH),
    //          .HEIGHT(HEIGHT)
    //           )  debayer
    // (
    //      .pclk(pixel_clk),
    //      .rst_n(sys_rst_n),


    //      .in_href(video_hs),
    //      .in_vsync(video_vs),
    //      .in_raw(video_rgb_565),
    //      .in_de(video_de),

    //      .out_de(out_de),
    //      .out_href(out_href),
    //      .out_vsync(out_vsync),
    //      .rgb565(out_raw)
    // );

//    isp_dpc  #(.BITS(BITS),
//             .WIDTH(WIDTH),
//             .HEIGHT(HEIGHT),
//             .BAYER (BAYER_PATTERN) )  dpc
//    (
//         .pclk(pixel_clk),
//         .rst_n(sys_rst_n),

//         .threshold(10'd1000), //????��,??????,???????????

//         .in_href(video_hs),
//         .in_vsync(video_vs),
//         .in_raw(video_rgb_565),
//         .in_de(video_de),

//         .out_de(out_de),
//         .out_href(out_href),
//         .out_vsync(out_vsync),
//         .out_raw(out_raw)
//    );

// isp_bnr  #(.BITS(BITS),
//          .WIDTH(WIDTH),
//          .HEIGHT(HEIGHT),
//          .BAYER (BAYER_PATTERN) )  bnr
// (
//      .pclk(pixel_clk),
//      .rst_n(sys_rst_n),

//      .nr_level(1),////0:NoNR 1-4:NRLevel

//      .in_href(out_href),
//      .in_vsync(out_vsync),
//      .in_raw(out_raw),
//      .in_de(out_de),

//      .out_de(out_de2),
//      .out_href(out_href2),
//      .out_vsync(out_vsync2),
//      .out_raw(out_raw2)
// );

// bayer_to_rgb888 trans(
//     .pclk(pixel_clk),
//     .rst(sys_rst_n),
//     .bayer_data(data_in),
//     .pixel_x(pixel_xpos),
//     .pixel_y(pixel_ypos),

//     .rgb888(video_rgb)
// );

// isp_demosaic

// #(
// 	.WIDTH(WIDTH),
//     .HEIGHT(HEIGHT),
// 	.BAYER (2) //0:RGGB 1:GRBG 2:GBRG 3:BGGR
// )
// debayer_h
// (
// 	.pclk(pixel_clk),
//          .rst_n(sys_rst_n),
//          .in_href(video_hs),
//          .in_vsync(video_vs),
//          .in_raw(video_rgb_565[15:8]),
//          .in_de(video_de),

//          .out_de(out_de),
//          .out_href(out_href),
//          .out_vsync(out_vsync),
//          .out_r(video_rgb[23:16]),
//          .out_g(video_rgb[15:8]),
//          .out_b(video_rgb[7:0])
// );

// isp_demosaic_m

// #(
// 	.WIDTH(WIDTH),
//     .HEIGHT(HEIGHT),
// 	.BAYER (2) //0:RGGB 1:GRBG 2:GBRG 3:BGGR
// )
// debayer_m
// (
// 	.pclk(pixel_clk),
//          .rst_n(sys_rst_n),
//          .in_href(video_hs),
//          .in_vsync(video_vs),
//          .in_raw(video_rgb_565[15:8]),
//          .in_de(video_de),

//          .out_de(out_de),
//          .out_href(out_href),
//          .out_vsync(out_vsync),
//          .out_r(video_rgb[23:16]),
//          .out_g(video_rgb[15:8]),
//          .out_b(video_rgb[7:0])
// );


isp_demosaic_l

#(
	.WIDTH(WIDTH),
    .HEIGHT(HEIGHT),
	.BAYER (2) //0:RGGB 1:GRBG 2:GBRG 3:BGGR
)
debayer_l
(
	.pclk(pixel_clk),
         .rst_n(sys_rst_n),
         .in_href(video_hs),
         .in_vsync(video_vs),
         .in_raw(video_rgb_565[15:8]),
         .in_de(video_de),

         .out_de(out_de),
         .out_href(out_href),
         .out_vsync(out_vsync),
         .out_r(video_rgb[23:16]),
         .out_g(video_rgb[15:8]),
         .out_b(video_rgb[7:0])
);
//????HDMI???????
hdmi_tx #(.FAMILY("EG4"))	//EF2??EF3??EG4??AL3??PH1

 u3_hdmi_tx(
    .PXLCLK_I        (pixel_clk),
    .PXLCLK_5X_I        (pixel_clk_5x),
    .RST_N        (sys_rst_n),
                
    .VGA_RGB      (video_rgb),
    .VGA_HS    (out_href), 
    .VGA_VS    (out_vsync),
    .VGA_DE       (out_de),
                
    .HDMI_CLK_P     (tmds_clk_p),
    //.tmds_clk_n     (tmds_clk_n),
    .HDMI_D2_P (tmds_data_p[2] ),
	.HDMI_D1_P (tmds_data_p[1] ),
	.HDMI_D0_P (tmds_data_p[0] )	
    // .tmds_data_p    (tmds_data_p),
    //.tmds_data_n    (tmds_data_n)
    );

endmodule 