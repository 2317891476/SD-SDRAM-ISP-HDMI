module ISP_interconnect(
    input                               clk ,
    input                               rst_n,

    input wire [3:0] mode,

    input wire [24:0] bayer_data,

    input wire [23:0] dpc_out,
    input wire [23:0] awb_out,
    input wire [23:0] debayer_l_out,
    input wire [23:0] debayer_m_out,
    input wire [23:0] debayer_h_out,
    input wire [23:0] yuv_out,
    input wire [23:0] bayer_rgb888_out,

    input wire [23:0] bayer_rgb888_in,
    output wire[23:0] dpc_in,
    output wire[23:0] awb_in,
    output wire[23:0] debayer_l_in,
    output wire[23:0] debayer_m_in,
    output wire[23:0] debayer_h_in,
    output wire[23:0] yuv_in,

    output wire[23:0] hdmi_in
);
reg [23:0] dpc_in_reg;
reg [23:0] awb_in_reg;
reg [23:0] debayer_l_in_reg;
reg [23:0] debayer_m_in_reg;
reg [23:0] debayer_h_in_reg;
reg [23:0] yuv_in_reg;
reg [23:0] bayer_rgb888_in_reg;
reg [23:0] hdmi_in_reg;

always @(posedge clk or negedge rst_n) begin        
    if (!rst_n) begin
        dpc_in_reg <= 24'h0;
        awb_in_reg <= 24'h0;
        debayer_l_in_reg <= 24'h0;
        debayer_m_in_reg <= 24'h0;
        debayer_h_in_reg <= 24'h0;
        yuv_in_reg <= 24'h0;
        bayer_rgb888_in_reg <= 24'h0;
        hdmi_in_reg <= 24'h0;
    end          
    else begin                     
        case(mode)                                        
            4'd0: begin     //mode 0:不经过ISP   
                bayer_rgb888_in_reg <= bayer_data ;                          
                hdmi_in_reg<=bayer_rgb888_out;
            end
            4'd1: begin     //mode 1:双线性插值
                dpc_in_reg <=bayer_data;
                debayer_l_in_reg <= dpc_out;
                hdmi_in_reg<=debayer_l_out;
            end
            4'd2: begin     //mode 2:梯度插值
                dpc_in_reg <=bayer_data;
                debayer_m_in_reg <= dpc_out;
                hdmi_in_reg<=debayer_m_out;
            end
            4'd3: begin     //mode 3:自适应插值
                dpc_in_reg <=bayer_data;
                debayer_h_in_reg <= dpc_out;
                hdmi_in_reg<=debayer_m_out;
            end
            4'd4: begin     //mode 4:自动白平衡
                dpc_in_reg <=bayer_data;
                debayer_l_in_reg <= dpc_out;
                awb_in_reg <= debayer_l_out;
                hdmi_in_reg<=awb_out;
            end
            4'd5: begin     //mode 5:YUV颜色转换
                dpc_in_reg <=bayer_data;
                debayer_l_in_reg <= dpc_out;
                awb_in_reg <= debayer_l_out;
                yuv_in_reg <= awb_out;
                hdmi_in_reg<=yuv_out;
            end
            default:begin
                dpc_in_reg <= 24'h0;
                awb_in_reg <= 24'h0;
                debayer_l_in_reg <= 24'h0;
                debayer_m_in_reg <= 24'h0;
                debayer_h_in_reg <= 24'h0;
                yuv_in_reg <= 24'h0;
                bayer_rgb888_in_reg <= 24'h0;
                hdmi_in_reg <= 24'h0;
            end
        endcase
    end  
end       

assign dpc_in = dpc_in_reg ;  
assign awb_in = awb_in_reg ;
assign debayer_l_in = debayer_l_in_reg ;
assign debayer_m_in = debayer_m_in_reg ;
assign debayer_h_in = debayer_h_in_reg ;
assign yuv_in = yuv_in_reg ;     
assign bayer_rgb888_in = bayer_rgb888_in_reg ;    
assign hdmi_in = hdmi_in_reg;                

endmodule