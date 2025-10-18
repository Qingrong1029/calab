module EX (
    input           clk,
    input           resetn,

    // 流水线握手信号
    output          ex_allowin,
    input           id_ex_valid,
    input   [186:0] id_ex_bus,

    output          ex_mem_valid,
    input           mem_allowin,
    output  [102:0] ex_mem_bus,

    // 数据存储器接口
    output          data_sram_en,
    output  [ 3:0]  data_sram_we,
    output  [31:0]  data_sram_addr,
    output  [31:0]  data_sram_wdata,

    // 反馈给 ID 阶段的旁路/阻塞信号
    output  [39:0]  ex_id_bus    // {ex_bypass , ex_ld , ex_dest , alu_result , ex_div_busy}
);

    //======================================================================
    //  流水线控制信号
    //======================================================================
    reg             ex_valid;
    wire            ex_ready_go;
    reg     [186:0] id_ex_bus_vld;

    assign  ex_ready_go = 1'b1;   // 除法器 busy 由 ID 控制，不在 EX 内阻塞
    assign  ex_mem_valid = ex_ready_go & ex_valid;
    assign  ex_allowin = ex_mem_valid & mem_allowin | ~ex_valid;

    always @(posedge clk) begin
        if (~resetn)
            ex_valid <= 1'b0;
        else if (ex_allowin)
            ex_valid <= id_ex_valid;
    end

    always @(posedge clk) begin
        if (id_ex_valid & ex_allowin)
            id_ex_bus_vld <= id_ex_bus;
    end

    //======================================================================
    //  ID→EX 总线拆分
    //======================================================================
    wire             ex_gr_we;     // 写寄存器使能
    wire             mem_we;       // 访存写使能
    wire             res_from_mem; // 是否load指令
    wire    [11:0]   alu_op;
    wire             ex_div_en;    // 除法启动信号
    wire    [2:0]    ex_div_op;    // 除法操作类型（000 div，001 mod，010 divu，011 modu）
    wire    [31:0]   alu_src1;
    wire    [31:0]   alu_src2;
    wire    [4:0]    ex_dest;
    wire    [31:0]   rkd_value;
    wire    [31:0]   ex_inst;
    wire    [31:0]   ex_pc;

    assign {
        ex_gr_we, mem_we, res_from_mem,
        alu_op, ex_div_en, ex_div_op,
        alu_src1, alu_src2,
        ex_dest, rkd_value, ex_inst, ex_pc
    } = id_ex_bus_vld;

    //======================================================================
    // ALU 普通运算
    //======================================================================
    wire [31:0] alu_result;
    alu my_alu (    
        .alu_op    (alu_op),
        .alu_src1  (alu_src1),
        .alu_src2  (alu_src2),
        .alu_result(alu_result)
    );

    //======================================================================
    //  除法器实例化（有符号 + 无符号）
    //======================================================================
    wire signed [31:0] signed_src1 = alu_src1;
    wire signed [31:0] signed_src2 = alu_src2;

    // 除法器接口信号（有符号）
    wire div_s_tvalid, div_s_tready;
    wire [63:0] div_s_result;
    wire div_s_valid;

    div_gen_s div_signed (
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

    // 除法器接口信号（无符号）
    wire div_u_tvalid, div_u_tready;
    wire [63:0] div_u_result;
    wire div_u_valid;

    div_gen_u div_unsigned (
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

    //======================================================================
    //  除法控制逻辑（启动与结果选择）
    //======================================================================
    reg div_busy;
    reg [31:0] div_result;

    always @(posedge clk) begin
        if (~resetn)
            div_busy <= 1'b0;
        else if (ex_div_en && !div_busy)
            div_busy <= 1'b1;                // 启动除法器
        else if ((div_s_valid | div_u_valid))
            div_busy <= 1'b0;                // 完成后释放 busy
    end

    // 除法启动信号，只在启动时有效
    assign div_s_tvalid = ex_div_en && !div_busy && (ex_div_op[1:0] == 2'b00 || ex_div_op[1:0] == 2'b01);
    assign div_u_tvalid = ex_div_en && !div_busy && (ex_div_op[1:0] == 2'b10 || ex_div_op[1:0] == 2'b11);

    // 选择除法结果（div/mod 有符号或无符号）
    always @(*) begin
        case (ex_div_op[1:0])
            2'b00: div_result = div_s_result[31:0];  // div.w
            2'b01: div_result = div_s_result[63:32]; // mod.w
            2'b10: div_result = div_u_result[31:0];  // div.wu
            2'b11: div_result = div_u_result[63:32]; // mod.wu
            default: div_result = 32'b0;
        endcase
    end

    //======================================================================
    //  ALU / 除法结果选择
    //======================================================================
    wire [31:0] ex_final_result = ex_div_en ? div_result : alu_result;

    //======================================================================
    //  访存阶段信号
    //======================================================================
    assign data_sram_en    = 1'b1;
    assign data_sram_we    = {4{mem_we}};
    assign data_sram_addr  = alu_result;
    assign data_sram_wdata = rkd_value;

    //======================================================================
    //  EX→MEM 总线
    //======================================================================
    assign ex_mem_bus = {
        ex_gr_we, res_from_mem, ex_dest,
        ex_pc, ex_inst, ex_final_result
    };

    //======================================================================
    //  EX→ID 旁路 + busy 反馈
    //======================================================================
    wire ex_bypass = ex_valid & ex_gr_we;
    wire ex_ld     = ex_valid & res_from_mem;
    wire ex_div_busy = ex_valid & div_busy;

    assign ex_id_bus = {ex_bypass , ex_ld , ex_dest , ex_final_result , ex_div_busy};

endmodule
