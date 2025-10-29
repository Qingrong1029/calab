// ========================================
// LoongArch CSR 地址宏定义
// ========================================

// ========== 系统控制类 ==========
`define CSR_CRMD       14'h0000   // 当前模式寄存器
`define CSR_PRMD       14'h0001   // 先前模式寄存器
`define CSR_EUEN       14'h0002   // 扩展使能寄存器
`define CSR_ECFG       14'h0004   // 异常配置寄存器
`define CSR_ESTAT      14'h0005   // 异常状态寄存器
`define CSR_ERA        14'h0006   // 异常返回地址寄存器
`define CSR_BADV       14'h0007   // 异常虚拟地址寄存器
`define CSR_EENTRY     14'h000c   // 异常入口寄存器

// ========== 处理器标识类 ==========
`define CSR_CPUID      14'h0020   // CPU 标识寄存器

// ========== 计时类 ==========
`define CSR_TID        14'h0040   // 定时器 ID
`define CSR_TCFG       14'h0041   // 定时器配置寄存器
`define CSR_TVAL       14'h0042   // 定时器当前值
`define CSR_TICLR      14'h0044   // 定时器清除寄存器

// ========== 保存通用寄存器类（软件可用） ==========
`define CSR_SAVE0      14'h0030
`define CSR_SAVE1      14'h0031
`define CSR_SAVE2      14'h0032
`define CSR_SAVE3      14'h0033
`define CSR_SAVE4      14'h0034
`define CSR_SAVE5      14'h0035
`define CSR_SAVE6      14'h0036
`define CSR_SAVE7      14'h0037

// ========== 其他 ==========
`define CSR_TLBIDX     14'h0010
`define CSR_TLBEHI     14'h0011
`define CSR_TLBELO0    14'h0012
`define CSR_TLBELO1    14'h0013
`define CSR_ASID       14'h0018
`define CSR_PGDL       14'h0019
`define CSR_PGDH       14'h001a
`define CSR_PGD        14'h001b
`define CSR_PWCL       14'h001c
`define CSR_PWCH       14'h001d
`define CSR_STLBIDX    14'h001e
`define CSR_RVACFG     14'h001f

// ========== 常用宏 ==========
`define CSR_MASK       14'h3fff   // CSR 地址掩码

module csr_reg (
    input  wire        clk,
    input  wire        reset,

    // 指令访问接口
    input  wire        csr_re,
    input  wire [13:0] csr_num,
    output wire [31:0] csr_rvalue,
    input  wire        csr_we,
    input  wire [31:0] csr_wmask,
    input  wire [31:0] csr_wvalue,

    // 异常、返回
    input  wire        ertn_flush,
    input  wire        wb_ex,
    input  wire [31:0] wb_pc,
    input  wire [31:0] wb_vaddr,
    input  wire [5:0]  wb_ecode,
    input  wire [8:0]  wb_esubcode,
    output wire [31:0] ex_entry,

    // 中断信号
    input  wire [7:0]  hw_int_in,
    input  wire        ipi_int_in
);

    // ----------------------------------------
    // ====== CSR 各域定义 ======
    // ----------------------------------------

    // CRMD
    reg [1:0] csr_crmd_plv;
    reg       csr_crmd_ie;
    wire      csr_crmd_da, csr_crmd_pg;
    wire [1:0] csr_crmd_datf, csr_crmd_datm;

    // PRMD
    reg [1:0] csr_prmd_pplv;
    reg       csr_prmd_pie;

    // ECFG
    reg [12:0] csr_ecfg_lie;

    // ESTAT
    reg [11:0] csr_estat_is;
    reg [5:0]  csr_estat_ecode;
    reg [8:0]  csr_estat_esubcode;

    // ERA
    reg [31:0] csr_era_pc;

    // EENTRY
    reg [31:0] csr_eentry_va;

    // SAVE 寄存器
    reg [31:0] csr_save0, csr_save1, csr_save2, csr_save3;

    // BADV
    reg [31:0] csr_badv_vaddr;

    // ----------------------------------------
    // ====== 各域赋值逻辑 ======
    // ----------------------------------------

    // ---------- CRMD.PLV ----------
    always @(posedge clk) begin
        if (reset)
            csr_crmd_plv <= 2'b0;
        else if (wb_ex)
            csr_crmd_plv <= 2'b0;
        else if (ertn_flush)
            csr_crmd_plv <= csr_prmd_pplv;
        else if (csr_we && csr_num == `CSR_CRMD)
            csr_crmd_plv <= (csr_wmask[1:0] & csr_wvalue[1:0]) | (~csr_wmask[1:0] & csr_crmd_plv);
    end

    // ---------- CRMD.IE ----------
    always @(posedge clk) begin
        if (reset)
            csr_crmd_ie <= 1'b0;
        else if (wb_ex)
            csr_crmd_ie <= 1'b0;
        else if (ertn_flush)
            csr_crmd_ie <= csr_prmd_pie;
        else if (csr_we && csr_num == `CSR_CRMD)
            csr_crmd_ie <= (csr_wmask[2] & csr_wvalue[2]) | (~csr_wmask[2] & csr_crmd_ie);
    end

    // ---------- CRMD.DA/PG/DATF/DATM（固定值） ----------
    assign csr_crmd_da   = 1'b1;
    assign csr_crmd_pg   = 1'b0;
    assign csr_crmd_datf = 2'b00;
    assign csr_crmd_datm = 2'b00;

    // ---------- PRMD.PPLV, PIE ----------
    always @(posedge clk) begin
        if (wb_ex) begin
            csr_prmd_pplv <= csr_crmd_plv;
            csr_prmd_pie  <= csr_crmd_ie;
        end else if (csr_we && csr_num == `CSR_PRMD) begin
            csr_prmd_pplv <= (csr_wmask[1:0] & csr_wvalue[1:0]) | (~csr_wmask[1:0] & csr_prmd_pplv);
            csr_prmd_pie  <= (csr_wmask[2] & csr_wvalue[2]) | (~csr_wmask[2] & csr_prmd_pie);
        end
    end

    // ---------- ESTAT.IS ----------
    always @(posedge clk) begin
        if (reset)
            csr_estat_is[1:0] <= 2'b0;
        else if (csr_we && csr_num == `CSR_ESTAT)
            csr_estat_is[1:0] <= (csr_wmask[1:0] & csr_wvalue[1:0]) | (~csr_wmask[1:0] & csr_estat_is[1:0]);

        csr_estat_is[9:2] <= hw_int_in[7:0];  // 硬件中断输入
        csr_estat_is[10]  <= 1'b0;           // 保留
        csr_estat_is[12]  <= ipi_int_in;     // 核间中断输入
    end

    // ---------- ESTAT.ECODE & ESUBCODE ----------
    always @(posedge clk) begin
        if (wb_ex) begin
            csr_estat_ecode    <= wb_ecode;
            csr_estat_esubcode <= wb_esubcode;
        end
    end

    // ---------- ERA.PC ----------
    always @(posedge clk) begin
        if (wb_ex)
            csr_era_pc <= wb_pc;
        else if (csr_we && csr_num == `CSR_ERA)
            csr_era_pc <= (csr_wmask & csr_wvalue) | (~csr_wmask & csr_era_pc);
    end

    // ---------- EENTRY.VA ----------
    always @(posedge clk) begin
        if (csr_we && csr_num == `CSR_EENTRY)
            csr_eentry_va <= (csr_wmask & csr_wvalue) | (~csr_wmask & csr_eentry_va);
    end

    // ---------- SAVE0~3 ----------
    always @(posedge clk) begin
        if (csr_we && csr_num == `CSR_SAVE0)
            csr_save0 <= (csr_wmask & csr_wvalue) | (~csr_wmask & csr_save0);
        if (csr_we && csr_num == `CSR_SAVE1)
            csr_save1 <= (csr_wmask & csr_wvalue) | (~csr_wmask & csr_save1);
        if (csr_we && csr_num == `CSR_SAVE2)
            csr_save2 <= (csr_wmask & csr_wvalue) | (~csr_wmask & csr_save2);
        if (csr_we && csr_num == `CSR_SAVE3)
            csr_save3 <= (csr_wmask & csr_wvalue) | (~csr_wmask & csr_save3);
    end

    // ----------------------------------------
    // ====== 读出 ======
    // ----------------------------------------
    wire [31:0] csr_crmd_rvalue  = {23'b0, csr_crmd_datm, csr_crmd_datf, csr_crmd_pg,
                                    csr_crmd_da, csr_crmd_ie, csr_crmd_plv};
    wire [31:0] csr_prmd_rvalue  = {29'b0, csr_prmd_pie, csr_prmd_pplv};
    wire [31:0] csr_ecfg_rvalue  = {19'b0, csr_ecfg_lie};
    wire [31:0] csr_estat_rvalue = {csr_estat_ecode, csr_estat_esubcode, 4'b0, csr_estat_is};
    wire [31:0] csr_era_rvalue   = csr_era_pc;
    wire [31:0] csr_eentry_rvalue= csr_eentry_va;

    assign csr_rvalue = (csr_num==`CSR_CRMD)   ? csr_crmd_rvalue  :
                        (csr_num==`CSR_PRMD)   ? csr_prmd_rvalue  :
                        (csr_num==`CSR_ECFG)   ? csr_ecfg_rvalue  :
                        (csr_num==`CSR_ESTAT)  ? csr_estat_rvalue :
                        (csr_num==`CSR_ERA)    ? csr_era_rvalue   :
                        (csr_num==`CSR_EENTRY) ? csr_eentry_rvalue:
                        (csr_num==`CSR_SAVE0)  ? csr_save0 :
                        (csr_num==`CSR_SAVE1)  ? csr_save1 :
                        (csr_num==`CSR_SAVE2)  ? csr_save2 :
                        (csr_num==`CSR_SAVE3)  ? csr_save3 : 32'b0;

    assign ex_entry = csr_eentry_va;

endmodule
