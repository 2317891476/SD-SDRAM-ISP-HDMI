//****************************************Copyright (c)***********************************//
//ԭ�Ӹ����߽�ѧƽ̨��www.yuanzige.com
//����֧�֣�www.openedv.com
//�Ա����̣�http://openedv.taobao.com
//��ע΢�Ź���ƽ̨΢�źţ�"����ԭ��"����ѻ�ȡZYNQ & FPGA & STM32 & LINUX���ϡ�
//��Ȩ���У�����ؾ���
//Copyright(C) ����ԭ�� 2018-2028
//All rights reserved
//----------------------------------------------------------------------------------------
// File name:           hdmi_top
// Last modified Date:  2020/05/04 9:19:08
// Last Version:        V1.0
// Descriptions:        HDMI��ʾ����ģ��
//                      
//----------------------------------------------------------------------------------------
// Created by:          ����ԭ��
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
   //hdmi�ӿ� 
    output          tmds_clk_p,     // TMDS ʱ��ͨ��
    //output          tmds_clk_n,
    output [2:0]    tmds_data_p,    // TMDS ����ͨ��
    //output [2:0]    tmds_data_n,
   //�û��ӿ� 
    output          video_vs,       //HDMI���ź�      
    output  [10:0]  pixel_xpos,     //���ص������
    output  [10:0]  pixel_ypos,     //���ص�������      
    input   [15:0]  data_in,        //��������
    output          data_req        //������������   
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

//������ͷ16bit����ת��Ϊ24bit��hdmi����
// assign video_rgb = {video_rgb_565[15:11],3'b000,video_rgb_565[10:5],2'b00,
//                     video_rgb_565[4:0],3'b000};  

//ת��RGB444����
assign video_rgb = {out_raw[14:11],out_raw[8:5],
                   out_raw[3:0]};  

//������Ƶ��ʾ����ģ��
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

        .threshold(0), //��ֵԽС,���Խ��,��������Խ��

        .in_href(video_hs),
        .in_vsync(video_vs),
        .in_raw(video_rgb_565),

        .out_href(out_href),
        .out_vsync(out_vsync),
        .out_raw(out_raw)
   );

//����HDMI����ģ��
hdmi_tx #(.FAMILY("EG4"))	//EF2��EF3��EG4��AL3��PH1

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