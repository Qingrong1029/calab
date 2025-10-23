//======================================================================
//  File: div.v (fixed version for 8-cycle non-pipelined divider)
//======================================================================

module div (
    input  wire         clk,
    input  wire         resetn,

    // 控制输入
    input  wire         ex_div_en,
    input  wire [1:0]   ex_div_op,
    input  wire [31:0]  alu_src1,
    input  wire [31:0]  alu_src2,
    input  wire [31:0]  signed_src1,
    input  wire [31:0]  signed_src2,

    // 输出
    output wire [31:0]  div_result,
    output wire         div_busy,
    output wire         div_done
);

    //==================================================================
    //  除法器接口信号
    //==================================================================
    wire div_s_tvalid, div_s_tready, div_s_valid;
    wire [63:0] div_s_result;
    wire div_u_tvalid, div_u_tready, div_u_valid;
    wire [63:0] div_u_result;

    // 有符号除法器
    div_gen_0 div_signed (
        .aclk                  (clk),
        .s_axis_divisor_tvalid (div_s_tvalid),
        .s_axis_divisor_tready (div_s_tready),
        .s_axis_divisor_tdata  (signed_src2),
        .s_axis_dividend_tvalid(div_s_tvalid),
        .s_axis_dividend_tready(),
        .s_axis_dividend_tdata (signed_src1),
        .m_axis_dout_tvalid    (div_s_valid),
        .m_axis_dout_tdata     (div_s_result)
    );

    // 无符号除法器
    div_gen_1 div_unsigned (
        .aclk                  (clk),
        .s_axis_divisor_tvalid (div_u_tvalid),
        .s_axis_divisor_tready (div_u_tready),
        .s_axis_divisor_tdata  (alu_src2),
        .s_axis_dividend_tvalid(div_u_tvalid),
        .s_axis_dividend_tready(),
        .s_axis_dividend_tdata (alu_src1),
        .m_axis_dout_tvalid    (div_u_valid),
        .m_axis_dout_tdata     (div_u_result)
    );

    //==================================================================
    //  启动握手逻辑
    //==================================================================
    wire start_signed   = ex_div_en && !div_busy && (ex_div_op[1:0] == 2'b00 || ex_div_op[1:0] == 2'b01);
    wire start_unsigned = ex_div_en && !div_busy && (ex_div_op[1:0] == 2'b10 || ex_div_op[1:0] == 2'b11);

    // 输入握手成功信号
    wire div_s_start = start_signed   && div_s_tready;
    wire div_u_start = start_unsigned && div_u_tready;

    assign div_s_tvalid = start_signed;
    assign div_u_tvalid = start_unsigned;

    //==================================================================
    //  Busy控制
    //==================================================================
    reg div_busy_r;
    assign div_busy = div_busy_r;

    always @(posedge clk or negedge resetn) begin
        if (~resetn)
            div_busy_r <= 1'b0;
        else if (div_s_valid || div_u_valid)
            div_busy_r <= 1'b0;     // 完成
        else if (div_s_start || div_u_start)
            div_busy_r <= 1'b1;     // 真正 handshake 成功才 busy
    end

    // 完成信号
    assign div_done = div_s_valid | div_u_valid;

    //==================================================================
    //  结果选择
    //==================================================================
    reg [31:0] div_result_r;
    assign div_result = div_result_r;

    always @(*) begin
        case (ex_div_op[1:0])
            2'b00: div_result_r = div_s_result[63:32];
            2'b01: div_result_r = div_s_result[31:0];
            2'b10: div_result_r = div_u_result[63:32];
            2'b11: div_result_r = div_u_result[31:0];
            default: div_result_r = 32'b0;
        endcase
    end

endmodule

