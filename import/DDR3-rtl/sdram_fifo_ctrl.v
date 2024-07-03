module sdram_fifo_ctrl(
	input             clk_ref,		     //SDRAM控制器时钟
	input             rst_n,			 //系统复位 
                                         
    //用户写端口                         
	input             clk_write,		 //写端口FIFO: 写时钟 
	input             wrf_wrreq,		 //写端口FIFO: 写请求 
	input      [15:0] wrf_din,		     //写端口FIFO: 写数据	
	input      [20:0] wr_min_addr,	     //写SDRAM的起始地址
	input      [20:0] wr_max_addr,	     //写SDRAM的结束地址
 	input      [ 8:0] wr_length,		 //写SDRAM时的数据突发长度 
	input             wr_load,		     //写端口复位: 复位写地址,清空写FIFO 
                                         
    //用户读端口                         
	input             clk_read,		     //读端口FIFO: 读时钟
	input             rdf_rdreq,		 //读端口FIFO: 读请求 
	output     [15:0] rdf_dout,		     //读端口FIFO: 读数据
	input      [20:0] rd_min_addr,	     //读SDRAM的起始地址
	input      [20:0] rd_max_addr,	     //读SDRAM的结束地址
	input      [ 8:0] rd_length,		 //从SDRAM中读数据时的突发长度 
	input             rd_load,		     //读端口复位: 复位读地址,清空读FIFO
	                                     
	//用户控制端口	                     
	input             sdram_read_valid,  //SDRAM 读使能
	input             sdram_init_done,   //SDRAM 初始化完成标志
    
    input  ddr3_pingpang_en,                 
                       
    //SDRAM 控制器写端口                 
	output reg		  sdram_wr_req,	     //sdram 写请求
	input             sdram_wr_ack,	     //sdram 写响应
	output  [20:0] sdram_wr_addr1,	 //sdram 写地址
	output	   [15:0] sdram_din,		 //写入SDRAM中的数据 
                                         
    //SDRAM 控制器读端口                 
	output reg        sdram_rd_req,	     //sdram 读请求
	input             sdram_rd_ack,	     //sdram 读响应
	output  [20:0] sdram_rd_addr1,	     //sdram 读地址 
	input      [15:0] sdram_dout 		 //从SDRAM中读出的数据 
    
    );

//reg define
reg	       wr_ack_r1;                    //sdram写响应寄存器      
reg	       wr_ack_r2;                    
reg        rd_ack_r1;                    //sdram读响应寄存器      
reg	       rd_ack_r2;                    
reg	       wr_load_r1;                   //写端口复位寄存器      
reg        wr_load_r2;                   
reg	       rd_load_r1;                   //读端口复位寄存器      
reg        rd_load_r2;                   
reg        read_valid_r1;                //sdram读使能寄存器      
reg        read_valid_r2;   
reg  [20:0] sdram_wr_addr,sdram_rd_addr;             
reg           raddr_page;           //ddr3读地址切换信号
reg           waddr_page;           //ddr3写地址切换信号    
reg   wr_end,rd_end;                                 
//wire define                            
wire       write_done_flag;              //sdram_wr_ack 下降沿标志位      
wire       read_done_flag;               //sdram_rd_ack 下降沿标志位      
wire       wr_load_flag;                 //wr_load      上升沿标志位      
wire       rd_load_flag;                 //rd_load      上升沿标志位      
wire [9:0] wrf_use;                      //写端口FIFO中的数据量
wire [9:0] rdf_use;                      //读端口FIFO中的数据量

//*****************************************************
//**                    main code
//***************************************************** 

//检测下降沿
assign write_done_flag = wr_ack_r2   & ~wr_ack_r1;	
assign read_done_flag  = rd_ack_r2   & ~rd_ack_r1;

//检测上升沿
assign wr_load_flag    = ~wr_load_r2 & wr_load_r1;
assign rd_load_flag    = ~rd_load_r2 & rd_load_r1;

//寄存sdram写响应信号,用于捕获sdram_wr_ack下降沿
always @(posedge clk_ref or negedge rst_n) begin
	if(!rst_n) begin
		wr_ack_r1 <= 1'b0;
		wr_ack_r2 <= 1'b0;
    end
	else begin
		wr_ack_r1 <= sdram_wr_ack;
		wr_ack_r2 <= wr_ack_r1;		
    end
end	

//寄存sdram读响应信号,用于捕获sdram_rd_ack下降沿
always @(posedge clk_ref or negedge rst_n) begin
	if(!rst_n) begin
		rd_ack_r1 <= 1'b0;
		rd_ack_r2 <= 1'b0;
    end
	else begin
		rd_ack_r1 <= sdram_rd_ack;
		rd_ack_r2 <= rd_ack_r1;
    end
end	

//同步写端口复位信号，用于捕获wr_load上升沿
always @(posedge clk_ref or negedge rst_n) begin
	if(!rst_n) begin
		wr_load_r1 <= 1'b0;
		wr_load_r2 <= 1'b0;
    end
	else begin
		wr_load_r1 <= wr_load;
		wr_load_r2 <= wr_load_r1;
    end
end

//同步读端口复位信号，同时用于捕获rd_load上升沿
always @(posedge clk_ref or negedge rst_n) begin
	if(!rst_n) begin
		rd_load_r1 <= 1'b0;
		rd_load_r2 <= 1'b0;
    end
	else begin
		rd_load_r1 <= rd_load;
		rd_load_r2 <= rd_load_r1;
    end
end

//同步sdram读使能信号
always @(posedge clk_ref or negedge rst_n) begin
	if(!rst_n) begin
		read_valid_r1 <= 1'b0;
		read_valid_r2 <= 1'b0;
    end
	else begin
		read_valid_r1 <= sdram_read_valid;
		read_valid_r2 <= read_valid_r1;
    end
end

//sdram写地址产生模块
always @(posedge clk_ref or negedge rst_n) begin
	if(!rst_n)  begin
		sdram_wr_addr <= 24'd0;	
        wr_end <= 1'b0;
    end
    else if(wr_load_flag)  begin              //检测到写端口复位信号时，写地址复位
		sdram_wr_addr <= wr_min_addr;
        wr_end <=1'b0;	
        end
	else if(write_done_flag) begin		 //若突发写SDRAM结束，更改写地址
                                         //若未到达写SDRAM的结束地址，则写地址累加
		if(sdram_wr_addr < wr_max_addr - wr_length-1)begin
        	sdram_wr_addr <= sdram_wr_addr + wr_length;
            wr_end <=1'b0;
        end
        else  begin                        //若已到达写SDRAM的结束地址，则回到写起始地址
        	sdram_wr_addr <= wr_min_addr;
            wr_end <=1'b1;
        end
    end
    else wr_end <=1'b0;
end
assign sdram_wr_addr1 = ddr3_pingpang_en?{waddr_page,sdram_wr_addr[19:0]}:sdram_wr_addr;
//sdram读地址产生模块
always @(posedge clk_ref or negedge rst_n) begin
	if(!rst_n) begin
		sdram_rd_addr <= 21'd0;
        rd_end    <=1'b0;
    end
	else if(rd_load_flag)	begin			 //检测到读端口复位信号时，读地址复位
		sdram_rd_addr <= rd_min_addr;
        rd_end <=1'b0;
    end
	else if(read_done_flag) begin        //突发读SDRAM结束，更改读地址
                                         //若未到达读SDRAM的结束地址，则读地址累加
		if(sdram_rd_addr < rd_max_addr - rd_length-1) begin
        	sdram_rd_addr <= sdram_rd_addr + rd_length;
            rd_end <=1'b0;
        end
		else begin                           //若已到达读SDRAM的结束地址，则回到读起始地址
        	sdram_rd_addr <= rd_min_addr;
            rd_end <=1'b1;
         end
	end
    else rd_end <=1'b0;
end
    
assign sdram_rd_addr1 = ddr3_pingpang_en?{waddr_page,sdram_rd_addr[19:0]}:sdram_rd_addr;
//sdram 读写请求信号产生模块
always@(posedge clk_ref or negedge rst_n) begin
	if(!rst_n) begin
		sdram_wr_req <= 0;
		sdram_rd_req <= 0;
	end
	else if(sdram_init_done) begin       //SDRAM初始化完成后才能响应读写请求
                                         //优先执行写操作，防止写入SDRAM中的数据丢失
		if(wrf_use >= wr_length) begin   //若写端口FIFO中的数据量达到了写突发长度
			sdram_wr_req <= 1;		     //发出写sdarm请求
			sdram_rd_req <= 0;		     
		end
		else if((rdf_use < rd_length)    //若读端口FIFO中的数据量小于读突发长度，
                 && read_valid_r2) begin //同时sdram读使能信号为高
			sdram_wr_req <= 0;		     
			sdram_rd_req <= 1;		     //发出读sdarm请求
		end
		else begin
			sdram_wr_req <= 0;
			sdram_rd_req <= 0;
		end
	end
	else begin
		sdram_wr_req <= 0;
		sdram_rd_req <= 0;
	end
end
always@(posedge clk_ref or negedge rst_n) begin
	if(~rst_n)
        raddr_page <= 1'b0;
    else if(rd_end)
        raddr_page <= ~waddr_page;         
    else
        raddr_page <= raddr_page;     
end

always@(posedge clk_ref or negedge rst_n) begin
	if(~rst_n)
        waddr_page <= 1'b1;
    else if( wr_end)
        waddr_page <= ~waddr_page ;         
    else
        waddr_page <= waddr_page;          
end
//例化写端口FIFO
SOFTFIFO	wrfifo(
    //用户接口
	.clkw		(clk_write),		     //写时钟
	.we		(wrf_wrreq),		     //写请求
	.di		(wrf_din),			     //写数据
    
    //sdram接口
	.clkr		(clk_ref),			     //读时钟
	.re		(sdram_wr_ack),		     //读请求
	.dout			(sdram_din),		     //读数据

	.rdusedw	(wrf_use),			     //FIFO中的数据量
	.rst		(~rst_n | wr_load_flag)  //异步清零信号
    );	

//例化读端口FIFO
SOFTFIFO	rdfifo(
	//sdram接口
	.clkw		(clk_ref),       	     //写时钟
	.we		(sdram_rd_ack),  	     //写请求
	.di		(sdram_dout),  		     //写数据
    
	//用户接口
	.clkr		(clk_read),              //读时钟
	.re		(rdf_rdreq),     	     //读请求
	.dout			(rdf_dout),			     //读数据

	.wrusedw	(rdf_use),        	     //FIFO中的数据量
	.rst		(~rst_n | rd_load_flag)  //异步清零信号   
    );
    
endmodule 
