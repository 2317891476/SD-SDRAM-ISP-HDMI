/*************************************************************************
    > File Name: isp_stat_awb.v
    > Author: bxq
    > Mail: 544177215@qq.com
    > Created Time: Thu 21 Jan 2021 21:50:04 GMT
 ************************************************************************/
`timescale 1 ns / 1 ps

/*
 * ISP - Statistics for Auto White Balance
 */

module isp_stat_awb
#(
	parameter BITS = 8,
	parameter WIDTH = 1280,
	parameter HEIGHT = 960,
	parameter OUT_BITS = 32,
	parameter HIST_BITS = BITS //直方图横坐标位数(默认像素位深)
)
(
	input pclk,
	input rst_n,

	input [BITS-1:0] min,
	input [BITS-1:0] max,

	input in_href,
	input in_vsync,
	input [BITS-1:0] in_r,
	input [BITS-1:0] in_g,
	input [BITS-1:0] in_b,

	output out_done,
	output [OUT_BITS-1:0] out_cnt,
	output [OUT_BITS-1:0] out_sum_r,
	output [OUT_BITS-1:0] out_sum_g,
	output [OUT_BITS-1:0] out_sum_b

);

	reg in_href_reg, in_vsync_reg;
	reg [BITS-1:0] in_r_reg, in_g_reg, in_b_reg;
	reg r_vaild, g_vaild, b_vaild;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			in_href_reg <= 0;
			in_vsync_reg <= 0;
			in_r_reg <= 0;
			in_g_reg <= 0;
			in_b_reg <= 0;
			r_vaild <= 0;
			g_vaild <= 0;
			b_vaild <= 0;
		end
		else begin
			in_href_reg <= in_href;
			in_vsync_reg <= in_vsync;
			in_r_reg <= in_r;
			in_g_reg <= in_g;
			in_b_reg <= in_b;
			r_vaild <= in_r >= min && in_r <= max;
			g_vaild <= in_g >= min && in_g <= max;
			b_vaild <= in_b >= min && in_b <= max;
		end
	end

	reg prev_vsync;
	wire frame_start = prev_vsync & (~in_vsync_reg);
	wire frame_end = (~prev_vsync) & in_vsync_reg;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			prev_vsync <= 0;
		end
		else begin
			prev_vsync <= in_vsync_reg;
		end
	end

	reg [OUT_BITS-1:0] tmp_cnt;
	reg [OUT_BITS-1:0] tmp_sum_r, tmp_sum_g, tmp_sum_b;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			tmp_cnt <= 0;
			tmp_sum_r <= 0;
			tmp_sum_g <= 0;
			tmp_sum_b <= 0;
		end
		else if (frame_start) begin
			tmp_cnt <= 0;
			tmp_sum_r <= 0;
			tmp_sum_g <= 0;
			tmp_sum_b <= 0;
		end
		else if (in_href_reg && r_vaild && g_vaild && b_vaild) begin
			tmp_cnt <= tmp_cnt + 1'b1;
			tmp_sum_r <= tmp_sum_r + in_r_reg;
			tmp_sum_g <= tmp_sum_g + in_g_reg;
			tmp_sum_b <= tmp_sum_b + in_b_reg;
		end
		else begin
			tmp_cnt <= tmp_cnt;
			tmp_sum_r <= tmp_sum_r;
			tmp_sum_g <= tmp_sum_g;
			tmp_sum_b <= tmp_sum_b;
		end
	end

	reg done;
	reg [OUT_BITS-1:0] pix_cnt;
	reg [OUT_BITS-1:0] pix_sum_r;
	reg [OUT_BITS-1:0] pix_sum_g;
	reg [OUT_BITS-1:0] pix_sum_b;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			done <= 0;
			pix_cnt <= 0;
			pix_sum_r <= 0;
			pix_sum_g <= 0;
			pix_sum_b <= 0;
		end
		else if (frame_end) begin
			done <= 1;
			pix_cnt <= tmp_cnt;
			pix_sum_r <= tmp_sum_r;
			pix_sum_g <= tmp_sum_g;
			pix_sum_b <= tmp_sum_b;
		end
		else begin
			done <= 0;
			pix_cnt <= pix_cnt;
			pix_sum_r <= pix_sum_r;
			pix_sum_g <= pix_sum_g;
			pix_sum_b <= pix_sum_b;
		end
	end

	assign out_done = done;
	assign out_cnt = pix_cnt;
	assign out_sum_r = pix_sum_r;
	assign out_sum_g = pix_sum_g;
	assign out_sum_b = pix_sum_b;

endmodule
