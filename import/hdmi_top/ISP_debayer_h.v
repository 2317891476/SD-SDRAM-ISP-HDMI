module isp_debayer_h
#(
	parameter BITS = 8,
	parameter WIDTH = 1280,
	parameter HEIGHT = 960,
	parameter BAYER = 0 //0:RGGB 1:GRBG 2:GBRG 3:BGGR
)
(
	input pclk,
	input rst_n,

	input in_href,
	input in_vsync,
	input [BITS-1:0] in_raw,
	input in_de,

	output out_de,
	output out_href,
	output out_vsync,
	output [BITS-1:0] out_r,
	output [BITS-1:0] out_g,
	output [BITS-1:0] out_b
);

	wire [BITS-1:0] shiftout;
	wire [BITS-1:0] tap5x, tap4x, tap3x, tap2x, tap1x, tap0x;
	shift_register #(BITS, WIDTH, 6) linebuffer(pclk, in_href, in_raw, shiftout, {tap5x, tap4x, tap3x, tap2x, tap1x, tap0x});
	
	reg [BITS-1:0] in_raw_r;
	reg [BITS-1:0] p11,p12,p13,p14,p15,p16,p17;
	reg [BITS-1:0] p21,p22,p23,p24,p25,p26,p27;
	reg [BITS-1:0] p31,p32,p33,p34,p35,p36,p37;
	reg [BITS-1:0] p41,p42,p43,p44,p45,p46,p47;
	reg [BITS-1:0] p51,p52,p53,p54,p55,p56,p57;
	reg [BITS-1:0] p61,p62,p63,p64,p65,p66,p67;
	reg [BITS-1:0] p71,p72,p73,p74,p75,p76,p77;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			in_raw_r <= 0;
			p11 <= 0; p12 <= 0; p13 <= 0; p14 <= 0; p15 <= 0; p16 <= 0; p17 <= 0;
			p21 <= 0; p22 <= 0; p23 <= 0; p24 <= 0; p25 <= 0; p26 <= 0; p27 <= 0;
			p31 <= 0; p32 <= 0; p33 <= 0; p34 <= 0; p35 <= 0; p36 <= 0; p37 <= 0;
			p41 <= 0; p42 <= 0; p43 <= 0; p44 <= 0; p45 <= 0; p46 <= 0; p47 <= 0;
			p51 <= 0; p52 <= 0; p53 <= 0; p54 <= 0; p55 <= 0; p56 <= 0; p57 <= 0;
			p61 <= 0; p62 <= 0; p63 <= 0; p64 <= 0; p65 <= 0; p66 <= 0; p67 <= 0;
			p71 <= 0; p72 <= 0; p73 <= 0; p74 <= 0; p75 <= 0; p76 <= 0; p77 <= 0;
		end
		else begin
			in_raw_r <= in_raw;
			p11 <= p12; p12 <= p13; p13 <= p14; p14 <= p15; p15 <= p16; p16 <= p17; p17 <= tap5x;
			p21 <= p22; p22 <= p23; p23 <= p24; p24 <= p25; p25 <= p26; p26 <= p27; p27 <= tap4x;
			p31 <= p32; p32 <= p33; p33 <= p34; p34 <= p35; p35 <= p36; p36 <= p37; p37 <= tap3x;
			p41 <= p42; p42 <= p43; p43 <= p44; p44 <= p45; p45 <= p46; p46 <= p47; p47 <= tap2x;
			p51 <= p52; p52 <= p53; p53 <= p54; p54 <= p55; p55 <= p56; p56 <= p57; p57 <= tap1x;
			p61 <= p62; p62 <= p63; p63 <= p64; p64 <= p65; p65 <= p66; p66 <= p67; p67 <= tap0x;
			p71 <= p72; p72 <= p73; p73 <= p74; p74 <= p75; p75 <= p76; p76 <= p77; p77 <= in_raw_r;
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
	wire odd_pix_sync_shift = ~odd_pix; //sync to shift_register
	
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
	wire odd_line_sync_shift = ~odd_line; //sync to shift_register

	wire [1:0] fmt = BAYER[1:0] ^ {odd_line_sync_shift, odd_pix_sync_shift}; //pixel format 0:[R]GGB 1:R[G]GB 2:RG[G]B 3:RGG[B]
	localparam FMT_R = 2'd0;  //[R]GGB
	localparam FMT_Gr = 2'd1; //R[G]GB
	localparam FMT_Gb = 2'd2; //RG[G]B
	localparam FMT_B = 2'd3;  //RGG[B]

	//calc G stage 1
	reg [1:0] t1_fmt;
	reg [(BITS+1)*5+BITS*2-1:0] t1_g, t1_g1, t1_g2, t1_g3, t1_g4;
	reg [BITS-1:0] t1_rb, t1_rb1, t1_rb2, t1_rb3, t1_rb4;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			t1_fmt <= 0;
			t1_g<=0; t1_g1<=0; t1_g2<=0; t1_g3<=0; t1_g4<=0;
			t1_rb<=0; t1_rb1<=0; t1_rb2<=0; t1_rb3<=0; t1_rb4<=0;
		end
		else begin
			t1_fmt <= fmt;
			case (fmt)
				FMT_R, FMT_B: begin //[R]GGB, RGG[B]
					t1_rb  <= p44;
					t1_rb1 <= p33;
					t1_rb2 <= p35;
					t1_rb3 <= p53;
					t1_rb4 <= p55;
					t1_g  <= interpolate_G_on_R_stage1(p44, p42, p46, p24, p64, p43, p45, p34, p54);
					t1_g1 <= interpolate_G_on_R_stage1(p33, p31, p35, p13, p53, p32, p34, p23, p43);
					t1_g2 <= interpolate_G_on_R_stage1(p35, p33, p37, p15, p55, p34, p36, p25, p45);
					t1_g3 <= interpolate_G_on_R_stage1(p53, p51, p55, p33, p73, p52, p54, p43, p63);
					t1_g4 <= interpolate_G_on_R_stage1(p55, p53, p57, p35, p75, p54, p56, p45, p65);
				end
				FMT_Gr, FMT_Gb: begin //R[G]GB RG[G]B
					t1_rb  <= 0;
					t1_rb1 <= p43;
					t1_rb2 <= p45;
					t1_rb3 <= p34;
					t1_rb4 <= p54;
					t1_g  <= p44;
					t1_g1 <= interpolate_G_on_R_stage1(p43, p41, p45, p23, p63, p42, p44, p33, p53);
					t1_g2 <= interpolate_G_on_R_stage1(p45, p43, p47, p25, p65, p44, p46, p35, p55);
					t1_g3 <= interpolate_G_on_R_stage1(p34, p32, p36, p14, p54, p33, p35, p24, p44);
					t1_g4 <= interpolate_G_on_R_stage1(p54, p52, p56, p34, p74, p53, p55, p44, p64);
				end
				default: begin
					t1_g<=0; t1_g1<=0; t1_g2<=0; t1_g3<=0; t1_g4<=0;
					t1_rb<=0; t1_rb1<=0; t1_rb2<=0; t1_rb3<=0; t1_rb4<=0;
				end
			endcase
		end
	end

	//calc G stage 2
	reg [1:0] t2_fmt;
	reg [(BITS+2)*5-1:0] t2_g, t2_g1, t2_g2, t2_g3, t2_g4;
	reg [BITS-1:0] t2_rb, t2_rb1, t2_rb2, t2_rb3, t2_rb4;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			t2_fmt <= 0;
			t2_g<=0; t2_g1<=0; t2_g2<=0; t2_g3<=0; t2_g4<=0;
			t2_rb<=0; t2_rb1<=0; t2_rb2<=0; t2_rb3<=0; t2_rb4<=0;
		end
		else begin
			t2_fmt <= t1_fmt;
			t2_rb  <= t1_rb;
			t2_rb1 <= t1_rb1;
			t2_rb2 <= t1_rb2;
			t2_rb3 <= t1_rb3;
			t2_rb4 <= t1_rb4;
			t2_g1 <= interpolate_G_on_R_stage2(t1_g1);
			t2_g2 <= interpolate_G_on_R_stage2(t1_g2);
			t2_g3 <= interpolate_G_on_R_stage2(t1_g3);
			t2_g4 <= interpolate_G_on_R_stage2(t1_g4);
			case (t1_fmt)
				FMT_R, FMT_B: t2_g <= interpolate_G_on_R_stage2(t1_g);
				default:      t2_g <= t1_g[BITS-1:0];
			endcase
		end
	end

	//calc G stage 3
	reg [1:0] t3_fmt;
	reg [BITS-1:0] t3_g, t3_g1, t3_g2, t3_g3, t3_g4;
	reg [BITS-1:0] t3_rb, t3_rb1, t3_rb2, t3_rb3, t3_rb4;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			t3_fmt <= 0;
			t3_g<=0; t3_g1<=0; t3_g2<=0; t3_g3<=0; t3_g4<=0;
			t3_rb<=0; t3_rb1<=0; t3_rb2<=0; t3_rb3<=0; t3_rb4<=0;
		end
		else begin
			t3_fmt <= t2_fmt;
			t3_rb  <= t2_rb;
			t3_rb1 <= t2_rb1;
			t3_rb2 <= t2_rb2;
			t3_rb3 <= t2_rb3;
			t3_rb4 <= t2_rb4;
			t3_g1 <= interpolate_G_on_R_stage3(t2_g1);
			t3_g2 <= interpolate_G_on_R_stage3(t2_g2);
			t3_g3 <= interpolate_G_on_R_stage3(t2_g3);
			t3_g4 <= interpolate_G_on_R_stage3(t2_g4);
			case (t2_fmt)
				FMT_R, FMT_B: t3_g <= interpolate_G_on_R_stage3(t2_g);
				default:      t3_g <= t2_g[BITS-1:0];
			endcase
		end
	end

	//calc R/B stage 1
	reg [1:0] t4_fmt;
	reg [BITS-1:0] t4_g;
	reg [(BITS+1)*4+BITS*3-1:0] t4_r, t4_b;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			t4_fmt <= 0;
			t4_g <= 0;
			t4_r <= 0;
			t4_b <= 0;
		end
		else begin
			t4_fmt <= t3_fmt;
			t4_g <= t3_g;
			case (t3_fmt)
				FMT_R: begin
					t4_r <= t3_rb;
					t4_b <= interpolate_R_on_B_stage1(t3_g, t3_g1, t3_g2, t3_g3, t3_g4, t3_rb1, t3_rb2, t3_rb3, t3_rb4);
				end
				FMT_Gr: begin
					t4_r <= interpolate_R_on_G_stage1(t3_g, t3_g1, t3_g2, t3_rb1, t3_rb2);
					t4_b <= interpolate_R_on_G_stage1(t3_g, t3_g3, t3_g4, t3_rb3, t3_rb4);
				end
				FMT_Gb: begin
					t4_r <= interpolate_R_on_G_stage1(t3_g, t3_g3, t3_g4, t3_rb3, t3_rb4);
					t4_b <= interpolate_R_on_G_stage1(t3_g, t3_g1, t3_g2, t3_rb1, t3_rb2);
				end
				FMT_B: begin
					t4_r <= interpolate_R_on_B_stage1(t3_g, t3_g1, t3_g2, t3_g3, t3_g4, t3_rb1, t3_rb2, t3_rb3, t3_rb4);
					t4_b <= t3_rb;
				end
				default: begin
					t4_r <= 0;
					t4_b <= 0;
				end
			endcase
		end
	end

	//calc R/B stage 2
	reg [1:0] t5_fmt;
	reg [BITS-1:0] t5_g;
	reg [(BITS+2)*5-1:0] t5_r, t5_b;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			t5_fmt <= 0;
			t5_g <= 0;
			t5_r <= 0;
			t5_b <= 0;
		end
		else begin
			t5_fmt <= t4_fmt;
			t5_g <= t4_g;
			case (t4_fmt)
				FMT_R: begin
					t5_r <= t4_r[BITS-1:0];
					t5_b <= interpolate_R_on_B_stage2(t4_b);
				end
				FMT_Gr: begin
					t5_r <= interpolate_R_on_G_stage2(t4_r[BITS*2:0]);
					t5_b <= interpolate_R_on_G_stage2(t4_b[BITS*2:0]);
				end
				FMT_Gb: begin
					t5_r <= interpolate_R_on_G_stage2(t4_r[BITS*2:0]);
					t5_b <= interpolate_R_on_G_stage2(t4_b[BITS*2:0]);
				end
				FMT_B: begin
					t5_r <= interpolate_R_on_B_stage2(t4_r);
					t5_b <= t4_b[BITS-1:0];
				end
				default: begin
					t5_r <= 0;
					t5_b <= 0;
				end
			endcase
		end
	end

	//calc R/B stage 3
	reg [BITS-1:0] r_now, g_now, b_now;
	always @ (posedge pclk or negedge rst_n) begin
		if (!rst_n) begin
			r_now <= 0;
			g_now <= 0;
			b_now <= 0;
		end
		else begin
			g_now <= t5_g;
			case (t5_fmt)
				FMT_R: begin
					r_now <= t5_r[BITS-1:0];
					b_now <= interpolate_R_on_B_stage3(t5_b);
				end
				FMT_Gr: begin
					r_now <= t5_r[BITS-1:0];
					b_now <= t5_b[BITS-1:0];
				end
				FMT_Gb: begin
					r_now <= t5_r[BITS-1:0];
					b_now <= t5_b[BITS-1:0];
				end
				FMT_B: begin
					r_now <= interpolate_R_on_B_stage3(t5_r);
					b_now <= t5_b[BITS-1:0];
				end
				default: begin
					r_now <= 0;
					b_now <= 0;
				end
			endcase
		end
	end

	localparam DLY_CLK = 3;
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
	assign out_r = out_href ? r_now[BITS-1:BITS-8] : {BITS{1'b0}};
	assign out_g = out_href ? g_now[BITS-1:BITS-8] : {BITS{1'b0}};
	assign out_b = out_href ? b_now[BITS-1:BITS-8] : {BITS{1'b0}};

	function [(BITS+1)*5+BITS*2-1:0] interpolate_G_on_R_stage1;
		input [BITS-1:0] R, R_left, R_right, R_up, R_down, G_left, G_right, G_up, G_down;
		reg [BITS:0] Rx2, R_lr_sum, R_ud_sum, G_lr_sum, G_ud_sum;
		reg [BITS-1:0] G_lr_diff, G_ud_diff;
		begin
			Rx2 = {R,1'b0};
			R_lr_sum = R_left + R_right;
			R_ud_sum = R_up + R_down;
			G_lr_sum = G_left + G_right;
			G_ud_sum = G_up + G_down;
			G_lr_diff = G_left > G_right ? G_left - G_right : G_right - G_left;
			G_ud_diff = G_up > G_down ? G_up - G_down : G_down - G_up;
			interpolate_G_on_R_stage1 = {Rx2, R_lr_sum, R_ud_sum, G_lr_sum, G_ud_sum, G_lr_diff, G_ud_diff};
		end
	endfunction

	function [(BITS+2)*5-1:0] interpolate_G_on_R_stage2;
		input [(BITS+1)*5+BITS*2-1:0] stage1_in;
		reg [BITS:0]   Rx2, R_lr_sum, R_ud_sum, G_lr_sum, G_ud_sum;
		reg [BITS-1:0] G_lr_diff, G_ud_diff;
		reg [BITS+1:0] Rx2_lr_diff_G_lr_diff, Rx2_ud_diff_G_ud_diff;
		reg signed [BITS:0]   s_G_lr_avg, s_G_ud_avg, s_G_lrud_avg;
		reg signed [BITS+1:0] s_Rx2, s_R_lr_sum, s_R_ud_sum;
		reg signed [BITS+2:0] s_Rx4, s_R_lrud_sum;
		reg signed [BITS+1:0] s_G_lr_out, s_G_ud_out, s_G_lrud_out;
		begin
			{Rx2, R_lr_sum, R_ud_sum, G_lr_sum, G_ud_sum, G_lr_diff, G_ud_diff} = stage1_in;
			Rx2_lr_diff_G_lr_diff = (Rx2 > R_lr_sum ? Rx2 - R_lr_sum : R_lr_sum - Rx2) + G_lr_diff;
			Rx2_ud_diff_G_ud_diff = (Rx2 > R_ud_sum ? Rx2 - R_ud_sum : R_ud_sum - Rx2) + G_ud_diff;
			s_G_lr_avg = G_lr_sum[BITS:1];
			s_G_ud_avg = G_ud_sum[BITS:1];
			s_G_lrud_avg = ({1'b0,G_lr_sum} + {1'b0,G_ud_sum}) >> 2;
			s_Rx2 = Rx2;
			s_R_lr_sum = R_lr_sum;
			s_R_ud_sum = R_ud_sum;
			s_Rx4 = {Rx2, 1'b0};
			s_R_lrud_sum = R_lr_sum + R_ud_sum;
			s_G_lr_out = s_G_lr_avg + ((s_Rx2 - s_R_lr_sum) >>> 2);
			s_G_ud_out = s_G_ud_avg + ((s_Rx2 - s_R_ud_sum) >>> 2);
			s_G_lrud_out = s_G_lrud_avg + ((s_Rx4 - s_R_lrud_sum) >>> 3);
			interpolate_G_on_R_stage2 = {Rx2_lr_diff_G_lr_diff, Rx2_ud_diff_G_ud_diff, s_G_lr_out, s_G_ud_out, s_G_lrud_out};
		end
	endfunction

	function [BITS-1:0] interpolate_G_on_R_stage3;
		input [(BITS+2)*5-1:0] stage2_in;
		reg [BITS+1:0] Rx2_lr_diff_G_lr_diff, Rx2_ud_diff_G_ud_diff;
		reg signed [BITS+1:0] s_G_lr_out, s_G_ud_out, s_G_lrud_out;
		reg signed [BITS+1:0] out;
		begin
			{Rx2_lr_diff_G_lr_diff, Rx2_ud_diff_G_ud_diff, s_G_lr_out, s_G_ud_out, s_G_lrud_out} = stage2_in;
			out = Rx2_lr_diff_G_lr_diff < Rx2_ud_diff_G_ud_diff ? s_G_lr_out : (Rx2_lr_diff_G_lr_diff > Rx2_ud_diff_G_ud_diff ? s_G_ud_out : s_G_lrud_out);
			interpolate_G_on_R_stage3 = out[BITS+1] ? 0 : (out[BITS] ? {BITS{1'b1}} : out[BITS-1:0]);
		end
	endfunction

	function [BITS*2:0] interpolate_R_on_G_stage1;
		input [BITS-1:0] G, Gr1, Gr2, R1, R2;
		reg [BITS:0] R_sum, Gr_sum;
		reg [BITS:0] G_add_R_avg;
		begin
			R_sum = {1'd0,R1} + {1'd0,R2};
			Gr_sum = {1'd0,Gr1} + {1'd0,Gr2};
			G_add_R_avg = G + R_sum[BITS:1];
			interpolate_R_on_G_stage1 = {G_add_R_avg, Gr_sum[BITS:1]};
		end
	endfunction

	function [BITS-1:0] interpolate_R_on_G_stage2;
		input [BITS*2:0] stage1_in;
		reg [BITS:0] G_add_R_avg;
		reg [BITS-1:0] Gr_avg;
		reg [BITS:0] R_out;
		begin
			Gr_avg = stage1_in[0+:BITS];
			G_add_R_avg = stage1_in[BITS+:BITS+1];
			R_out = G_add_R_avg > Gr_avg ? G_add_R_avg - Gr_avg : 0;
			interpolate_R_on_G_stage2 = R_out[BITS] ? {BITS{1'b1}} : R_out[BITS-1:0];
		end
	endfunction

	function [(BITS+1)*4+BITS*3-1:0] interpolate_R_on_B_stage1;
		input [BITS-1:0] G, Gr1, Gr2, Gr3, Gr4, R1, R2, R3, R4;
		reg [BITS:0] G_14_sum, G_23_sum, R_14_sum, R_23_sum;
		reg [BITS-1:0] R_14_diff, R_23_diff;
		begin
			G_14_sum = Gr1 + Gr4;
			G_23_sum = Gr2 + Gr3;
			R_14_sum = R1 + R4;
			R_23_sum = R2 + R3;
			R_14_diff = R1 > R4 ? R1 - R4 : R4 - R1;
			R_23_diff = R2 > R3 ? R2 - R3 : R3 - R2;
			interpolate_R_on_B_stage1 = {G_14_sum, G_23_sum, R_14_sum, R_23_sum, R_14_diff, R_23_diff, G};
		end
	endfunction

	function [(BITS+2)*5-1:0] interpolate_R_on_B_stage2;
		input [(BITS+1)*4+BITS*3-1:0] stage1_in;
		reg [BITS:0] G_14_sum, G_23_sum, R_14_sum, R_23_sum;
		reg [BITS-1:0] R_14_diff, R_23_diff, G;
		reg [BITS+1:0] Gx2_14_diff_R_14_diff, Gx2_23_diff_R_23_diff;
		reg signed [BITS:0]   s_R_14_avg, s_R_23_avg, s_R_1234_avg, s_G_14_avg, s_G_23_avg, s_G_1234_avg, s_G;
		reg signed [BITS+1:0] s_R_14_out, s_R_23_out, s_R_1234_out;
		begin
			{G_14_sum, G_23_sum, R_14_sum, R_23_sum, R_14_diff, R_23_diff, G} = stage1_in;
			Gx2_14_diff_R_14_diff = ({G,1'b0} > G_14_sum ? {G,1'b0} - G_14_sum : G_14_sum - {G,1'b0}) + R_14_diff;
			Gx2_23_diff_R_23_diff = ({G,1'b0} > G_23_sum ? {G,1'b0} - G_23_sum : G_23_sum - {G,1'b0}) + R_23_diff;
			s_R_14_avg = R_14_sum[BITS:1];
			s_R_23_avg = R_23_sum[BITS:1];
			s_R_1234_avg = ({1'b0,R_14_sum} + {1'b0,R_23_sum}) >> 2;
			s_G_14_avg = G_14_sum[BITS:1];
			s_G_23_avg = G_23_sum[BITS:1];
			s_G_1234_avg = ({1'b0,G_14_sum} + {1'b0,G_23_sum}) >> 2;
			s_G = G;
			s_R_14_out = s_G + s_R_14_avg - s_G_14_avg;
			s_R_23_out = s_G + s_R_23_avg - s_G_23_avg;
			s_R_1234_out = s_G + s_R_1234_avg - s_G_1234_avg;
			interpolate_R_on_B_stage2 = {Gx2_14_diff_R_14_diff, Gx2_23_diff_R_23_diff, s_R_14_out, s_R_23_out, s_R_1234_out};
		end
	endfunction

	function [BITS-1:0] interpolate_R_on_B_stage3;
		input [(BITS+2)*5-1:0] stage2_in;
		reg [BITS+1:0] Gx2_14_diff_R_14_diff, Gx2_23_diff_R_23_diff;
		reg signed [BITS+1:0] s_R_14_out, s_R_23_out, s_R_1234_out;
		reg signed [BITS+1:0] out;
		begin
			{Gx2_14_diff_R_14_diff, Gx2_23_diff_R_23_diff, s_R_14_out, s_R_23_out, s_R_1234_out} = stage2_in;
			out = Gx2_14_diff_R_14_diff < Gx2_23_diff_R_23_diff ? s_R_14_out : (Gx2_14_diff_R_14_diff > Gx2_23_diff_R_23_diff ? s_R_23_out : s_R_1234_out);
			interpolate_R_on_B_stage3 = out[BITS+1] ? 0 : (out[BITS] ? {BITS{1'b1}} : out[BITS-1:0]);
		end
	endfunction
endmodule
