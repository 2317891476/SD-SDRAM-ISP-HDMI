module read_rawdata(
    input                clk           ,  //时钟信号
    input                rst_n         ,  //复位信号,低电平有效
    input        [1:0]   switch_video  ,
    input        [20:0]  ddr_max_addr  ,  //DDR读写最大地址  
    input        [25:0]  sd_sec_num    ,  //SD卡读扇区个数
    input                rd_busy       ,  //SD卡读忙信号
    input                sd_rd_val_en  ,  //SD卡读数据有效信号
    input        [15:0]  sd_rd_val_data,  //SD卡读出的数据
    output  reg          rd_start_en   ,  //开始写SD卡数据信号
    output  reg  [31:0]  rd_sec_addr   ,  //读数据扇区地址
    output  reg          ddr_wr_en     ,  //DDR写使能信号
    output       [15:0]  ddr_wr_data      //DDR写数据
    );

//parameter define                          
//设置两张图片的扇区地址,通过上位机WinHex软件查看
parameter PHOTO_SECTION_ADDR0 = 32'd16640;//第一张图片扇区起始地址

parameter PHOTO_SECTION_ADDR1 = 32'd2978816;//第二张图片扇区起始地址
//BMP文件首部长度=BMP文件头+信息头
//parameter BMP_HEAD_NUM = 6'd54;           //BMP文件头+信息头=14+40=54

//每一帧图像的头部数据1936*4*2字节数，但是一次读取2字节，所以无需*2
//parameter PIC_HEAD_NUM = 15'd30976;
parameter PIC_HEAD_NUM = 15'd7744;
parameter PIC_END_NUM = 15'd7744;
parameter PIC_ROW_NUM = 11'd1088;
//reg define
reg    [1:0]          rd_flow_cnt      ;  //读数据流程控制计数器
reg    [25:0]         rd_sec_cnt       ;  //读扇区次数计数器
reg                   rd_addr_sw       ;  //读两张图片切换
reg    [25:0]         delay_cnt        ;  //延时切换图片计数器
reg                   bmp_rd_done      ;  //单张图片读取完成

reg                   rd_busy_d0       ;  //读忙信号打拍，用来采下降沿
reg                   rd_busy_d1       ;  

//reg    [1:0]          val_en_cnt       ;  //SD卡数据有效计数器
//reg    [15:0]         val_data_t       ;  //SD卡数据有效寄存
//reg    [5:0]          bmp_head_cnt     ;  //BMP首部计数器
//reg                   bmp_head_flag    ;  //BMP首部标志
//reg    [23:0]         rgb888_data      ;  //24位RGB888数据
//reg    [23:0]         ddr_wr_cnt       ;  //DDR写入计数器
reg    [3:0]          ddr_flow_cnt     ;  //DDR写数据流程控制器计数器

//wire define
wire                  neg_rd_busy      ;  //SD卡读忙信号下降沿
      
//*****************************************************
//**                    main code
//*****************************************************
parameter R = 2'b00,G = 2'b01,B = 2'b10;
//状态定义
parameter   PIC_HEAD = 4'b0,
            ROW_HEAD = 4'b1,
            ROW_DATA = 4'b10,
            ROW_END  = 4'b11,
            ROW_STATE_CHA = 4'b101,
            PIC_END  = 4'b100,
            IDLE = 4'b110;
//行状态
parameter row_G = 1'b0,row_R = 1'b1;
assign  neg_rd_busy = rd_busy_d1 & (~rd_busy_d0);
//24位RGB888格式转成16位RGB565格式
//assign  ddr_wr_data = {rgb888_data[23:19],rgb888_data[15:10],rgb888_data[7:3]};

//对rd_busy信号进行延时打拍,用于采rd_busy信号的下降沿
always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0) begin
        rd_busy_d0 <= 1'b0;
        rd_busy_d1 <= 1'b0;
    end
    else begin
        rd_busy_d0 <= rd_busy;
        rd_busy_d1 <= rd_busy_d0;
    end
end

//循环读取SD卡中的两张图片（读完之后延时1s再读下一个）
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        rd_flow_cnt <= 2'd0;
        rd_addr_sw <= 1'b0;
        rd_sec_cnt <= 26'd0;
        rd_start_en <= 1'b0;
        rd_sec_addr <= 32'd0;
        //delay_cnt <= 26'd0;
    end
    else begin
        rd_start_en <= 1'b0;
        case(rd_flow_cnt)
            2'd0 : begin
                //开始读取SD卡数据
                rd_flow_cnt <= rd_flow_cnt + 2'd1;
                rd_start_en <= 1'b1;
                case (switch_video)
                    2'b01:
                        rd_sec_addr <= PHOTO_SECTION_ADDR1;
                    default:
                        rd_sec_addr <= PHOTO_SECTION_ADDR0;
                endcase
            end
            2'd1 : begin
                //读忙信号的下降沿代表读完一个扇区,开始读取下一扇区地址数据
                if(neg_rd_busy) begin                          
                    rd_sec_cnt <= rd_sec_cnt + 1'b1;
                    rd_sec_addr <= rd_sec_addr + 32'd1;
					//单轮视频读完
                    if(rd_sec_cnt == sd_sec_num - 4'd1) begin
                        rd_sec_cnt <= 26'd0;
                        rd_flow_cnt <= 2'd0;
                        bmp_rd_done <= 1'b1;
                    end    
                    else
                        rd_start_en <= 1'b1;                   
                end                    
            end
            
            default : ;
        endcase    
    end
end


reg [3:0] row_head_cnt,row_end_cnt;
reg [11:0] row_data_cnt;
reg [11:0] row_cnt;
reg row_state,pixel_state;
reg [15:0] ddr_wr_datar;
reg [14:0] pic_head_cnt,pic_end_cnt;
reg [10:0] pic_cnt;

//DDR3状态转换机
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        ddr_wr_datar <= 16'd0; 
        pic_head_cnt <= 15'd0;
        pic_end_cnt <= 15'd0;
        ddr_wr_en <= 1'b0;
        ddr_flow_cnt <= PIC_HEAD;//表示ddr阶段
        row_cnt <=12'b0;
        row_head_cnt<= 4'b0;
        row_end_cnt<=4'b0;
        row_data_cnt <=12'b0;
        row_state <=row_G;
        pixel_state <= G;
    end
    else begin
        ddr_wr_en <= 1'b0;
        case(ddr_flow_cnt)
            PIC_HEAD : begin   //pic首部         
                if(sd_rd_val_en) begin
                    pic_head_cnt <= pic_head_cnt + 1'b1;
                    if(pic_head_cnt == PIC_HEAD_NUM - 1'b1) begin
                        ddr_flow_cnt <= ROW_HEAD;
                        pic_head_cnt <= 15'd0;
                        row_state <= row_G;
                    end    
                end   
            end 
            ROW_HEAD:begin
                if(sd_rd_val_en) begin
                    row_head_cnt <= row_head_cnt + 1'b1;
                    if(row_head_cnt == 7) begin
                        ddr_flow_cnt <= ROW_DATA;
                        row_head_cnt <= 4'd0;
                    end    
                end   
            end
            ROW_DATA:begin
                if(sd_rd_val_en) begin
                    row_data_cnt <= row_data_cnt+1;
                    if (row_data_cnt ==1919) begin
                        ddr_flow_cnt <=ROW_END;
                        row_data_cnt <= 12'b0;
                    end
                    if (row_state == row_G) begin
                        if(pixel_state==G) begin 
                            pixel_state<= B;
                            case (switch_video)
                                2'b0:
                                    ddr_wr_datar <= {5'b0,sd_rd_val_data[15:10],5'b0};
                                2'b10:
                                    ddr_wr_datar <= {5'b0,sd_rd_val_data[9:4],5'b0};
                                2'b01:
                                    ddr_wr_datar <= sd_rd_val_data;
                                default:ddr_wr_datar <= {4'b0,sd_rd_val_data[15:4]};
                            endcase
                            ddr_wr_en <= 1'b1;
                        end
                        //Bas'
                         
                        else begin
                            pixel_state <=G;
                            case (switch_video)
                                2'b0:
                                    ddr_wr_datar <= {5'b0,6'b0,sd_rd_val_data[15:11]};
                                2'b10:
                                    ddr_wr_datar <= {5'b0,6'b0,sd_rd_val_data[8:4]};
                                2'b01:
                                    ddr_wr_datar <= sd_rd_val_data;
                                default:ddr_wr_datar <= {4'b0,sd_rd_val_data[15:4]};
                            endcase
                            ddr_wr_en <= 1'b1;
                        end
                    end
                    //row_R
                    else begin
                        if (pixel_state == R) begin
                            pixel_state<= G;
                            case (switch_video)
                                2'b0:
                                    ddr_wr_datar <= {sd_rd_val_data[15:11],6'b0,5'b0};
                                2'b10:
                                    ddr_wr_datar <= {sd_rd_val_data[8:4],6'b0,5'b0};
                                2'b01:
                                    ddr_wr_datar <= sd_rd_val_data;
                                default:ddr_wr_datar <= {4'b0,sd_rd_val_data[15:4]};
                            endcase
                            ddr_wr_en <= 1'b1;
                        end
                        //G
                        else begin
                            pixel_state<= R;
                            case (switch_video)
                                2'b0:
                                    ddr_wr_datar <= {5'b0,sd_rd_val_data[15:10],5'b0};
                                2'b10:
                                    ddr_wr_datar <= {5'b0,sd_rd_val_data[9:4],5'b0};
                                2'b01:
                                    ddr_wr_datar <= sd_rd_val_data;
                                default:ddr_wr_datar <= {4'b0,sd_rd_val_data[15:4]};
                            endcase
                            ddr_wr_en <= 1'b1;
                        end
                    end
                end    
            end
            ROW_END:begin
                if(sd_rd_val_en) begin
                    row_end_cnt <= row_end_cnt + 1'b1;
                    if(row_end_cnt == 7) begin
                        row_cnt <=row_cnt +1;
                        if (row_cnt == 1079) begin
                            row_cnt <= 12'b0;
                            ddr_flow_cnt <= PIC_END;
                        end
                        else ddr_flow_cnt <=ROW_STATE_CHA;
                        row_end_cnt <= 4'd0;
                    end    
                end   
            end             
            ROW_STATE_CHA:begin
                if (row_state == row_G) begin
                    row_state<= row_R;
                    pixel_state <=R;
                    ddr_flow_cnt <=ROW_HEAD;
                end
                else begin
                    row_state<= row_G;
                    pixel_state <=G;
                    ddr_flow_cnt <=ROW_HEAD;
                end
            end  
            PIC_END:begin
                if(sd_rd_val_en) begin
                    pic_end_cnt <= pic_end_cnt + 1'b1;
                    if(pic_end_cnt == PIC_END_NUM-1) begin
                        ddr_flow_cnt <= PIC_HEAD;
                        pic_end_cnt <= 15'd0;
                    end    
                end   
            end
            
            default :;
        endcase
    end
end

assign  ddr_wr_data = ddr_wr_datar;
endmodule
