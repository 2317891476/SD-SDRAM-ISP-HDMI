//****************************************Copyright (c)***********************************//
//ԭ�Ӹ����߽�ѧƽ̨��www.yuanzige.com
//����֧�֣�www.openedv.com
//�Ա����̣�http://openedv.taobao.com
//��ע΢�Ź���ƽ̨΢�źţ�"����ԭ��"����ѻ�ȡZYNQ & FPGA & STM32 & LINUX���ϡ�
//��Ȩ���У�����ؾ���
//Copyright(C) ����ԭ�� 2018-2028
//All rights reserved
//----------------------------------------------------------------------------------------
// File name:           sd_bmp_hdmi
// Last modified Date:  2020/11/22 15:16:38
// Last Version:        V1.0
// Descriptions:        SD����BMPͼƬHDMI��ʾ
//                      
//----------------------------------------------------------------------------------------
// Created by:          ����ԭ��
// Created date:        2020/11/22 15:16:38
// Version:             V1.0
// Descriptions:        The original version
//
//----------------------------------------------------------------------------------------
//****************************************************************************************//

module sd_bmp_hdmi(    
    input                 sys_clk      ,  //ϵͳʱ��
    input                 sys_rst_n    ,  //ϵͳ��λ���͵�ƽ��Ч
    //SD���ӿ�
    input                 sd_miso      ,  //SD��SPI�������������ź�
    output                sd_clk       ,  //SD��SPIʱ���ź�
    output                sd_cs        ,  //SD��SPIƬѡ�ź�
    output                sd_mosi      ,  //SD��SPI������������ź�     
    // DDR3                            
    //inout   [15:0]        ddr3_dq      ,  //DDR3 ����
    //	inout   [3:0]         ddr3_dqs_n   ,  //DDR3 dqs��
    //	inout   [3:0]         ddr3_dqs_p   ,  //DDR3 dqs��  
    //output  [10:0]        ddr3_addr    ,  //DDR3 ��ַ   
    //output  [2:0]         ddr3_ba      ,  //DDR3 banck ѡ��
    //output                ddr3_ras_n   ,  //DDR3 ��ѡ��
    //output                ddr3_cas_n   ,  //DDR3 ��ѡ��
    //output                ddr3_we_n    ,  //DDR3 ��дѡ��
    //	output                ddr3_reset_n ,  //DDR3 ��λ
    //	output  [0:0]         ddr3_ck_p    ,  //DDR3 ʱ����
    //	output  [0:0]         ddr3_ck_n    ,  //DDR3 ʱ�Ӹ�
    //output  [0:0]         ddr3_cke     ,  //DDR3 ʱ��ʹ��
    //output  [0:0]         ddr3_cs_n    ,  //DDR3 Ƭѡ
    //output  [3:0]         ddr3_dm      ,  //DDR3_dm
    //	output  [0:0]         ddr3_odt     ,  //DDR3_odt
    input 			[1:0]	switch_video,									                            
    //hdmi�ӿ�                             
    output                tmds_clk_p   ,  // TMDS ʱ��ͨ��
    //	output                tmds_clk_n   ,
    output  [2:0]         tmds_data_p    // TMDS ����ͨ��
    //	output  [2:0]         tmds_data_n  
    );

//parameter define 
//parameter  V_CMOS_DISP = 11'd768;                  //CMOS�ֱ���--��
//parameter  V_CMOS_DISP = 11'd768;   
//parameter  H_CMOS_DISP = 11'd1024;                 //CMOS�ֱ���--��	
//parameter  H_CMOS_DISP = 11'd480;
//DDR3��д����ַ 1024 * 768 = 786432
//parameter  DDR_MAX_ADDR = 21'd786432 ; 
 
parameter  DDR_MAX_ADDR = 21'd2073600 ; 
//SD������������ 1024 * 768 * 3 / 512 + 1 = 4609
parameter  SD_SEC_NUM = 26'd740521;    
//parameter  SD_SEC_NUM = 16'd4609;    

//wire define
wire   [15:0]        ddr3_dq      ;  //DDR3 ����
wire  [10:0]        ddr3_addr    ;  //DDR3 ��ַ   
wire  [2:0]         ddr3_ba      ;  //DDR3 banck ѡ��
wire                ddr3_ras_n   ;  //DDR3 ��ѡ��
wire                ddr3_cas_n   ;  //DDR3 ��ѡ��
wire                ddr3_we_n    ;  //DDR3 ��дѡ��
wire  [0:0]         ddr3_cke     ;  //DDR3 ʱ��ʹ��
wire  [0:0]         ddr3_cs_n    ;  //DDR3 Ƭѡ
wire  [3:0]         ddr3_dm      ;  //DDR3_dm  
                        
wire         clk_200m                  ;  //ddr3�ο�ʱ��
wire         clk_50m                   ;  //50mhzʱ��
wire         pixel_clk_5x              ;  //HDMI����ʱ��
wire         pixel_clk                 ;  //HDMI 5������ʱ��
wire         clk_sd_180deg            ;  //50mhzʱ��,��λƫ��180��
wire         clk_sd            			;  //50mhzʱ��,��λƫ��180��
wire         locked                    ;  //ʱ�������ź�
wire         rst_n                     ;  //ȫ�ָ�λ 	

wire  [27:0] ddr_max_addr              ;  //DDR��д����ַ
wire  [15:0] sd_sec_num                ;  //SD������������
wire         sd_rd_start_en            ;  //��ʼдSD�������ź�
wire  [31:0] sd_rd_sec_addr            ;  //������������ַ    
wire         sd_rd_busy                ;  //��æ�ź�
wire         sd_rd_val_en              ;  //���ݶ�ȡ��Чʹ���ź�
wire  [15:0] sd_rd_val_data            ;  //������
wire         sd_init_done              ;  //SD����ʼ������ź�	
wire         ddr_wr_en                 ;  //DDR3������ģ��дʹ��
wire  [15:0] ddr_wr_data               ;  //DDR3������ģ��д����

wire         wr_en                     ;  //DDR3������ģ��дʹ��
wire  [15:0] wr_data                   ;  //DDR3������ģ��д����
wire         rdata_req                 ;  //DDR3������ģ���ʹ��
wire  [15:0] rd_data,rd_data1                   ;  //DDR3������ģ�������
wire         init_calib_complete       ;  //DDR3��ʼ�����init_calib_complete
wire         sys_init_done             ;  //ϵͳ��ʼ�����(DDR��ʼ��+����ͷ��ʼ��)

//*****************************************************
//**                    main code
//*****************************************************

//��ʱ�������������λ�����ź�
assign  rst_n = sys_rst_n & locked;
//ϵͳ��ʼ����ɣ�DDR3��ʼ����� & SD����ʼ�����
assign  sys_init_done = init_calib_complete & sd_init_done;
//DDR3������ģ��Ϊдʹ�ܺ�д���ݸ�ֵ
assign  wr_en = ddr_wr_en;
assign  wr_data = ddr_wr_data;

//��ȡSD��ͼƬ
read_rawdata u_sd_read_photo(
    .clk                      (clk_sd),
    .switch_video       (switch_video),
    //ϵͳ��ʼ�����֮��,�ٿ�ʼ��SD���ж�ȡͼƬ
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

//SD���������ģ��
sd_ctrl_top u_sd_ctrl_top(
    .clk_ref                  (clk_sd),
    .clk_ref_180deg           (clk_sd_180deg),
    .rst_n                    (rst_n),
    //SD���ӿ�                
    .sd_miso                  (sd_miso),
    .sd_clk                   (sd_clk),
    .sd_cs                    (sd_cs),
    .sd_mosi                  (sd_mosi),
    //�û�дSD���ӿ�
    .wr_start_en              (1'b0),                      //����Ҫд������,д��ӿڸ�ֵΪ0
    .wr_sec_addr              (32'b0),
    .wr_data                  (16'b0),
    .wr_busy                  (),
    .wr_req                   (),
    //�û���SD���ӿ�
    .rd_start_en              (sd_rd_start_en),
    .rd_sec_addr              (sd_rd_sec_addr),
    .rd_busy                  (sd_rd_busy),
    .rd_val_en                (sd_rd_val_en),
    .rd_val_data              (sd_rd_val_data),    
    
    .sd_init_done             (sd_init_done)
    );

//DDR3ģ��
ddr3_top1 u_ddr3_top (
    .ref_clk                (clk_50m),                  //�û�ʱ��           0
    .clk_sdram                (clk_200m),                  //ddr3�ο�ʱ��     0
    .rst_n                    (rst_n),                 //��λ,����Ч          0
    .sys_init_done            (sys_init_done),         //ϵͳ��ʼ�����        0
    .sdram_init_done      (init_calib_complete),   //ddr3��ʼ������ź�    0
    //ddr3�ӿ��ź�         
    .rd_min_addr          (21'd0),                 //��DDR3����ʼ��ַ       0
    .rd_max_addr          (DDR_MAX_ADDR+1),          //��DDR3�Ľ�����ַ  0
    .rd_len              (9'd256),          //��DDR3�ж�����ʱ��ͻ������ 0
    .wr_min_addr          (21'd0),                 //дDDR3����ʼ��ַ          0
    .wr_max_addr          (DDR_MAX_ADDR+1),          //дDDR3�Ľ�����ַ  0
    .wr_len               (9'd256),          //��DDR3��д����ʱ��ͻ������ 0
    // DDR3 IO�ӿ�              
    //.sdram_data                  (ddr3_dq),               //DDR3 ����     0
    //.ddr3_dqs_n               (ddr3_dqs_n),            //DDR3 dqs��
    //.ddr3_dqs_p               (ddr3_dqs_p),            //DDR3 dqs��  
    //.sdram_addr                (ddr3_addr),        //DDR3 ��ַ       0��λ���д��޸ģ�
    //.sdram_ba                  (ddr3_ba),               //DDR3 banck ѡ�� 0
    //.sdram_ras_n               (ddr3_ras_n),            //DDR3 ��ѡ��   0
    //.sdram_cas_n               (ddr3_cas_n),            //DDR3 ��ѡ��   0
    //.sdram_we_n                (ddr3_we_n),             //DDR3 ��дѡ��  0
    //.ddr3_reset_n             (ddr3_reset_n),          //DDR3 ��λ
    //.ddr3_ck_p                (ddr3_ck_p),             //DDR3 ʱ����
    //.ddr3_ck_n                (ddr3_ck_n),             //DDR3 ʱ�Ӹ�  
    //.sdram_cke                 (ddr3_cke),              //DDR3 ʱ��ʹ��    0
    //.sdram_cs_n                (ddr3_cs_n),             //DDR3 Ƭѡ       0
    //.sdram_dqm                  (ddr3_dm[1:0]),         //DDR3_dm �������� 0
    //.ddr3_odt                 (ddr3_odt),              //DDR3_odt
    //�û�
    .sdram_read_valid          (1'b1),                  //DDR3 ��ʹ��        0
    .ddr3_pingpang_en         (1'b0),                  //DDR3 ƹ�Ҳ���ʹ��     0
    .wr_clk                   (clk_sd),               //дʱ��              0
    .wr_load                  (1'b0),                  //����Դ�����ź�        0
    .wr_en                    (wr_en),                 //������Чʹ���ź�        0
    .wr_data                   (wr_data),               //��Ч����            0
    .rd_clk                   (pixel_clk),             //��ʱ��              0
    .rd_load                  (rd_vsync),              //���Դ�����ź�        0
    .rd_data                   (rd_data),               //rfifo������� 16λ  0
    .rd_en                    (rdata_req)              //������������         0
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
//HDMI������ʾģ��    
hdmi_top1 u_hdmi_top(
    .pixel_clk                (pixel_clk),
    .pixel_clk_5x             (pixel_clk_5x),    
    .sys_rst_n                (sys_init_done & rst_n),
    //hdmi�ӿ�                      
    .tmds_clk_p               (tmds_clk_p   ),   // TMDS ʱ��ͨ��
    //.tmds_clk_n               (tmds_clk_n   ),
    .tmds_data_p              (tmds_data_p  ),   // TMDS ����ͨ��
    //.tmds_data_n              (tmds_data_n  ),
    //�û��ӿ�                
    .video_vs                 (rd_vsync     ),   //HDMI���ź�  
    .pixel_xpos               (),
    .pixel_ypos               (),      
    .data_in                  (rd_data),         //�������� 
    .data_req                 (rdata_req)        //������������   
);   

endmodule