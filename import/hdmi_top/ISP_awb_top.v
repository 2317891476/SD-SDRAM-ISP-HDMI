module ISP_awb_top #(
    parameter BITS = 8,
	parameter WIDTH = 1920,
	parameter HEIGHT = 1080,
	parameter BAYER = 2 //0:RGGB 1:GRBG 2:GBRG 3:BGGR
)
(
	input pclk,
	input rst_n,

	input in_href,
	input in_vsync,
	input [BITS-1:0] in_r,
    input [BITS-1:0] in_g,
    input [BITS-1:0] in_b,
    input in_de,

    output out_de,
	output out_href,
	output out_vsync,
	output [BITS-1:0] out_r,
	output [BITS-1:0] out_g,
	output [BITS-1:0] out_b
);
localparam OUT_BITS = 32;
wire statis_done;
wire [OUT_BITS-1:0] out_sum_r,out_sum_g,out_sum_b,out_cnt;


isp_stat_awb #(
    .BITS(BITS),
    .OUT_BITS(OUT_BITS)
) stat(
    .pclk(pclk),
    .rst_n(rst_n),

    .min(0),
    .max(8'b1111_1111),

    .in_href(in_href),
    .in_vsync(in_vsync),
    .in_r(in_r),
    .in_g(in_g),
    .in_b(in_b),

    .out_done(statis_done),
    .out_cnt(out_cnt),
    .out_sum_r(out_sum_r),
    .out_sum_g(out_sum_g),
    .out_sum_b(out_sum_b)
);

wire [7:0] r_gain,g_gain,b_gain;

alg_awb#(
	.BITS(BITS)
)
cal_awb
(
	.pclk(pclk),
    .rst_n(rst_n),

	.stat_done(statis_done),
	.pix_cnt(out_cnt),
	.sum_r(out_sum_r),
	.sum_g(out_sum_g),
	.sum_b(out_sum_b),

	.r_gain(r_gain),
	.g_gain(g_gain),
	.b_gain(b_gain)
);

isp_wb#(
	.BITS(8),
	.WIDTH (WIDTH),
	.HEIGHT (HEIGHT)
)
    wb
(
	.pclk(pclk),
    .rst_n(rst_n),

	.gain_r(r_gain),
	.gain_g(g_gain),
	.gain_b(b_gain),

	.in_href(in_href),
    .in_vsync(in_vsync),
	.in_r(in_r),
	.in_g(in_g),
	.in_b(in_b),
    .in_de(video_de),

    .out_de(out_de),
    .out_href(out_href),
    .out_vsync(out_vsync),
	.out_r(out_r),
	.out_g(out_g),
	.out_b(out_b)
);
endmodule