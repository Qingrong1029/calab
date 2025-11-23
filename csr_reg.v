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
    output  wire [31:0] ertn_entry,
    output wire [31:0] ex_entry,
    output wire        has_int,
    
    input  wire [7:0]  hw_int_in,
    input              ipi_int_in,
    
    input  wire [31:0] coreid_in
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
    reg [12:0] csr_estat_is;
    reg [5:0]  csr_estat_ecode;
    reg [8:0]  csr_estat_esubcode;

    // ERA
    reg [31:0] csr_era_pc;

    // EENTRY
    reg [25:0] csr_eentry_va;

    // SAVE 寄存器
    reg [31:0] csr_save0, csr_save1, csr_save2, csr_save3;
    
    // BADV (虚地址)
    reg [31:0] csr_badv_vaddr;
    
    // TID
    reg [31:0] csr_tid_tid;
    
    // TCFG (timer config fields)
    reg        csr_tcfg_en;
    reg        csr_tcfg_periodic;
    reg [29:0] csr_tcfg_initval;

    // TVAL / timer counter
    reg  [31:0] timer_cnt;
    wire [31:0] csr_tval;
    wire [31:0] tcfg_next_value;

    // TICLR CLR is W1 (reads as 0)
    wire csr_ticlr_clr;
    assign csr_ticlr_clr = 1'b0;

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

    // ---------- ECFG.LIE ----------
    always @(posedge clk) begin
        if (~resetn)
            csr_ecfg_lie <= 13'b0;
        else if (csr_we && csr_num==`CSR_ECFG)
            csr_ecfg_lie <= csr_wmask[`CSR_ECFG_LIE]&13'h1bff&csr_wvalue[`CSR_ECFG_LIE]| ~csr_wmask[`CSR_ECFG_LIE]&13'h1bff&csr_ecfg_lie;
    end

    // ---------- ESTAT.IS ----------

    always @(posedge clk) begin
        if (~resetn) begin
            csr_estat_is[1:0] <= 2'b0;
        end
        else if (csr_we && csr_num==`CSR_ESTAT) begin
            csr_estat_is[1:0] <= csr_wmask[`CSR_ESTAT_IS10] & csr_wvalue[`CSR_ESTAT_IS10] | ~csr_wmask[`CSR_ESTAT_IS10] & csr_estat_is[1:0];
        end   

        csr_estat_is[9:2] <= hw_int_in[7:0];
        csr_estat_is[10]  <= 1'b0;
        
        if (timer_cnt[31:0]==32'b0)
            csr_estat_is[11] <= 1'b1;
        else if (csr_we && csr_num==`CSR_TICLR && csr_wmask[`CSR_TICLR_CLR]&& csr_wvalue[`CSR_TICLR_CLR])
            csr_estat_is[11] <= 1'b0;
        
        csr_estat_is[12] <= ipi_int_in;   
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
    
    // ---------- BADV.VAddr ----------
    wire wb_ex_addr_err = (wb_ecode == `ECODE_ADE) || (wb_ecode == `ECODE_ALE);
    always @(posedge clk) begin
        if (wb_ex && wb_ex_addr_err) begin
            csr_badv_vaddr <= ((wb_ecode==`ECODE_ADE) && (wb_esubcode==`ESUB_ADE)) ? wb_csr_pc : wb_vaddr;
        end
    end

    // ---------- EENTRY.VA ----------
    always @(posedge clk) begin
    if (csr_we && csr_num==`CSR_EENTRY)
        csr_eentry_va <= csr_wmask[`CSR_EENTRY_VA]&csr_wvalue[`CSR_EENTRY_VA]
                       | ~csr_wmask[`CSR_EENTRY_VA]&csr_eentry_va;
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
    
    // ---------- TID ----------
    always @(posedge clk) begin
        if (~resetn)
            csr_tid_tid <= coreid_in;
        else if (csr_we && csr_num==`CSR_TID)
            csr_tid_tid <= csr_wmask[`CSR_TID_TID]&csr_wvalue[`CSR_TID_TID]| ~csr_wmask[`CSR_TID_TID]&csr_tid_tid;
    end
    
    // ---------- TCFG.En Periodic InitVal----------
    always @(posedge clk) begin
        if (~resetn)
            csr_tcfg_en <= 1'b0;
        else if (csr_we && csr_num==`CSR_TCFG)
            csr_tcfg_en <= csr_wmask[`CSR_TCFG_EN]&csr_wvalue[`CSR_TCFG_EN]| ~csr_wmask[`CSR_TCFG_EN]&csr_tcfg_en;
        
        if (csr_we && csr_num==`CSR_TCFG) begin
            csr_tcfg_periodic <= csr_wmask[`CSR_TCFG_PERIOD]&csr_wvalue[`CSR_TCFG_PERIOD]
                              | ~csr_wmask[`CSR_TCFG_PERIOD]&csr_tcfg_periodic;
            csr_tcfg_initval <= csr_wmask[`CSR_TCFG_INITV]&csr_wvalue[`CSR_TCFG_INITV]| ~csr_wmask[`CSR_TCFG_INITV]&csr_tcfg_initval;
        end
    end
    
    // ---------- TVAL.TimeVal----------
    assign tcfg_next_value = csr_wmask[31:0]&csr_wvalue[31:0]
                          | ~csr_wmask[31:0]&{csr_tcfg_initval,
                                              csr_tcfg_periodic, csr_tcfg_en};
    always @(posedge clk) begin
        if (~resetn)
            timer_cnt <= 32'hffffffff;
        else if (csr_we && csr_num==`CSR_TCFG && tcfg_next_value[`CSR_TCFG_EN])
            timer_cnt <= {tcfg_next_value[`CSR_TCFG_INITV], 2'b0};
        else if (csr_tcfg_en && timer_cnt!=32'hffffffff) begin
            if (timer_cnt[31:0]==32'b0 && csr_tcfg_periodic)
                timer_cnt <= {csr_tcfg_initval, 2'b0};
            else
                timer_cnt <= timer_cnt - 1'b1;
        end
    end
    
    assign csr_tval = timer_cnt[31:0];
    
    // ---------- TICLR.CLR----------
    assign csr_ticlr_clr = 1'b0;
    
    // ----------------------------------------
    // ====== 读出 ======
    // ----------------------------------------
    wire [31:0] csr_crmd_rvalue  = {23'b0, csr_crmd_datm, csr_crmd_datf, csr_crmd_pg,
                                    csr_crmd_da, csr_crmd_ie, csr_crmd_plv};
    wire [31:0] csr_prmd_rvalue  = {29'b0, csr_prmd_pie, csr_prmd_pplv};
    wire [31:0] csr_ecfg_rvalue  = {19'b0, csr_ecfg_lie};
    wire [31:0] csr_estat_rvalue = {1'b0, csr_estat_esubcode, csr_estat_ecode, 3'b0, csr_estat_is};
    wire [31:0] csr_era_rvalue   = csr_era_pc;
    wire [31:0] csr_badv_rvalue  = csr_badv_vaddr;
    wire [31:0] csr_eentry_rvalue= {csr_eentry_va, 6'b0};
    wire [31:0] csr_tid_rvalue   = csr_tid_tid;
    wire [31:0] csr_tcfg_rvalue  = {csr_tcfg_initval,csr_tcfg_periodic, csr_tcfg_en};
    wire [31:0] csr_tval_rvalue  = csr_tval;

    assign csr_rvalue = (csr_num==`CSR_CRMD)   ? csr_crmd_rvalue  :
                        (csr_num==`CSR_PRMD)   ? csr_prmd_rvalue  :
                        (csr_num==`CSR_ECFG)   ? csr_ecfg_rvalue  :
                        (csr_num==`CSR_ESTAT)  ? csr_estat_rvalue :
                        (csr_num==`CSR_ERA)    ? csr_era_rvalue   :
                        (csr_num==`CSR_BADV)   ? csr_badv_rvalue  :
                        (csr_num==`CSR_EENTRY) ? csr_eentry_rvalue:
                        (csr_num==`CSR_SAVE0)  ? csr_save0 :
                        (csr_num==`CSR_SAVE1)  ? csr_save1 :
                        (csr_num==`CSR_SAVE2)  ? csr_save2 :
                        (csr_num==`CSR_SAVE3)  ? csr_save3 :
                        (csr_num==`CSR_TID)    ? csr_tid_rvalue   :
                        (csr_num==`CSR_TCFG)   ? csr_tcfg_rvalue  :
                        (csr_num==`CSR_TVAL)   ? csr_tval_rvalue  : 32'b0;

    assign ex_entry = {csr_eentry_va, 6'b0};
    assign ertn_entry = csr_era_pc;
    
    wire int_pending = |(csr_estat_is[11:0] & csr_ecfg_lie[11:0]);
    assign has_int = csr_crmd_ie && int_pending;


endmodule
