module debounce(o_sw,i_sw,clk);
output	o_sw;
input	i_sw;
input	clk;

reg dly1_sw;

always @(posedge clk) begin
	dly1_sw <= i_sw;
end
reg dly2_sw;
always @(posedge clk)begin
	dly2_sw <= dly1_sw;
end
assign o_sw = dly1_sw | ~dly2_sw;
endmodule

module nco(o_nco,i_num,clk,rst_n);
output		o_nco;
input	[31:0]	i_num;
input		clk;
input		rst_n;

reg		o_nco;
reg	[31:0]	cnt;
always @(posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			o_nco <= 1'b0;
			cnt <= 32'd0;
		end else begin
			if( cnt >= (i_num/2)-1) begin
				o_nco <= ~ o_nco;
				   cnt<= 32'd0;
			end else begin
				cnt<=cnt+1'd1;
			end
		end
end

endmodule

module double(o_left,o_right,i_fig);
output	[3:0]	o_left;
output	[3:0]	o_right;
input	[5:0]	i_fig;

assign		o_left  = i_fig /10;
assign		o_right = i_fig %10;

endmodule

module mode_dp(o_six_dp,i_mode);
output	[5:0] o_six_dp;
input	[1:0] i_mode;

parameter	MODE_CLOCK = 2'b00;
parameter	MODE_SETUP = 2'b01;
parameter	MODE_ALARM = 2'b10;
parameter	MODE_TIMER = 2'b11;

reg	[5:0] o_six_dp;
always@(i_mode)begin
	case(i_mode)
		MODE_CLOCK:o_six_dp <= 6'b000_000;
		MODE_SETUP:o_six_dp <= 6'b000_011;
		MODE_ALARM:o_six_dp <= 6'b001_100;
		MODE_TIMER:o_six_dp <= 6'b110_000;
	endcase
end

endmodule

module ir_rx(o_data,o_cmplt,i_ir_rxb,clk,rst_n); 
output	[31:0]	o_data;
output		o_cmplt;
input		i_ir_rxb;
input		clk;
input		rst_n;

parameter	IDLE     = 2'b00;
parameter	LEADCODE = 2'b01;
parameter	DATACODE = 2'b10;
parameter	COMPLETE = 2'b11;

wire		clk_1M;
nco		u_nco(.o_nco(clk_1M),.i_num(32'd50),.clk(clk),.rst_n(rst_n));
wire		ir_rx;
assign		ir_rx = ~i_ir_rxb;

reg	[1:0]	seq_rx;
always@(posedge clk_1M or negedge rst_n)begin
	if(rst_n == 1'b0)begin
		seq_rx <= 2'b00;
	end else begin
		seq_rx	<= {seq_rx[0],ir_rx};
	end
end

reg	[15:0]	cnt_h;
reg	[15:0]	cnt_l;
always@(posedge clk_1M or negedge rst_n)begin
	if(rst_n ==1'b0)begin
		cnt_h	<= 16'd0;
		cnt_l	<= 16'd0;
	end else begin
		case(seq_rx)
			2'b00:	cnt_l <=cnt_l +1'b1;
			2'b01:begin
				cnt_l<=16'd0;
				cnt_h<=16'd0;
			      end
			2'b11:cnt_h <=cnt_h+1'b1;
		endcase
	end
end

reg	[1:0]	state;
reg	[5:0]	cnt32;
reg		o_cmplt;
always@(posedge clk_1M or negedge rst_n)begin
	if(rst_n ==1'b0)begin
		state <= IDLE;
		cnt32 <= 6'd0;
		o_cmplt<=1'b0;
	end else begin
		case(state)
			IDLE:begin
				state <=LEADCODE;
				cnt32 <=6'd0;
				o_cmplt<=1'b0;
				
			     end
			LEADCODE:begin
				    if(cnt_h>=16'd8500 && cnt_l>=16'd4000 )begin
				   		state <= DATACODE; 
				    end else begin
						state <= LEADCODE;
				    end
				 end
			DATACODE:begin
				 if(seq_rx == 2'b01)begin
					cnt32 <= cnt32 + 1;
				 end else begin
					cnt32<=cnt32;
				 end
				 if(cnt32 >= 6'd32 && cnt_l >= 16'd1000)begin
					state <= COMPLETE;
					o_cmplt<=1'b1;
				 end else begin
					state <= DATACODE;
				 end
				 end
			COMPLETE:	state <=IDLE;
		endcase
	end
end

reg	[31:0]	data;
reg	[31:0]	o_data;
always@(posedge clk_1M or negedge rst_n) begin
		if(rst_n ==1'b0) begin
			data <=32'd0;
		end else begin
			case(state)
				IDLE:o_data <=32'd0;// new!!!
				DATACODE:begin
					 if(cnt_l >= 16'd1000)begin
						data[32-cnt32] <= 1'b1;
					 end else begin
						data[32-cnt32] <= 1'b0;
					 end
					 end
				COMPLETE:o_data <= data;
			endcase
		end
end

endmodule

module ir_sw(o_sw0,o_sw1,o_sw2,o_sw3,i_data,i_cmplt,clk,rst_n);
output	o_sw0;
output	o_sw1;
output	o_sw2;
output	o_sw3;
input	[31:0]	i_data;
input	i_cmplt;
input	clk;
input	rst_n;

reg	o_sw0;
reg	o_sw1;
reg	o_sw2;
reg	o_sw3;

always@(posedge clk or negedge rst_n)begin
	if(rst_n==1'b0)begin
		o_sw0<= 1'b1;
		o_sw1<= 1'b1;
		o_sw2<= 1'b1;
		o_sw3<= 1'b1;
	end else begin
		if(i_cmplt==1'b1)begin
			case(i_data)
				32'hFD708F:o_sw0<=1'b0;
				32'hFD08F7:o_sw1<=1'b0;
				32'hFD8877:o_sw2<=1'b0;
				32'hFD48B7:o_sw3<=1'b0;
			endcase	
		end else begin
				o_sw0<= 1'b1;
				o_sw1<= 1'b1;
				o_sw2<= 1'b1;
				o_sw3<= 1'b1;
		end
	end
end
endmodule

module sw_sw(o_sw0,o_sw1,o_sw2,o_sw3,i_sw0,i_sw1,i_sw2,i_sw3,clk,rst_n);
output	o_sw0 ;
output	o_sw1 ;
output	o_sw2 ;
output	o_sw3 ;
input	i_sw0 ;
input	i_sw1 ;
input	i_sw2 ;
input	i_sw3 ;
input	clk ;
input	rst_n ;	

wire	sclk;
nco	nco_u1(.o_nco(sclk),.i_num(32'd500000),.clk(clk),.rst_n(rst_n));
debounce	de_u0(.o_sw(o_sw0),.i_sw(i_sw0),.clk(sclk));
debounce	de_u1(.o_sw(o_sw1),.i_sw(i_sw1),.clk(sclk));
debounce	de_u2(.o_sw(o_sw2),.i_sw(i_sw2),.clk(sclk));
debounce	de_u3(.o_sw(o_sw3),.i_sw(i_sw3),.clk(sclk));

endmodule

module sw_mux(o_sw0,o_sw1,o_sw2,o_sw3,i_sw0,i_sw1,i_sw2,i_sw3,i_data,i_cmplt,clk,rst_n);
output	o_sw0;
output	o_sw1;
output	o_sw2;
output	o_sw3;
input	i_sw0;
input	i_sw1;
input	i_sw2;
input	i_sw3;
input	[31:0]	i_data;
input	i_cmplt;
input	clk;
input	rst_n;

wire	r_sw0;
wire	r_sw1;
wire	r_sw2;
wire	r_sw3;
wire	s_sw0;
wire	s_sw1;
wire	s_sw2;
wire	s_sw3;

ir_sw	sm_u0(.o_sw0(r_sw0),.o_sw1(r_sw1),.o_sw2(r_sw2),.o_sw3(r_sw3),.i_data(i_data),.i_cmplt(i_cmplt),.clk(clk),.rst_n(rst_n));
sw_sw	sm_u1(.o_sw0(s_sw0),.o_sw1(s_sw1),.o_sw2(s_sw2),.o_sw3(s_sw3),.i_sw0(i_sw0),.i_sw1(i_sw1),.i_sw2(i_sw2),.i_sw3(i_sw3),.clk(clk),.rst_n(rst_n));

assign	o_sw0 = r_sw0&s_sw0;
assign	o_sw1 =	r_sw1&s_sw1;
assign	o_sw2 =	r_sw2&s_sw2;
assign	o_sw3 =	r_sw3&s_sw3;

endmodule

module fnd_dec(o_seg,i_num);
output	[6:0]	o_seg;
input	[3:0]	i_num;

reg	[6:0]	o_seg;


always @(i_num) begin
	case(i_num)
		4'd0:o_seg=7'b111_1110; //abc_defg
		4'd1:o_seg=7'b011_0000;
		4'd2:o_seg=7'b110_1101;
		4'd3:o_seg=7'b111_1001;
		4'd4:o_seg=7'b011_0011;
		4'd5:o_seg=7'b101_1011;
		4'd6:o_seg=7'b101_1111;
		4'd7:o_seg=7'b111_0000;
		4'd8:o_seg=7'b111_1111;
		4'd9:o_seg=7'b111_0011;
		4'd10:o_seg = 7'b111_0111 ;
		4'd11:o_seg = 7'b001_1111 ;
		4'd12:o_seg = 7'b100_1110 ;
		4'd13:o_seg = 7'b011_1101 ;
		4'd14:o_seg = 7'b100_1111 ;
		4'd15:o_seg = 7'b100_0111 ;
		default:o_seg=7'b000_0000;
	endcase
end

endmodule

module buzz(o_buzz,i_buzz_en1,i_buzz_en2,clk,rst_n);
output		o_buzz;
input		i_buzz_en1;
input		i_buzz_en2;
input		clk;
input		rst_n;


parameter	C = 191113;
parameter	D = 170262;
parameter	E = 151686;
parameter	F = 143173;
parameter	G = 63776;
parameter	A = 56818;
parameter	B = 50619;
parameter	S = 500;

wire		clk_bit;

nco		u0(.o_nco(clk_bit),.i_num(32'd9000000),
		   .clk(clk),.rst_n(rst_n));

reg	[6:0]	cnt;
wire	rst;
assign 	rst = i_buzz_en1 | i_buzz_en2 ; // start from beigning

always @(posedge clk_bit or negedge rst) begin
		if(rst == 1'b0) begin
			cnt <= 7'd0;
		end else begin
			if( cnt >= 7'd84) begin
				cnt <= 7'd0;
			end else begin
				cnt <= cnt +1'd1;
			end
		end
end

reg	[31:0]	nco_num;

always @(cnt) begin
		case(cnt)
			7'd0 : nco_num = E;
			7'd1 : nco_num = E;
			7'd2 : nco_num = E;//MI
			7'd3 : nco_num = D;
			7'd4 : nco_num = D;
			7'd5 : nco_num = D;//RE
			7'd6 : nco_num = C;
			7'd7 : nco_num = C;
			7'd8 : nco_num = C;//DO
			7'd9 :nco_num = D;
			7'd10:nco_num = D;
			7'd11:nco_num = D;//RE
			7'd12: nco_num = E;
			7'd13: nco_num = E;
			7'd14: nco_num = E;//MI
			7'd15:nco_num = S;
			7'd16:nco_num = E;
			7'd17: nco_num = E;
			7'd18: nco_num = E;//MI
			7'd19: nco_num =  S;
			7'd20:nco_num = E;
			7'd21:nco_num = E;
			7'd22: nco_num = E;//MI
			7'd23: nco_num = D;
			7'd24: nco_num  = D;
			7'd25: nco_num  = D;//RE
			7'd26: nco_num  = S;
			7'd27: nco_num = D;
			7'd28: nco_num = D;
			7'd29: nco_num  = D;//RE
			7'd30: nco_num = S;
			7'd31: nco_num  = D;
			7'd32: nco_num = D;
			7'd33: nco_num = D;//RE
			7'd34: nco_num = E;
			7'd35: nco_num  = E;
			7'd36: nco_num  = E;//MI
			7'd37:nco_num = S;
			7'd38: nco_num = E;
			7'd39: nco_num  = E;
			7'd40: nco_num  = E;
			7'd41: nco_num  = S;//MI
			7'd42: nco_num = E;
			7'd43: nco_num = E;
			7'd44: nco_num = E;//MI
			7'd45: nco_num  = S;
			7'd46: nco_num  = E;
			7'd47: nco_num = E;
			7'd48: nco_num = E;//MI
			7'd49: nco_num = D;
			7'd50: nco_num  = D;
			7'd51: nco_num  = D;
			7'd52: nco_num = C;
			7'd53: nco_num = C;
			7'd54: nco_num = C;
			7'd55: nco_num  = D;
			7'd56: nco_num  = D;
			7'd57: nco_num = D;
			7'd58: nco_num = E;
			7'd59: nco_num = E;	
			7'd60: nco_num = E;
			7'd61: nco_num = S;
			7'd62: nco_num = E;
			7'd63: nco_num = E;
			7'd64: nco_num = E;
			7'd65: nco_num  = S;
			7'd66: nco_num  = E;
			7'd67: nco_num = E;
			7'd68: nco_num = E;//MI
			7'd69: nco_num = D;
			7'd70: nco_num  = D;
			7'd71: nco_num  = D;
			7'd72: nco_num = D;
			7'd73: nco_num  = D;
			7'd74: nco_num  = D;
			7'd75: nco_num = E;
			7'd76: nco_num = E;
			7'd77: nco_num = E;
			7'd78: nco_num = D;
			7'd79: nco_num = D;
			7'd80: nco_num = D;
			7'd81: nco_num = C;
			7'd82: nco_num = C;
			7'd83: nco_num = C;
			7'd84: nco_num = S;
		endcase

end
wire		buzz;
nco		u1(.o_nco(buzz),.i_num(nco_num),
		   .clk(clk),.rst_n(rst_n));
assign		o_buzz = buzz & (i_buzz_en1|i_buzz_en2);
endmodule

module blink(blnk_seg,on_seg,clk,rst_n);
output	[13:0]	blnk_seg;
input	[13:0]	on_seg;
input		clk;
input		rst_n;

reg	[13:0]	blnk_seg;

parameter 	OFF = 14'b0000000_0000000;

always @(posedge clk or negedge rst_n)begin
	if(rst_n == 1'b0)begin
		blnk_seg <= on_seg;
	end else begin	
		if(blnk_seg == OFF )begin
			blnk_seg <= on_seg;
		end else begin
			blnk_seg <= OFF ;
		end
	
	end
end

endmodule

module blink_mux(o_six_seg,i_six_seg,i_mode,i_position,i_timer_on,clk,rst_n);
output	[41:0]	o_six_seg;

input	[41:0]	i_six_seg;
input	[1:0]	i_mode;
input	[1:0]	i_position;

input		i_timer_on;
input		clk;
input		rst_n;

parameter	MODE_CLOCK = 2'b00;
parameter	MODE_SETUP = 2'b01;
parameter	MODE_ALARM = 2'b10;
parameter	MODE_TIMER = 2'b11;

parameter	POS_SEC	   = 2'b00;	
parameter	POS_MIN	   = 2'b01;
parameter	POS_HOUR   = 2'b10;


wire 	bclk;
nco(.o_nco(bclk),.i_num(32'd10000000),.clk(clk),.rst_n(rst_n));

wire	[13:0]	blk_sec;
wire	[13:0]	blk_min;
wire	[13:0]	blk_hour;

blink	b_u0(.blnk_seg(blk_sec),.on_seg(i_six_seg[13:0]),.clk(bclk),.rst_n(rst_n));
blink	b_u2(.blnk_seg(blk_min),.on_seg(i_six_seg[27:14]),.clk(bclk),.rst_n(rst_n));
blink	b_u1(.blnk_seg(blk_hour),.on_seg(i_six_seg[41:28]),.clk(bclk),.rst_n(rst_n));

reg	[41:0]	o_six_seg;

always@(*)begin
	  case(i_mode)
		MODE_CLOCK: o_six_seg <= i_six_seg;
		
		MODE_TIMER:begin
				case(i_timer_on)
					1'b0:begin
						case(i_position)
							POS_SEC:begin
								o_six_seg[13:0]<=blk_sec;
				        			o_six_seg[27:14]<=i_six_seg[27:14];
				        			o_six_seg[41:28]<=i_six_seg[41:28];

								end
							POS_MIN:begin
								o_six_seg[13:0]<=i_six_seg[13:0];
				        			o_six_seg[27:14]<=blk_min;
				       				o_six_seg[41:28]<=i_six_seg[41:28];

								end
							POS_HOUR:begin
								o_six_seg[13:0]<=i_six_seg[13:0];
				        			o_six_seg[27:14]<=i_six_seg[27:14];
				        			o_six_seg[41:28]<=blk_hour;
					 			end	
							endcase	
					     end
					1'b1:begin
						o_six_seg <= i_six_seg;
					     end
				endcase
			   end
	
		default:begin
			case(i_position)
				POS_SEC:begin
					o_six_seg[13:0]<=blk_sec;
				        o_six_seg[27:14]<=i_six_seg[27:14];
				        o_six_seg[41:28]<=i_six_seg[41:28];

					end
				POS_MIN:begin
					o_six_seg[13:0]<=i_six_seg[13:0];
				        o_six_seg[27:14]<=blk_min;
				        o_six_seg[41:28]<=i_six_seg[41:28];

					end
				POS_HOUR:begin
					o_six_seg[13:0]<=i_six_seg[13:0];
				        o_six_seg[27:14]<=i_six_seg[27:14];
				        o_six_seg[41:28]<=blk_hour;
					 end	
			endcase	
			end
		endcase
end	

endmodule

module	hms_dcnt(o_hms_dcnt,o_min_hit,i_prev,i_tmp,clk,rst_n);

output	[5:0]	o_hms_dcnt;
output		o_min_hit;
input	[5:0]	i_prev;
input	[5:0]	i_tmp;
input		clk;
input		rst_n;

reg	[5:0]	o_hms_dcnt;
reg		o_min_hit;
always@(posedge clk or negedge rst_n) begin
		if(rst_n == 1'b0)begin
			o_hms_dcnt <= i_tmp;
			o_min_hit  <= 1'b0;
		end else begin
			if(o_hms_dcnt <= 6'd0) begin
				if(i_prev <= 6'd0)begin
					o_min_hit<=1'b0;
					o_hms_dcnt<=6'd0;
				end else begin
					o_min_hit<=1'b1;
					o_hms_dcnt<=6'd59;
				end
				
		        end else begin
				o_min_hit <=1'b0;
				o_hms_dcnt <= o_hms_dcnt -1'b1;
			end
		end
end

endmodule

module	down_cnt(o_sec,o_min,o_hour,i_sec,i_min,i_hour,i_timer_on,sw3,clk,rst_n);
output	[5:0]	o_sec;
output	[5:0]	o_min;
output	[5:0]	o_hour;

input	[5:0]	i_sec;
input	[5:0]	i_min;
input	[5:0]	i_hour;

input		i_timer_on;
input		sw3;
input		clk;
input		rst_n;

wire	dclk_1hz;
nco	d0(.o_nco(dclk_1hz),.i_num(32'd50000000),.clk(clk),.rst_n(rst_n));
reg	dclock;
reg	d_sec;
reg	d_min;
reg	d_hour;
always@(*)begin
	case(i_timer_on)
		1'b0:dclock<=1'b0;
		1'b1: dclock<=dclk_1hz;
	endcase
end

wire	d_sec_min;
wire	d_min_min;
wire	d_hour_min;

hms_dcnt	d1(.o_hms_dcnt(o_sec),.o_min_hit(d_sec_min),.i_prev(o_min),.i_tmp(i_sec),.clk(dclock),.rst_n(sw3));
hms_dcnt	d2(.o_hms_dcnt(o_min),.o_min_hit(d_min_min),.i_prev(o_hour),.i_tmp(i_min),.clk(d_sec_min),.rst_n(sw3));
hms_dcnt	d3(.o_hms_dcnt(o_hour),.o_min_hit(d_hour_min),.i_prev(1'b0),.i_tmp(i_hour),.clk(d_min_min),.rst_n(sw3));

endmodule

module hms_timer(o_timer_buzz,t_sec,t_min,t_hour,i_sec_timer,i_min_timer,i_hour_timer,i_timer_on,sw3,clk,rst_n);
output		o_timer_buzz;

output	[5:0]	t_sec;
output	[5:0]	t_min;
output	[5:0]	t_hour;

input		i_sec_timer;
input		i_min_timer;
input		i_hour_timer;

input		i_timer_on;
input		clk;
input		rst_n;
input 		sw3;

wire	[5:0]	t0_sec;
wire	[5:0]	t0_min;
wire	[5:0]	t0_hour;

hms_cnt		u6_sec(.o_hms_cnt(t0_sec),.o_max_hit(),.i_max_cnt(6'd59),.clk(i_sec_timer),.rst_n(rst_n));
hms_cnt		u7_min(.o_hms_cnt(t0_min),.o_max_hit(),.i_max_cnt(6'd59),.clk(i_min_timer),.rst_n(rst_n));
hms_cnt		u8_hour(.o_hms_cnt(t0_hour),.o_max_hit(),.i_max_cnt(6'd23),.clk(i_hour_timer),.rst_n(rst_n));

wire	[5:0]	t1_sec;
wire	[5:0]	t1_min;
wire	[5:0]	t1_hour;
down_cnt	u9_dcnt(.o_sec(t1_sec),.o_min(t1_min),.o_hour(t1_hour),.i_sec(t0_sec),.i_min(t0_min),.i_hour(t0_hour),.i_timer_on(i_timer_on),.sw3(sw3),.clk(clk),.rst_n(rst_n));

reg	o_timer_buzz;
always@(posedge clk or negedge rst_n)begin
	if(rst_n==1'b0)begin
		o_timer_buzz<=1'b0;
	end else begin
		if((t1_sec==6'd0)&&(t1_min==6'd0)&&(t1_hour==6'd0))begin
			o_timer_buzz<=1'b1 & i_timer_on;
		end else begin
			o_timer_buzz <=o_timer_buzz & i_timer_on;
		end
	end
end


reg	[5:0]	t_sec;
reg	[5:0]	t_min;
reg	[5:0]	t_hour;

always@(*)begin
	case(i_timer_on)
		1'b0:begin
			t_sec<=t0_sec;
			t_min<=t0_min;
			t_hour<=t0_hour;
		     end
		1'b1:begin
			t_sec<=t1_sec;
			t_min<=t1_min;
			t_hour<=t1_hour;
		     end
	endcase
end
endmodule

module hms_alarm(o_alarm_buzz,c_sec,c_min,c_hour,a_sec,a_min,a_hour,i_alarm_on,sw3,clk,rst_n);
output		 o_alarm_buzz;

input	[5:0]	c_sec;
input	[5:0]	c_min;
input	[5:0]	c_hour;

input	[5:0]	a_sec;
input	[5:0]	a_min;
input	[5:0]	a_hour;

input		i_alarm_on;
input		sw3;
input		clk;
input		rst_n;

reg	[5:0]	a0_sec;
reg	[5:0]	a0_min;
reg	[5:0]	a0_hour;

always@(negedge sw3)begin
	if(sw3==1'b0)begin
		a0_sec <= a_sec;
		a0_min <= a_min;
		a0_hour<= a_hour;
	end	
end

reg		o_alarm_buzz;
always@(posedge clk or negedge rst_n)begin
	if(rst_n==1'b0)begin
		o_alarm_buzz<=1'b0;
	end else begin
		if((c_sec==a0_sec)&&(c_min==a0_min)&&(c_hour==a0_hour))begin
			o_alarm_buzz<=1'b1 & i_alarm_on;
		end else begin
			o_alarm_buzz<=o_alarm_buzz&i_alarm_on;
		end
	end
end
	
endmodule

module led_disp(o_seg,o_dp,o_enb,i_six_seg,i_six_dp,clk,rst_n);
output	[6:0]	o_seg;
output		o_dp;
output	[5:0]	o_enb;
input	[41:0]	i_six_seg;
input	[5:0]	i_six_dp;
input		clk;
input		rst_n;

wire		gen_clk;
nco		u_nco(.o_nco(gen_clk),.i_num(32'd50000),.clk(clk),.rst_n(rst_n));

reg	[3:0]	common_node;
always @(posedge gen_clk or negedge rst_n) begin
		if(rst_n == 1'b0) begin
			common_node <= 4'd0;
		end else begin
			if(common_node >= 4'd5) begin
				common_node <= 4'd0;
			end else begin
				common_node <= common_node +1'b1;
			end
		end
end

reg	[5:0]	o_enb;
always @(common_node) begin
		case(common_node)
			4'd0:o_enb=6'b111110;
			4'd1:o_enb=6'b111101;
			4'd2:o_enb=6'b111011;
			4'd3:o_enb=6'b110111;
			4'd4:o_enb=6'b101111;
			4'd5:o_enb=6'b011111;
		endcase
end

reg		o_dp;
always @(common_node) begin
		case(common_node)
			4'd0:o_dp=i_six_dp[0];
			4'd1:o_dp=i_six_dp[1];
			4'd2:o_dp=i_six_dp[2];
			4'd3:o_dp=i_six_dp[3];
			4'd4:o_dp=i_six_dp[4];
			4'd5:o_dp=i_six_dp[5];
		endcase
end

reg	[6:0]	o_seg;
always @(common_node) begin
		case(common_node)
			4'd0:o_seg=i_six_seg[6:0];
			4'd1:o_seg=i_six_seg[13:7];
			4'd2:o_seg=i_six_seg[20:14];
			4'd3:o_seg=i_six_seg[27:21];
			4'd4:o_seg=i_six_seg[34:28];
			4'd5:o_seg=i_six_seg[41:35];
		endcase
end

endmodule

module hms_cnt(o_hms_cnt,o_max_hit,i_max_cnt,clk,rst_n);

output	[5:0]	o_hms_cnt;
output 		o_max_hit;
input 	[5:0]	i_max_cnt;
input 		clk;
input 		rst_n;

reg	[5:0] 	o_hms_cnt;
reg		o_max_hit;

always @(posedge clk or negedge rst_n) begin
	if(rst_n == 1'b0)begin
		o_hms_cnt <= 6'd0;
		o_max_hit <= 1'b0;
	end else begin
		if(o_hms_cnt >= i_max_cnt) begin
			o_hms_cnt <=6'd0;
			o_max_hit <=1'b1;
		end else begin
			o_hms_cnt <= o_hms_cnt +1'b1;
			o_max_hit <= 1'b0;
		end
	end
end

endmodule

module hourminsec(o_sec ,o_min ,o_hour ,
		  o_max_hit_sec ,o_max_hit_min ,o_max_hit_hour ,
		  o_alarm_buzz,o_timer_buzz,
		  i_sec_clk ,i_min_clk ,i_hour_clk ,
		  i_sec_alarm ,i_min_alarm ,i_hour_alarm,
		  i_sec_timer ,i_min_timer ,i_hour_timer,
		  i_mode,i_timer_on,i_sw3,i_alarm_on,clk ,rst_n );
output	[5:0]	o_sec;
output	[5:0]	o_min;
output	[5:0]	o_hour;

output		o_max_hit_sec;	
output		o_max_hit_min;
output		o_max_hit_hour;	

output		o_alarm_buzz;
output		o_timer_buzz;

input		i_sec_clk;
input		i_min_clk;
input		i_hour_clk ;

input		i_sec_alarm;
input		i_min_alarm;
input		i_hour_alarm;

input		i_sec_timer;
input		i_min_timer;
input		i_hour_timer;

input	[1:0]	i_mode;
input		i_timer_on;
input		i_alarm_on;
input		i_sw3;

input		rst_n;
input		clk;

parameter	MODE_CLOCK = 2'b00;
parameter	MODE_SETUP = 2'b01;
parameter	MODE_ALARM = 2'b10;
parameter	MODE_TIMER = 2'b11;


//MODE_CLOCK
wire	[5:0]	c_sec;
wire	[5:0]	c_min;
wire	[5:0]	c_hour;

hms_cnt		u0_sec(.o_hms_cnt(c_sec),.o_max_hit(o_max_hit_sec),.i_max_cnt(6'd59),.clk(i_sec_clk),.rst_n(rst_n));
hms_cnt		u1_min(.o_hms_cnt(c_min),.o_max_hit(o_max_hit_min),.i_max_cnt(6'd59),.clk(i_min_clk),.rst_n(rst_n));
hms_cnt		u2_hour(.o_hms_cnt(c_hour),.o_max_hit(o_max_hit_hour),.i_max_cnt(6'd23),.clk(i_hour_clk),.rst_n(rst_n));
//MODE_ALARM
wire	[5:0]	a_sec;
wire	[5:0]	a_min;
wire	[5:0]	a_hour;

hms_cnt		u3_sec(.o_hms_cnt(a_sec),.o_max_hit(),.i_max_cnt(6'd59),.clk(i_sec_alarm),.rst_n(rst_n));
hms_cnt		u4_min(.o_hms_cnt(a_min),.o_max_hit(),.i_max_cnt(6'd59),.clk(i_min_alarm),.rst_n(rst_n));
hms_cnt		u5_hour(.o_hms_cnt(a_hour),.o_max_hit(),.i_max_cnt(6'd23),.clk(i_hour_alarm),.rst_n(rst_n));

hms_alarm	a0(.o_alarm_buzz(o_alarm_buzz),.c_sec(c_sec),.c_min(c_min),.c_hour(c_hour),.a_sec(a_sec),.a_min(a_min),.a_hour(a_hour),.i_alarm_on(i_alarm_on),.sw3(i_sw3),.clk(clk),.rst_n(rst_n));

//MODE_TIMER

wire	[5:0]	t_sec;
wire 	[5:0]	t_min;
wire	[5:0] 	t_hour;
hms_timer	t0(.o_timer_buzz(o_timer_buzz),.t_sec(t_sec),.t_min(t_min),.t_hour(t_hour),
		   .i_sec_timer(i_sec_timer),.i_min_timer(i_min_timer),.i_hour_timer(i_hour_timer),
		   .i_timer_on(i_timer_on),.sw3(i_sw3),.clk(clk),.rst_n(rst_n));


reg	[5:0]	o_sec;
reg	[5:0]	o_min;
reg	[5:0]	o_hour;

always@(*)begin
	case(i_mode)
		MODE_CLOCK:begin
				o_sec<=c_sec;
				o_min<=c_min;
				o_hour<=c_hour;
			   end
		MODE_SETUP:begin
				o_sec<=c_sec;
				o_min<=c_min;
				o_hour<=c_hour;
			   end
		MODE_ALARM:begin
				o_sec<=a_sec;
				o_min<=a_min;
				o_hour<=a_hour;
			   end
		MODE_TIMER:begin
				 o_sec<=t_sec;
				 o_min<=t_min;
				 o_hour<=t_hour;
			   end
			   
	endcase
end


endmodule

module controller(o_sec_clk ,o_min_clk ,o_hour_clk , 
		  o_sec_alarm ,o_min_alarm ,o_hour_alarm ,
		  o_sec_timer ,o_min_timer ,o_hour_timer ,
		  o_mode,o_position,o_timer_on,o_alarm_on,o_sw3,
		  i_sw0 ,i_sw1 ,i_sw2 ,i_sw3,
		  i_max_hit_sec ,i_max_hit_min ,i_max_hit_hour, 
		  i_data,i_cmplt,clk ,rst_n );
output	o_sec_clk;
output	o_min_clk;
output	o_hour_clk;

output	o_sec_alarm;
output	o_min_alarm;
output	o_hour_alarm;

output	o_sec_timer;
output	o_min_timer;	
output	o_hour_timer;

output	o_sw3;
output	[1:0]o_mode;
output	[1:0]o_position;
output	     o_timer_on;
output	     o_alarm_on;

input	i_sw0;
input	i_sw1;
input	i_sw2;
input	i_sw3;

input	i_max_hit_sec;
input	i_max_hit_min;
input	i_max_hit_hour;


input	[31:0]	i_data;
input	i_cmplt;	
input	clk;
input	rst_n;


parameter	MODE_CLOCK = 1'b0;
parameter	MODE_SETUP = 1'b1;
parameter	MODE_ALARM = 2'b10;
parameter	MODE_TIMER = 2'b11;

parameter	POS_SEC	   = 2'b00;	
parameter	POS_MIN	   = 2'b01;
parameter	POS_HOUR   = 2'b10;	

wire	clk_1hz;
nco	nco_u0(.o_nco(clk_1hz),.i_num(32'd50000000),.clk(clk),.rst_n(rst_n));



wire	sw0;
wire	sw1;
wire	sw2;
wire 	sw3;

sw_mux	sw_u0(.o_sw0(sw0),.o_sw1(sw1),.o_sw2(sw2),.o_sw3(sw3),
	      .i_sw0(i_sw0),.i_sw1(i_sw1),.i_sw2(i_sw2),.i_sw3(i_sw3),
	      .i_data(i_data),.i_cmplt(i_cmplt),.clk(clk),.rst_n(rst_n));
assign	o_sw3=sw3;

reg	[1:0] o_mode;
always @(posedge sw0 or negedge rst_n) begin
	if(rst_n== 1'b0)begin
		o_mode<=MODE_CLOCK;
	end else begin
		o_mode<=o_mode+1'b1;
	end
end

reg	[1:0]	o_position;
always@(posedge sw1 or negedge rst_n) begin
	if(rst_n== 1'b0)begin
		o_position <= POS_SEC;
	end else begin
		if(o_position >= POS_HOUR) begin
			o_position <= POS_SEC;
		end else begin
			o_position <= o_position +1'b1;
		end
	end
end

reg	o_timer_on;
always@(posedge sw3 or negedge rst_n)begin
	if(rst_n==1'b0)begin
		o_timer_on <=1'b0;
	end else begin
		if(o_mode == MODE_TIMER)begin
			o_timer_on <=o_timer_on+1'b1;
		end else begin
			o_timer_on <=1'b0;
		end
	end
end
//---------------------------------------//
reg	o_alarm_on;
always@(posedge sw3 or negedge rst_n)begin
	if(rst_n==1'b0)begin
		o_alarm_on<=1'b0;
	end else begin
		if(o_mode == MODE_ALARM)begin
			o_alarm_on <= o_alarm_on +1'b1;
		end else begin
			o_alarm_on <= o_alarm_on +1'b1;
		end
	end
end
//-------------------------------------//

reg 	o_sec_clk;
reg 	o_min_clk;
reg	o_hour_clk;

reg	o_sec_alarm;
reg	o_min_alarm;
reg	o_hour_alarm;

reg	o_sec_timer;
reg	o_min_timer;	
reg	o_hour_timer;


always @(*)begin
	case(o_mode)
		MODE_CLOCK:begin
				o_sec_clk <= clk_1hz;
				o_min_clk <= i_max_hit_sec;
				o_hour_clk<= i_max_hit_min;
			   end
		MODE_SETUP:begin
				case(o_position)
					POS_SEC:begin
							o_sec_clk <= ~sw2;
							o_min_clk <= 1'b0;
							o_hour_clk<= 1'b0;

							o_sec_alarm<= 1'b0;
							o_min_alarm<= 1'b0;
							o_hour_alarm<=1'b0;

							o_sec_timer<=1'b0;
							o_min_timer<=1'b0;	
							o_hour_timer<=1'b0;
						end	
					POS_MIN:begin
							o_sec_clk <= 1'b0;
							o_min_clk <= ~sw2;
							o_hour_clk<= 1'b0;	

							o_sec_alarm<= 1'b0;
							o_min_alarm<= 1'b0;
							o_hour_alarm<=1'b0;

							o_sec_timer<=1'b0;
							o_min_timer<=1'b0;	
							o_hour_timer<=1'b0;
						end
					POS_HOUR:begin
							o_sec_clk <= 1'b0;
							o_min_clk <= 1'b0;	
							o_hour_clk<= ~sw2;

							o_sec_alarm<= 1'b0;
							o_min_alarm<= 1'b0;
							o_hour_alarm<=1'b0;

							o_sec_timer<=1'b0;
							o_min_timer<=1'b0;	
							o_hour_timer<=1'b0;
						end
				endcase
			   end
		MODE_ALARM:begin
				case(o_position)
					POS_SEC:begin
						o_sec_clk <= clk_1hz;
						o_min_clk <= i_max_hit_sec;
						o_hour_clk<= i_max_hit_min;

						o_sec_alarm<=~sw2;
						o_min_alarm<=1'b0;	
						o_hour_alarm<=1'b0;
						
						o_sec_timer<=1'b0;
						o_min_timer<=1'b0;	
						o_hour_timer<=1'b0;

						end
					POS_MIN:begin
						o_sec_clk <= clk_1hz;
						o_min_clk <= i_max_hit_sec;
						o_hour_clk<= i_max_hit_min;
						
						o_sec_alarm<=1'b0;
						o_min_alarm<=~sw2;	
						o_hour_alarm<=1'b0;

						o_sec_timer<=1'b0;
						o_min_timer<=1'b0;	
						o_hour_timer<=1'b0;
						end
					POS_HOUR:begin
						o_sec_clk <= clk_1hz;
						o_min_clk <= i_max_hit_sec;
						o_hour_clk<= i_max_hit_min;

						o_sec_alarm<=1'b0;
						o_min_alarm<=1'b0;	
						o_hour_alarm<=~sw2;

						o_sec_timer<=1'b0;
						o_min_timer<=1'b0;	
						o_hour_timer<=1'b0;
						 end
				endcase
			   end
		MODE_TIMER:begin
				case(o_position)
					POS_SEC:begin
						o_sec_clk <= clk_1hz;
						o_min_clk <= i_max_hit_sec;
						o_hour_clk<= i_max_hit_min;

						o_sec_alarm<= 1'b0;
						o_min_alarm<= 1'b0;
						o_hour_alarm<=1'b0;

						o_sec_timer<=~sw2;
						o_min_timer<=1'b0;	
						o_hour_timer<=1'b0;
							
						end	
					POS_MIN:begin
						o_sec_clk <= clk_1hz;
						o_min_clk <= i_max_hit_sec;
						o_hour_clk<= i_max_hit_min;

						o_sec_alarm<= 1'b0;
						o_min_alarm<= 1'b0;
						o_hour_alarm<=1'b0;

						o_sec_timer<=1'b0;
						o_min_timer<=~sw2;	
						o_hour_timer<=1'b0;	
						end
					POS_HOUR:begin
						o_sec_clk <= clk_1hz;
						o_min_clk <= i_max_hit_sec;	
						o_hour_clk<= i_max_hit_min;
	
						o_sec_alarm<= 1'b0;
						o_min_alarm<= 1'b0;
						o_hour_alarm<=1'b0;
							
						o_sec_timer<=1'b0;
						o_min_timer<=1'b0;	
						o_hour_timer<=~sw2;
						end
				endcase
				
			     end

	endcase
end
endmodule

module top_hms_clock(o_seg,o_seg_enb,o_seg_dp,o_buzz,i_sw0,i_sw1,i_sw2,i_sw3,i_ir_rxb,clk,rst_n);
output	[6:0]	o_seg;
output	[5:0]	o_seg_enb;
output		o_seg_dp;
output		o_buzz;
input		i_sw0;
input		i_sw1;
input		i_sw2;
input		i_sw3;
input		i_ir_rxb;
input		clk;
input		rst_n;

wire sec_clk;
wire min_clk;
wire hour_clk;

wire 	sec_alarm;
wire 	min_alarm;
wire 	hour_alarm;

wire 	sec_timer;
wire 	min_timer;
wire 	hour_timer;

wire	max_hit_sec;
wire	max_hit_min;
wire	max_hit_hour;

wire	[31:0]	data;
wire		cmplt;
ir_rx		 irx_u( .o_data(data) ,.o_cmplt(cmplt) ,.i_ir_rxb(i_ir_rxb) ,.clk(clk) ,.rst_n(rst_n));

wire 	[1:0]	mode;
wire	[1:0]	position;
wire		timer_on;
wire		alarm_on;
wire		sw3;
 
controller	 crtl_u( .o_sec_clk(sec_clk) ,.o_min_clk(min_clk) ,.o_hour_clk(hour_clk) ,
		  	 .o_sec_alarm(sec_alarm) ,.o_min_alarm(min_alarm) ,.o_hour_alarm(hour_alarm) ,
		 	 .o_sec_timer(sec_timer) ,.o_min_timer(min_timer) ,.o_hour_timer(hour_timer) ,
			 .o_mode(mode),.o_position(position),.o_timer_on(timer_on),.o_alarm_on(alarm_on),.o_sw3(sw3),
		 	 .i_sw0(i_sw0) ,.i_sw1(i_sw1) ,.i_sw2(i_sw2) ,.i_sw3(i_sw3),
		 	 .i_max_hit_sec(max_hit_sec) ,.i_max_hit_min(max_hit_min) ,.i_max_hit_hour(max_hit_hour),
		 	 .i_data(data) ,.i_cmplt(cmplt) ,.clk(clk) ,.rst_n(rst_n));




wire	[5:0]	o_sec;
wire	[5:0]	o_min;
wire	[5:0]	o_hour;

wire	alarm_buzz;
wire	timer_buzz;
hourminsec	 hms_u( .o_sec(o_sec) ,.o_min(o_min) ,.o_hour(o_hour) ,
		  	.o_max_hit_sec(max_hit_sec) ,.o_max_hit_min(max_hit_min) ,.o_max_hit_hour(max_hit_hour) ,
		  	.o_alarm_buzz(alarm_buzz),.o_timer_buzz(timer_buzz),
			.i_sec_clk(sec_clk) ,.i_min_clk(min_clk) ,.i_hour_clk(hour_clk) ,
		  	.i_sec_alarm(sec_alarm) ,.i_min_alarm(min_alarm) ,.i_hour_alarm(hour_alarm),
		 	.i_sec_timer(sec_timer) ,.i_min_timer(min_timer) ,.i_hour_timer(hour_timer),
		 	.i_mode(mode),.i_timer_on(timer_on),.i_sw3(sw3),.i_alarm_on(alarm_on),.clk(clk) ,.rst_n(rst_n) );


wire	[3:0]	l_sec;
wire	[3:0]	r_sec;
double		dbl_sec(.o_left(l_sec), .o_right(r_sec), .i_fig(o_sec));

wire	[3:0]	l_min;
wire	[3:0]	r_min;
double		dbl_min(.o_left(l_min), .o_right(r_min), .i_fig(o_min));

wire	[3:0]	l_hour;
wire	[3:0]	r_hour;

double		dbl_hour( .o_left(l_hour), .o_right(r_hour), .i_fig(o_hour));

wire	[6:0]	seg_sec_l;
wire	[6:0]	seg_sec_r;
fnd_dec		fnd_u0(.o_seg(seg_sec_l),.i_num(l_sec));
fnd_dec		fnd_u1(.o_seg(seg_sec_r),.i_num(r_sec));

wire	[6:0]	seg_min_l;
wire	[6:0]	seg_min_r;
fnd_dec		fnd_u2(.o_seg(seg_min_l),.i_num(l_min));
fnd_dec		fnd_u3(.o_seg(seg_min_r),.i_num(r_min));

wire	[6:0]	seg_hour_l;
wire	[6:0]	seg_hour_r;
fnd_dec		fnd_u4(.o_seg(seg_hour_l),.i_num(l_hour));
fnd_dec		fnd_u5(.o_seg(seg_hour_r),.i_num(r_hour));

wire	[41:0]	six_seg;
assign	six_seg={seg_hour_l,seg_hour_r,seg_min_l,seg_min_r,seg_sec_l,seg_sec_r};

wire	[41:0]	seg_six;
blink_mux	blnk_u(.o_six_seg(seg_six),.i_six_seg(six_seg),.i_mode(mode),.i_position(position),.i_timer_on(timer_on),.clk(clk),.rst_n(rst_n));

wire	[5:0]	six_dp;
mode_dp		dp_u(.o_six_dp(six_dp),.i_mode(mode));

led_disp	disp_u(.o_seg(o_seg),.o_dp(o_seg_dp),.o_enb(o_seg_enb),.i_six_seg(seg_six),.i_six_dp(six_dp),.clk(clk),.rst_n(rst_n));



buzz		buzz_u(.o_buzz(o_buzz),.i_buzz_en1(timer_buzz),.i_buzz_en2(alarm_buzz),.clk(clk),.rst_n(rst_n));

endmodule