module bayer_to_rgb888(
    input pclk,
    input rst,
    input [15:0] bayer_data,
    input [11:0] pixel_x,
    input [11:0] pixel_y,
    
    output reg [23:0] rgb888
);
    wire pat_x,pat_y;
    assign pat_x = pixel_x % 2;
    assign pat_y = pixel_y % 2;
    always @(posedge pclk or negedge rst) begin
        if (!rst) begin
            rgb888 <= 24'd0;
        end
        else begin
            case({pat_x,pat_y})
                2'b10:rgb888 <={16'b0,{bayer_data[12:4]}};//蓝色
                2'b01:rgb888 <={{bayer_data[12:4]},16'b0};//红色
                default:rgb888 <={8'b0,{bayer_data[12:4]},8'b0};//绿色
            endcase
        end 
    end
endmodule