//****************************************Copyright (c)***********************************//
//原子哥在线教学平台：www.yuanzige.com
//技术支持：www.openedv.com
//淘宝店铺：http://openedv.taobao.com
//关注微信公众平台微信号："正点原子"，免费获取ZYNQ & FPGA & STM32 & LINUX资料。
//版权所有，盗版必究。
//Copyright(C) 正点原子 2018-2028
//All rights reserved
//----------------------------------------------------------------------------------------
// File name:           sd_bmp_hdmi
// Last modified Date:  2020/11/22 15:16:38
// Last Version:        V1.0
// Descriptions:        SD卡读BMP图片HDMI显示
//                      
//----------------------------------------------------------------------------------------
// Created by:          正点原子
// Created date:        2020/11/22 15:16:38
// Version:             V1.0
// Descriptions:        The original version
//
//----------------------------------------------------------------------------------------
//****************************************************************************************//

module sd_bmp_hdmi(    
    input                 sys_clk      ,  //系统时钟
    input                 sys_rst_n    ,  //系统复位，低电平有效
    //SD卡接口
    input                 sd_miso      ,  //SD卡SPI串行输入数据信号
    output                sd_clk       ,  //SD卡SPI时钟信号
    output                sd_cs        ,  //SD卡SPI片选信号
    output                sd_mosi      ,  //SD卡SPI串行输出数据信号     
    // DDR3                            
    //inout   [15:0]        ddr3_dq      ,  //DDR3 数据
    //	inout   [3:0]         ddr3_dqs_n   ,  //DDR3 dqs负
    //	inout   [3:0]         ddr3_dqs_p   ,  //DDR3 dqs正  
    //output  [10:0]        ddr3_addr    ,  //DDR3 地址   
    //output  [2:0]         ddr3_ba      ,  //DDR3 banck 选择
    //output                ddr3_ras_n   ,  //DDR3 行选择
    //output                ddr3_cas_n   ,  //DDR3 列选择
    //output                ddr3_we_n    ,  //DDR3 读写选择
    //	output                ddr3_reset_n ,  //DDR3 复位
    //	output  [0:0]         ddr3_ck_p    ,  //DDR3 时钟正
    //	output  [0:0]         ddr3_ck_n    ,  //DDR3 时钟负
    //output  [0:0]         ddr3_cke     ,  //DDR3 时钟使能
    //output  [0:0]         ddr3_cs_n    ,  //DDR3 片选
    //output  [3:0]         ddr3_dm      ,  //DDR3_dm
    //	output  [0:0]         ddr3_odt     ,  //DDR3_odt
    input 			[1:0]	switch_video,									                            
    //hdmi接口                             
    output                tmds_clk_p   ,  // TMDS 时钟通道
    //	output                tmds_clk_n   ,
    output  [2:0]         tmds_data_p    // TMDS 数据通道
    //	output  [2:0]         tmds_data_n  
    );

//parameter define 
//parameter  V_CMOS_DISP = 11'd768;                  //CMOS分辨率--行
//parameter  V_CMOS_DISP = 11'd768;   
//parameter  H_CMOS_DISP = 11'd1024;                 //CMOS分辨率--列	
//parameter  H_CMOS_DISP = 11'd480;
//DDR3读写最大地址 1024 * 768 = 786432
//parameter  DDR_MAX_ADDR = 21'd786432 ; 
 
parameter  DDR_MAX_ADDR = 21'd2073600 ; 
//SD卡读扇区个数 1024 * 768 * 3 / 512 + 1 = 4609
parameter  SD_SEC_NUM = 26'd740521;    
//parameter  SD_SEC_NUM = 16'd4609;    

//wire define
wire   [15:0]        ddr3_dq      ;  //DDR3 数据
wire  [10:0]        ddr3_addr    ;  //DDR3 地址   
wire  [2:0]         ddr3_ba      ;  //DDR3 banck 选择
wire                ddr3_ras_n   ;  //DDR3 行选择
wire                ddr3_cas_n   ;  //DDR3 列选择
wire                ddr3_we_n    ;  //DDR3 读写选择
wire  [0:0]         ddr3_cke     ;  //DDR3 时钟使能
wire  [0:0]         ddr3_cs_n    ;  //DDR3 片选
wire  [3:0]         ddr3_dm      ;  //DDR3_dm  
                        
wire         clk_200m                  ;  //ddr3参考时钟
wire         clk_50m                   ;  //50mhz时钟
wire         pixel_clk_5x              ;  //HDMI像素时钟
wire         pixel_clk                 ;  //HDMI 5倍像素时钟
wire         clk_sd_180deg            ;  //50mhz时钟,相位偏移180度
wire         clk_sd            			;  //50mhz时钟,相位偏移180度
wire         locked                    ;  //时钟锁定信号
wire         rst_n                     ;  //全局复位 	

wire  [27:0] ddr_max_addr              ;  //DDR读写最大地址
wire  [15:0] sd_sec_num                ;  //SD卡读扇区个数
wire         sd_rd_start_en            ;  //开始写SD卡数据信号
wire  [31:0] sd_rd_sec_addr            ;  //读数据扇区地址    
wire         sd_rd_busy                ;  //读忙信号
wire         sd_rd_val_en              ;  //数据读取有效使能信号
wire  [15:0] sd_rd_val_data            ;  //读数据
wire         sd_init_done              ;  //SD卡初始化完成信号	
wire         ddr_wr_en                 ;  //DDR3控制器模块写使能
wire  [15:0] ddr_wr_data               ;  //DDR3控制器模块写数据

wire         wr_en                     ;  //DDR3控制器模块写使能
wire  [15:0] wr_data                   ;  //DDR3控制器模块写数据
wire         rdata_req                 ;  //DDR3控制器模块读使能
wire  [15:0] rd_data,rd_data1                   ;  //DDR3控制器模块读数据
wire         init_calib_complete       ;  //DDR3初始化完成init_calib_complete
wire         sys_init_done             ;  //系统初始化完成(DDR初始化+摄像头初始化)

//*****************************************************
//**                    main code
//*****************************************************

//待时钟锁定后产生复位结束信号
assign  rst_n = sys_rst_n & locked;
//系统初始化完成：DDR3初始化完成 & SD卡初始化完成
assign  sys_init_done = init_calib_complete & sd_init_done;
//DDR3控制器模块为写使能和写数据赋值
assign  wr_en = ddr_wr_en;
assign  wr_data = ddr_wr_data;

//读取SD卡图片
read_rawdata u_sd_read_photo(
    .clk                      (clk_sd),
    .switch_video       (switch_video),
    //系统初始化完成之后,再开始从SD卡中读取图片
    .rst_n                    (rst_n & sys_init_done), 
    .ddr_max_addr             (DDR_MAX_ADDR),       
    .sd_sec_num               (SD_SEC_NUM), 
    .rd_busy                  (sd_rd_busy),
    .sd_rd_val_en             (sd_rd_val_en),
    .sd_rd_val_data           (sd_rd_val_data),
    .rd_start_en              (sd_rd_start_en),
    .rd_sec_addr              (sd_rd_sec_addr),
    .ddr_wr_en                (ddr_wr_en),
    .ddr_wr_data              (ddr_wr_data)
    );     

//SD卡顶层控制模块
sd_ctrl_top u_sd_ctrl_top(
    .clk_ref                  (clk_sd),
    .clk_ref_180deg           (clk_sd_180deg),
    .rst_n                    (rst_n),
    //SD卡接口                
    .sd_miso                  (sd_miso),
    .sd_clk                   (sd_clk),
    .sd_cs                    (sd_cs),
    .sd_mosi                  (sd_mosi),
    //用户写SD卡接口
    .wr_start_en              (1'b0),                      //不需要写入数据,写入接口赋值为0
    .wr_sec_addr              (32'b0),
    .wr_data                  (16'b0),
    .wr_busy                  (),
    .wr_req                   (),
    //用户读SD卡接口
    .rd_start_en              (sd_rd_start_en),
    .rd_sec_addr              (sd_rd_sec_addr),
    .rd_busy                  (sd_rd_busy),
    .rd_val_en                (sd_rd_val_en),
    .rd_val_data              (sd_rd_val_data),    
    
    .sd_init_done             (sd_init_done)
    );

//DDR3模块
ddr3_top1 u_ddr3_top (
    .ref_clk                (clk_50m),                  //用户时钟           0
    .clk_sdram                (clk_200m),                  //ddr3参考时钟     0
    .rst_n                    (rst_n),                 //复位,低有效          0
    .sys_init_done            (sys_init_done),         //系统初始化完成        0
    .sdram_init_done      (init_calib_complete),   //ddr3初始化完成信号    0
    //ddr3接口信号         
    .rd_min_addr          (21'd0),                 //读DDR3的起始地址       0
    .rd_max_addr          (DDR_MAX_ADDR+1),          //读DDR3的结束地址  0
    .rd_len              (9'd256),          //从DDR3中读数据时的突发长度 0
    .wr_min_addr          (21'd0),                 //写DDR3的起始地址          0
    .wr_max_addr          (DDR_MAX_ADDR+1),          //写DDR3的结束地址  0
    .wr_len               (9'd256),          //从DDR3中写数据时的突发长度 0
    // DDR3 IO接口              
    //.sdram_data                  (ddr3_dq),               //DDR3 数据     0
    //.ddr3_dqs_n               (ddr3_dqs_n),            //DDR3 dqs负
    //.ddr3_dqs_p               (ddr3_dqs_p),            //DDR3 dqs正  
    //.sdram_addr                (ddr3_addr),        //DDR3 地址       0（位宽有待修改）
    //.sdram_ba                  (ddr3_ba),               //DDR3 banck 选择 0
    //.sdram_ras_n               (ddr3_ras_n),            //DDR3 行选择   0
    //.sdram_cas_n               (ddr3_cas_n),            //DDR3 列选择   0
    //.sdram_we_n                (ddr3_we_n),             //DDR3 读写选择  0
    //.ddr3_reset_n             (ddr3_reset_n),          //DDR3 复位
    //.ddr3_ck_p                (ddr3_ck_p),             //DDR3 时钟正
    //.ddr3_ck_n                (ddr3_ck_n),             //DDR3 时钟负  
    //.sdram_cke                 (ddr3_cke),              //DDR3 时钟使能    0
    //.sdram_cs_n                (ddr3_cs_n),             //DDR3 片选       0
    //.sdram_dqm                  (ddr3_dm[1:0]),         //DDR3_dm 数据掩码 0
    //.ddr3_odt                 (ddr3_odt),              //DDR3_odt
    //用户
    .sdram_read_valid          (1'b1),                  //DDR3 读使能        0
    .ddr3_pingpang_en         (1'b0),                  //DDR3 乒乓操作使能     0
    .wr_clk                   (clk_sd),               //写时钟              0
    .wr_load                  (1'b0),                  //输入源更新信号        0
    .wr_en                    (wr_en),                 //数据有效使能信号        0
    .wr_data                   (wr_data),               //有效数据            0
    .rd_clk                   (pixel_clk),             //读时钟              0
    .rd_load                  (rd_vsync),              //输出源更新信号        0
    .rd_data                   (rd_data),               //rfifo输出数据 16位  0
    .rd_en                    (rdata_req)              //请求数据输入         0
     );       

 PLL u_clk_wiz_0
   (
    // Clock out ports
    .clk0_out                 (clk_50m),     
    .clk1_out                 (clk_200m),
    //.clk2_out                (pixel_clk_5x),//300Mhz
    .clk3_out                 (clk_sd), //60Mhz
    .clk4_out                 (clk_sd_180deg),
    // Status and control signals
    .reset                    (1'b0), 
    .extlock                   (locked),       
   // Clock in ports
    .refclk                  (sys_clk)
    );
    PLL_hdmi u_clk_wiz_1
   (
    // Clock out ports
    .clk0_out                 (pixel_clk_5x),     
    .clk1_out                 (pixel_clk),
    //.clk2_out                (pixel_clk_5x),//300Mhz
    //.clk3_out                 (pixel_clk), //60Mhz
    //.clk4_out                 (clk_50m_180deg),
    // Status and control signals
    .reset                    (1'b0), 
    //.extlock                   (locked),       
   // Clock in ports
    .refclk                  (sys_clk)
    );          
 //assign rd_data = 16'h5424;
//HDMI驱动显示模块    
hdmi_top1 u_hdmi_top(
    .pixel_clk                (pixel_clk),
    .pixel_clk_5x             (pixel_clk_5x),    
    .sys_rst_n                (sys_init_done & rst_n),
    //hdmi接口                      
    .tmds_clk_p               (tmds_clk_p   ),   // TMDS 时钟通道
    //.tmds_clk_n               (tmds_clk_n   ),
    .tmds_data_p              (tmds_data_p  ),   // TMDS 数据通道
    //.tmds_data_n              (tmds_data_n  ),
    //用户接口                
    .video_vs                 (rd_vsync     ),   //HDMI场信号  
    .pixel_xpos               (),
    .pixel_ypos               (),      
    .data_in                  (rd_data),         //数据输入 
    .data_req                 (rdata_req)        //请求数据输入   
);   

endmodule