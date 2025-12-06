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
    output wire [31:0] ertn_entry,
    output wire [31:0] ex_entry,
    output wire        has_int,
    
    input  wire [7:0]  hw_int_in,
    input  wire        ipi_int_in,
    
    input  wire [31:0] coreid_in,

    //TLB 接口
    input  wire        tlbsrch_we,
    input  wire        tlbsrch_hit,
    input  wire        tlbrd_we,
    input  wire [ 3:0] tlbsrch_hit_index,
    
    input  wire        r_tlb_e,
    input  wire [ 5:0] r_tlb_ps,
    input  wire [18:0] r_tlb_vppn,
    input  wire [ 9:0] r_tlb_asid,
    input  wire        r_tlb_g,
    input  wire [19:0] r_tlb_ppn0,
    input  wire [ 1:0] r_tlb_plv0,
    input  wire [ 1:0] r_tlb_mat0,
    input  wire        r_tlb_d0,
    input  wire        r_tlb_v0,
    input  wire [19:0] r_tlb_ppn1,
    input  wire [ 1:0] r_tlb_plv1,
    input  wire [ 1:0] r_tlb_mat1,
    input  wire        r_tlb_d1,
    input  wire        r_tlb_v1,

    // IF stage exception signals
    input  wire        if_fetch_plv_ex,
    input  wire        if_fetch_tlb_refill,
    
    // TLBIDX outputs
    output wire [ 3:0] tlbidx_index,
    output wire [ 5:0] tlbidx_ps,
    output wire        tlbidx_ne,
    
    // TLBEHI output
    output wire [18:0] tlbehi_vppn,
    
    // TLBELO0 outputs
    output wire        tlbelo0_v,
    output wire        tlbelo0_d,
    output wire [ 1:0] tlbelo0_plv,
    output wire [ 1:0] tlbelo0_mat,
    output wire        tlbelo0_g,
    output wire [19:0] tlbelo0_ppn,
    
    // TLBELO1 outputs
    output wire        tlbelo1_v,
    output wire        tlbelo1_d,
    output wire [ 1:0] tlbelo1_plv,
    output wire [ 1:0] tlbelo1_mat,
    output wire        tlbelo1_g,
    output wire [19:0] tlbelo1_ppn,
    
    // ASID output
    output wire [ 9:0] tlbasid_asid,

    //dwm outputs
    output wire        DMW0_PLV0,
    output wire        DMW0_PLV3,
    output wire [ 1:0] DMW0_MAT,
    output wire [ 2:0] DMW0_PSEG,
    output wire [ 2:0] DMW0_VSEG,

    output wire        DMW1_PLV0,
    output wire        DMW1_PLV3,
    output wire [ 1:0] DMW1_MAT,
    output wire [ 2:0] DMW1_PSEG,
    output wire [ 2:0] DMW1_VSEG,
    
    output wire       crmd_da,
    output wire       crmd_pg,
    output wire [1:0] plv,
    output wire [1:0] datf,

    // TLB reflush
    input  wire        tlb_reflush,
    input  wire [31:0] tlb_reflush_pc,
    
    // TLB refill exception
    input  wire        out_ex_tlb_refill,
    
    // ESTAT ecode output
    output wire [ 5:0] stat_ecode,
    
    // WB crush with tlbsrch
    input  wire        if_wb_crush_tlbsrch
    
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

    // SAVE 寄存�?
    reg [31:0] csr_save0, csr_save1, csr_save2, csr_save3;
    
    // BADV (虚地�?)
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

    // TLBIDX
    reg  [ 5:0] csr_tlbidx_ps;
    reg         csr_tlbidx_ne;
    reg  [ 3:0] csr_tlbidx_index;
    // TLELO0
    reg         csr_tlbelo0_v;
    reg         csr_tlbelo0_d;
    reg  [ 1:0] csr_tlbelo0_plv;
    reg  [ 1:0] csr_tlbelo0_mat;
    reg         csr_tlbelo0_g;
    reg  [23:0] csr_tlbelo0_ppn;

    // TLELO1
    reg         csr_tlbelo1_v;
    reg         csr_tlbelo1_d;
    reg  [ 1:0] csr_tlbelo1_plv;
    reg  [ 1:0] csr_tlbelo1_mat;
    reg         csr_tlbelo1_g;
    reg  [23:0] csr_tlbelo1_ppn;

    // TLBEHI
    reg  [18:0] csr_tlbehi_vppn;
    
    // ASID
    wire [ 7:0] csr_asid_asidbits;
    reg  [ 9:0] csr_asid_asid;

    // TLBRENTRY
    reg  [25:0] csr_tlbrentry_pa;

    // ----------------------------------------
    // ====== 各域赋�?��?�辑 ======
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

    // ---------- CRMD.DA/PG/DATF/DATM（固定�?�） ----------
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
    

    // ---------- TLBIDX----------
    always @ (posedge clk) begin
        if (~resetn) begin
            csr_tlbidx_index <= 4'b0;
            csr_tlbidx_ps    <= 6'b0;
            csr_tlbidx_ne    <= 1'b1;
        end else if (tlbrd_we) begin
            if (r_tlb_e)
                csr_tlbidx_ps <= r_tlb_ps;
            else
                csr_tlbidx_ps <= 6'b0;
                csr_tlbidx_ne <= ~r_tlb_e;
        end else if (tlbsrch_we) begin
            csr_tlbidx_index <= tlbsrch_hit ? tlbsrch_hit_index : csr_tlbidx_index;
            csr_tlbidx_ne <= ~tlbsrch_hit;
        end else if (csr_we && csr_num == `CSR_TLBIDX) begin
            csr_tlbidx_index <= csr_wmask[`CSR_TLBIDX_INDEX] & csr_wvalue[`CSR_TLBIDX_INDEX] |
                               ~csr_wmask[`CSR_TLBIDX_INDEX] & csr_tlbidx_index;
            csr_tlbidx_ps <= csr_wmask[`CSR_TLBIDX_PS] & csr_wvalue[`CSR_TLBIDX_PS] |
                            ~csr_wmask[`CSR_TLBIDX_PS] & csr_tlbidx_ps;
            csr_tlbidx_ne <= csr_wmask[`CSR_TLBIDX_NE] & csr_wvalue[`CSR_TLBIDX_NE] |
                            ~csr_wmask[`CSR_TLBIDX_NE] & csr_tlbidx_ne;
        end
    end

    // ---------- TLBEHI----------
    always @ (posedge clk) begin
        if (~resetn) begin
            csr_tlbehi_vppn <= 19'b0;
        end else if (tlbrd_we) begin
            csr_tlbehi_vppn <= r_tlb_e ? {19{r_tlb_e}} & r_tlb_vppn : 19'b0;
        end else if (csr_we && csr_num == `CSR_TLBEHI) begin
            csr_tlbehi_vppn <= csr_wmask[`CSR_TLBEHI_VPPN] & csr_wvalue[`CSR_TLBEHI_VPPN] |
                            ~csr_wmask[`CSR_TLBEHI_VPPN] & csr_tlbehi_vppn;
        end
    end

    // ---------- TLB ELO0 & TLB ELO1----------
    always @ (posedge clk) begin
        if (~resetn | tlbrd_we & ~r_tlb_e) begin
            csr_tlbelo0_v   <= 1'b0;
            csr_tlbelo0_d   <= 1'b0;
            csr_tlbelo0_plv <= 2'b0;
            csr_tlbelo0_mat <= 2'b0;
            csr_tlbelo0_g   <= 1'b0;
            csr_tlbelo0_ppn <= 24'b0;

            csr_tlbelo1_v   <= 1'b0;
            csr_tlbelo1_d   <= 1'b0;
            csr_tlbelo1_plv <= 2'b0;
            csr_tlbelo1_mat <= 2'b0;
            csr_tlbelo1_g   <= 1'b0;
            csr_tlbelo1_ppn <= 24'b0;
        end else if (tlbrd_we && r_tlb_e) begin
            csr_tlbelo0_v   <= r_tlb_v0;
            csr_tlbelo0_d   <= r_tlb_d0;
            csr_tlbelo0_plv <= r_tlb_plv0;
            csr_tlbelo0_mat <= r_tlb_mat0;
            csr_tlbelo0_g   <= r_tlb_g;
            csr_tlbelo0_ppn <= {4'b0, r_tlb_ppn0};

            csr_tlbelo1_v   <= r_tlb_v1;
            csr_tlbelo1_d   <= r_tlb_d1;
            csr_tlbelo1_plv <= r_tlb_plv1;
            csr_tlbelo1_mat <= r_tlb_mat1;
            csr_tlbelo1_g   <= r_tlb_g;
            csr_tlbelo1_ppn <= {4'b0, r_tlb_ppn1};
        end else if (csr_we && csr_num == `CSR_TLBELO0) begin
            csr_tlbelo0_v   <= csr_wmask[`CSR_TLBELO_V]   & csr_wvalue[`CSR_TLBELO_V]   |
                              ~csr_wmask[`CSR_TLBELO_V]   & csr_tlbelo0_v;
            csr_tlbelo0_d   <= csr_wmask[`CSR_TLBELO_D]   & csr_wvalue[`CSR_TLBELO_D]   |
                              ~csr_wmask[`CSR_TLBELO_D]   & csr_tlbelo0_d;
            csr_tlbelo0_plv <= csr_wmask[`CSR_TLBELO_PLV] & csr_wvalue[`CSR_TLBELO_PLV] |
                              ~csr_wmask[`CSR_TLBELO_PLV] & csr_tlbelo0_plv;
            csr_tlbelo0_mat <= csr_wmask[`CSR_TLBELO_MAT] & csr_wvalue[`CSR_TLBELO_MAT] |
                              ~csr_wmask[`CSR_TLBELO_MAT] & csr_tlbelo0_mat;
            csr_tlbelo0_g   <= csr_wmask[`CSR_TLBELO_G]   & csr_wvalue[`CSR_TLBELO_G]   |
                              ~csr_wmask[`CSR_TLBELO_G]   & csr_tlbelo0_g;
            csr_tlbelo0_ppn <= csr_wmask[`CSR_TLBELO_PPN] & csr_wvalue[`CSR_TLBELO_PPN] |
                              ~csr_wmask[`CSR_TLBELO_PPN] & csr_tlbelo0_ppn;
        end else if (csr_we && csr_num == `CSR_TLBELO1) begin
            csr_tlbelo1_v   <= csr_wmask[`CSR_TLBELO_V]   & csr_wvalue[`CSR_TLBELO_V]   |
                              ~csr_wmask[`CSR_TLBELO_V]   & csr_tlbelo1_v;
            csr_tlbelo1_d   <= csr_wmask[`CSR_TLBELO_D]   & csr_wvalue[`CSR_TLBELO_D]   |
                              ~csr_wmask[`CSR_TLBELO_D]   & csr_tlbelo1_d;
            csr_tlbelo1_plv <= csr_wmask[`CSR_TLBELO_PLV] & csr_wvalue[`CSR_TLBELO_PLV] |
                              ~csr_wmask[`CSR_TLBELO_PLV] & csr_tlbelo1_plv;
            csr_tlbelo1_mat <= csr_wmask[`CSR_TLBELO_MAT] & csr_wvalue[`CSR_TLBELO_MAT] |
                              ~csr_wmask[`CSR_TLBELO_MAT] & csr_tlbelo1_mat;
            csr_tlbelo1_g   <= csr_wmask[`CSR_TLBELO_G]   & csr_wvalue[`CSR_TLBELO_G]   |
                              ~csr_wmask[`CSR_TLBELO_G]   & csr_tlbelo1_g;
            csr_tlbelo1_ppn <= csr_wmask[`CSR_TLBELO_PPN] & csr_wvalue[`CSR_TLBELO_PPN] |
                              ~csr_wmask[`CSR_TLBELO_PPN] & csr_tlbelo1_ppn;
        end
    end

    // ---------- ASID ----------
    assign csr_asid_asidbits = 8'd10;

    always @ (posedge clk) begin
        if (~resetn | tlbrd_we & ~r_tlb_e) begin
            csr_asid_asid <= 10'b0;
        end else if (tlbrd_we && r_tlb_e) begin
            csr_asid_asid <= r_tlb_asid;
        end else if (csr_we && csr_num == `CSR_ASID) begin
            csr_asid_asid <= csr_wmask[`CSR_ASID_ASID] & csr_wvalue[`CSR_ASID_ASID] |
                            ~csr_wmask[`CSR_ASID_ASID] & csr_asid_asid;
        end
    end

    // ---------- DMW0 ----------
    reg        csr_dmw0_plv0;
    reg        csr_dmw0_plv3;
    reg [1:0]  csr_dmw0_mat;
    reg [2:0]  csr_dmw0_pseg;
    reg [2:0]  csr_dmw0_vseg;
    always @(posedge clk ) begin
        if(~resetn) begin
            csr_dmw0_plv0 <= 1'b0;
            csr_dmw0_plv3 <= 1'b0;
            csr_dmw0_mat  <= 2'b0;
            csr_dmw0_pseg <= 3'b0;
            csr_dmw0_vseg <= 3'b0;
        end
        else if(csr_we && csr_num == `CSR_DMW0)begin
            csr_dmw0_plv0  <= csr_wmask[`CSR_DMW_PLV0] & csr_wvalue[`CSR_DMW_PLV0]
                        | ~csr_wmask[`CSR_DMW_PLV0] & csr_dmw0_plv0; 
            csr_dmw0_plv3  <= csr_wmask[`CSR_DMW_PLV3] & csr_wvalue[`CSR_DMW_PLV3]
                        | ~csr_wmask[`CSR_DMW_PLV3] & csr_dmw0_plv3; 
            csr_dmw0_mat   <= csr_wmask[`CSR_DMW_MAT] & csr_wvalue[`CSR_DMW_MAT]
                        | ~csr_wmask[`CSR_DMW_MAT] & csr_dmw0_mat; 
            csr_dmw0_pseg  <= csr_wmask[`CSR_DMW_PSEG] & csr_wvalue[`CSR_DMW_PSEG]
                        | ~csr_wmask[`CSR_DMW_PSEG] & csr_dmw0_pseg;
            csr_dmw0_vseg  <= csr_wmask[`CSR_DMW_VSEG] & csr_wvalue[`CSR_DMW_VSEG]
                        | ~csr_wmask[`CSR_DMW_VSEG] & csr_dmw0_vseg;   
        end
    end

    // ---------- DMW1 ----------
    reg        csr_dmw1_plv0;
    reg        csr_dmw1_plv3;   
    reg [1:0]  csr_dmw1_mat;
    reg [2:0]  csr_dmw1_pseg;
    reg [2:0]  csr_dmw1_vseg;
    always @(posedge clk ) begin
        if(~resetn) begin
            csr_dmw1_plv0 <= 1'b0;
            csr_dmw1_plv3 <= 1'b0;
            csr_dmw1_mat  <= 2'b0;
            csr_dmw1_pseg <= 3'b0;
            csr_dmw1_vseg <= 3'b0;
        end
        else if(csr_we && csr_num == `CSR_DMW1)begin
            csr_dmw1_plv0  <= csr_wmask[`CSR_DMW_PLV0] & csr_wvalue[`CSR_DMW_PLV0]
                        | ~csr_wmask[`CSR_DMW_PLV0] & csr_dmw1_plv0; 
            csr_dmw1_plv3  <= csr_wmask[`CSR_DMW_PLV3] & csr_wvalue[`CSR_DMW_PLV3]
                        | ~csr_wmask[`CSR_DMW_PLV3] & csr_dmw1_plv3; 
            csr_dmw1_mat   <= csr_wmask[`CSR_DMW_MAT] & csr_wvalue[`CSR_DMW_MAT]
                        | ~csr_wmask[`CSR_DMW_MAT] & csr_dmw1_mat; 
            csr_dmw1_pseg  <= csr_wmask[`CSR_DMW_PSEG] & csr_wvalue[`CSR_DMW_PSEG]
                        | ~csr_wmask[`CSR_DMW_PSEG] & csr_dmw1_pseg;
            csr_dmw1_vseg  <= csr_wmask[`CSR_DMW_VSEG] & csr_wvalue[`CSR_DMW_VSEG]
                        | ~csr_wmask[`CSR_DMW_VSEG] & csr_dmw1_vseg;   
        end
    end

    // ---------- TLBRENTRY ----------
    always @ (posedge clk) begin
        if (~resetn) begin
            csr_tlbrentry_pa <= 26'b0;
        end else if (csr_we && csr_num == `CSR_TLBRENTRY) begin
            csr_tlbrentry_pa <= csr_wmask[`CSR_TLBRENTRY_PA] & csr_wvalue[`CSR_TLBRENTRY_PA] |
                               ~csr_wmask[`CSR_TLBRENTRY_PA] & csr_tlbrentry_pa;
        end
    end

    // ----------------------------------------
    // ====== 读出 ======
    // ----------------------------------------
    wire [31:0] csr_crmd_rvalue     = {23'b0, csr_crmd_datm, csr_crmd_datf, csr_crmd_pg, csr_crmd_da, csr_crmd_ie, csr_crmd_plv};
    wire [31:0] csr_prmd_rvalue     = {29'b0, csr_prmd_pie, csr_prmd_pplv};
    wire [31:0] csr_ecfg_rvalue     = {19'b0, csr_ecfg_lie};
    wire [31:0] csr_estat_rvalue    = {1'b0, csr_estat_esubcode, csr_estat_ecode, 3'b0, csr_estat_is};
    wire [31:0] csr_era_rvalue      = csr_era_pc;
    wire [31:0] csr_badv_rvalue     = csr_badv_vaddr;
    wire [31:0] csr_eentry_rvalue   = {csr_eentry_va, 6'b0};
    wire [31:0] csr_tid_rvalue      = csr_tid_tid;
    wire [31:0] csr_tcfg_rvalue     = {csr_tcfg_initval,csr_tcfg_periodic, csr_tcfg_en};
    wire [31:0] csr_tval_rvalue     = csr_tval;
    wire [31:0] csr_tlbidx_rvalue   = {csr_tlbidx_ne, 1'b0, csr_tlbidx_ps, 20'b0, csr_tlbidx_index};
    wire [31:0] csr_tlbehi_rvalue   = {csr_tlbehi_vppn, 13'b0};
    wire [31:0] csr_tlbelo0_rvalue  = {csr_tlbelo0_ppn, 1'b0, csr_tlbelo0_g, csr_tlbelo0_mat, csr_tlbelo0_plv, csr_tlbelo0_d, csr_tlbelo0_v};
    wire [31:0] csr_tlbelo1_rvalue  = {csr_tlbelo1_ppn, 1'b0, csr_tlbelo1_g, csr_tlbelo1_mat, csr_tlbelo1_plv, csr_tlbelo1_d, csr_tlbelo1_v};
    wire [31:0] csr_asid_rvalue     = {8'b0, csr_asid_asidbits, 6'b0, csr_asid_asid};
    wire [31:0] csr_tlbrentry_rvalue= {csr_tlbrentry_pa, 6'b0};
    wire [31:0] csr_dmw0_rvalue     = {csr_dmw0_vseg, 1'b0, csr_dmw0_pseg, 19'b0, csr_dmw0_mat, csr_dmw0_plv3, 2'b0, csr_dmw0_plv0};
    wire [31:0] csr_dmw1_rvalue     = {csr_dmw1_vseg, 1'b0, csr_dmw1_pseg, 19'b0, csr_dmw1_mat, csr_dmw1_plv3, 2'b0, csr_dmw1_plv0};
    

    assign csr_rvalue = (csr_num==`CSR_CRMD)     ? csr_crmd_rvalue  :
                        (csr_num==`CSR_PRMD)     ? csr_prmd_rvalue  :
                        (csr_num==`CSR_ECFG)     ? csr_ecfg_rvalue  :
                        (csr_num==`CSR_ESTAT)    ? csr_estat_rvalue :
                        (csr_num==`CSR_ERA)      ? csr_era_rvalue   :
                        (csr_num==`CSR_BADV)     ? csr_badv_rvalue  :
                        (csr_num==`CSR_EENTRY)   ? csr_eentry_rvalue:
                        (csr_num==`CSR_SAVE0)    ? csr_save0 :
                        (csr_num==`CSR_SAVE1)    ? csr_save1 :
                        (csr_num==`CSR_SAVE2)    ? csr_save2 :
                        (csr_num==`CSR_SAVE3)    ? csr_save3 :
                        (csr_num==`CSR_TID)      ? csr_tid_rvalue       :
                        (csr_num==`CSR_TCFG)     ? csr_tcfg_rvalue      :
                        (csr_num==`CSR_TVAL)     ? csr_tval_rvalue      : 
                        (csr_num==`CSR_TLBIDX)   ? csr_tlbidx_rvalue    :
                        (csr_num==`CSR_TLBEHI)   ? csr_tlbehi_rvalue    :
                        (csr_num==`CSR_TLBELO0)  ? csr_tlbelo0_rvalue   :
                        (csr_num==`CSR_TLBELO1)  ? csr_tlbelo1_rvalue   :
                        (csr_num==`CSR_ASID)     ? csr_asid_rvalue      :
                        (csr_num==`CSR_TLBRENTRY)? csr_tlbrentry_rvalue : 
                        (csr_num==`CSR_DMW0)     ? csr_dmw0_rvalue      :
                        (csr_num==`CSR_DMW1)     ? csr_dmw1_rvalue      :
                        32'b0;

    // ----------------------------------------
    // ====== 其他输出信号 ======
    assign ex_entry = {csr_eentry_va, 6'b0};
    assign ertn_entry = csr_era_pc;
    
    wire int_pending = |(csr_estat_is[11:0] & csr_ecfg_lie[11:0]);
    assign has_int = csr_crmd_ie && int_pending;

    // ====== mycpu_sram expected outputs ======
    // TLBIDX outputs
    assign tlbidx_index = csr_tlbidx_index;
    assign tlbidx_ps    = csr_tlbidx_ps;
    assign tlbidx_ne    = csr_tlbidx_ne;
    
    // TLBEHI output
    assign tlbehi_vppn  = csr_tlbehi_vppn;
    
    // TLBELO0 outputs
    assign tlbelo0_v    = csr_tlbelo0_v;
    assign tlbelo0_d    = csr_tlbelo0_d;
    assign tlbelo0_plv  = csr_tlbelo0_plv;
    assign tlbelo0_mat  = csr_tlbelo0_mat;
    assign tlbelo0_g    = csr_tlbelo0_g;
    assign tlbelo0_ppn  = csr_tlbelo0_ppn[19:0];
    
    // TLBELO1 outputs
    assign tlbelo1_v    = csr_tlbelo1_v;
    assign tlbelo1_d    = csr_tlbelo1_d;
    assign tlbelo1_plv  = csr_tlbelo1_plv;
    assign tlbelo1_mat  = csr_tlbelo1_mat;
    assign tlbelo1_g    = csr_tlbelo1_g;
    assign tlbelo1_ppn  = csr_tlbelo1_ppn[19:0];
    
    // ASID output
    assign tlbasid_asid = csr_asid_asid;
    
    // ESTAT ecode output
    assign stat_ecode   = csr_estat_ecode;

    // DMW0 outputs
    assign DMW0_PLV0 = csr_dmw0_plv0;
    assign DMW0_PLV3 = csr_dmw0_plv3;
    assign DMW0_MAT  = csr_dmw0_mat;
    assign DMW0_PSEG = csr_dmw0_pseg;
    assign DMW0_VSEG = csr_dmw0_vseg;

    // DMW1 outputs
    assign DMW1_PLV0 = csr_dmw1_plv0;
    assign DMW1_PLV3 = csr_dmw1_plv3;
    assign DMW1_MAT  = csr_dmw1_mat;
    assign DMW1_PSEG = csr_dmw1_pseg;
    assign DMW1_VSEG = csr_dmw1_vseg;

    assign crmd_da = csr_crmd_da;
    assign crmd_pg = csr_crmd_pg;
    assign plv     = csr_crmd_plv;
    assign datf    = csr_crmd_datf;
endmodule
