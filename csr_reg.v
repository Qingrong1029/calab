`include "defines.vh"


module csr_reg (
    input  wire        clk,
    input  wire        resetn,

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
    input  wire [31:0] wb_csr_pc,
    input  wire [31:0] wb_vaddr,
    input  wire [5:0]  wb_ecode,
    input  wire [8:0]  wb_esubcode,
    output wire [31:0] ex_entry,
    
    input  wire [7:0]  hw_int_in,
    input              ipi_int_in
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

    // ----------------------------------------
    // ====== 各域赋值逻辑 ======
    // ----------------------------------------

    // ---------- CRMD.PLV ----------
    always @(posedge clk) begin
        if (~resetn)
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
        if (~resetn)
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
        if (~resetn)
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
            csr_era_pc <= wb_csr_pc;
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
