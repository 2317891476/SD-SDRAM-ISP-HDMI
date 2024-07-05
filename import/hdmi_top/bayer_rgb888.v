module bayer_to_rgb888(
    input pclk,
    input rst_n,
    input in_href,
    input in_vsync,
    input [15:0] bayer_data,
    
    output reg [23:0] rgb888
);

    reg odd_pix;
    always @ (posedge pclk or negedge rst_n) begin
        if (!rst_n)
            odd_pix <= 0;
        else if (!in_href)
            odd_pix <= 0;
        else
            odd_pix <= ~odd_pix;
    end
    wire odd_pix_sync_shift = odd_pix;

    reg prev_href;
    always @ (posedge pclk or negedge rst_n) begin
        if (!rst_n) 
            prev_href <= 0;
        else
            prev_href <= in_href;
    end	

    reg odd_line;
    always @ (posedge pclk or negedge rst_n) begin
        if (!rst_n) 
            odd_line <= 0;
        else if (in_vsync)
            odd_line <= 0;
        else if (prev_href & (~in_href))
            odd_line <= ~odd_line;
        else
            odd_line <= odd_line;
    end
    wire odd_line_sync_shift = odd_line;

    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            rgb888 <= 24'd0;
        end
        else begin
            case({odd_pix_sync_shift,odd_line_sync_shift})
                2'b10:rgb888 <={16'b0,{bayer_data[15:7]}};//蓝色
                2'b01:rgb888 <={{bayer_data[15:7]},16'b0};//红色
                default:rgb888 <={8'b0,{bayer_data[15:7]},8'b0};//绿色
            endcase
        end 
    end
endmodule