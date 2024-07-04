module ISP_debayer #(
	parameter BITS = 16,
	parameter WIDTH = 1920,
	parameter HEIGHT = 960
    //parameter BAYER = 0 //0:RGGB 1:GRBG 2:GBRG 3:BGGR
)(
    input pclk,
    input rst_n,
    input [15:0] in_raw,

    input in_href,
    input in_vsync,
    input in_de,

    output out_de,
    output out_href,
    output out_vsync,
    output [15:0] rgb565
);  

    wire [BITS-1:0] shiftout;
    wire [BITS-1:0] tap1x, tap0x;
    shift_register #(BITS, WIDTH, 2) linebuffer(pclk, in_href, in_raw, shiftout, {tap1x, tap0x});

    reg [BITS-1:0] in_raw_r;
    reg [BITS-1:0] p11,p12,p13;
    reg [BITS-1:0] p21,p22,p23;
    reg [BITS-1:0] p31,p32,p33;
    always @ (posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            in_raw_r <= 0;
            p11 <= 0; p12 <= 0; p13 <= 0;
            p21 <= 0; p22 <= 0; p23 <= 0; 
            p31 <= 0; p32 <= 0; p33 <= 0;
        end
        else begin
            in_raw_r <= in_raw;
            p11 <= p12; p12 <= p13; p13 <= tap1x; 
            p21 <= p22; p22 <= p23; p23 <= tap0x; 
            p31 <= p32; p32 <= p33; p33 <= in_raw_r; 
        end
    end
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

    //wire [1:0] p33_fmt = BAYER[1:0] ^ {odd_line_sync_shift, odd_pix_sync_shift}; //pixel format 0:[R]GGB 1:R[G]GB 2:RG[G]B 3:RGG[B]
    reg [4:0] red_p;
    reg [5:0] gr_p;
    reg [4:0] bl_p;

    always @ (posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            red_p <= 0; 
            gr_p <= 0; 
            bl_p <= 0; 
        end
        else begin
            case ({odd_line_sync_shift,odd_pix_sync_shift})
                2'b10:begin//R
                    red_p <= p22[15:11]; 
                    gr_p <= (p12[15:10] + p21[15:10] + p23[15:10] + p32[15:10])>>2; 
                    bl_p <= (p11[15:11] + p13[15:11] + p31[15:11] + p33[15:11])>>2; 
                end
                2'b01: begin //B
                    bl_p <= p22[15:11]; 
                    gr_p <= (p12[15:10] + p21[15:10] + p23[15:10] + p32[15:10])>>2; 
                    red_p <= (p11[15:11] + p13[15:11] + p31[15:11] + p33[15:11])>>2; 
                end
                2'b00: begin//Gb
                    red_p <= (p12[15:11] + p32[15:11])>>1; 
                    gr_p <= p22[15:10]; 
                    bl_p <= (p21[15:11] + p23[15:11])>>1; 
                end
                2'b11: begin//Gr
                    red_p <= (p21[15:11] + p23[15:11])>>1;
                    gr_p <= p22[15:10]; 
                    bl_p <=  (p12[15:11] + p32[15:11])>>1; 
                end
            endcase
        end
    end
    assign rgb565 = {red_p,gr_p,bl_p};

    localparam DLY_CLK = 6;
    reg [DLY_CLK-1:0] href_dly;
    reg [DLY_CLK-1:0] vsync_dly;
    reg [DLY_CLK-1:0] de_dly;
    always @ (posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            href_dly <= 0;
            vsync_dly <= 0;
            de_dly <=0;
        end
        else begin
            href_dly <= {href_dly[DLY_CLK-2:0], in_href};
            vsync_dly <= {vsync_dly[DLY_CLK-2:0], in_vsync};
            de_dly <= {de_dly[DLY_CLK-2:0],in_de};
        end
    end

    assign out_href = href_dly[DLY_CLK-1];
    assign out_vsync = vsync_dly[DLY_CLK-1];
    assign out_de = de_dly[DLY_CLK-1];
    
endmodule