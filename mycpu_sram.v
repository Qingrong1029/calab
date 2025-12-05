module mycpu_sram(
    input  wire        clk,
    input  wire        resetn,
    // inst sram interface
    output wire         inst_sram_req,
    output wire         inst_sram_wr,
    output wire [ 1:0]  inst_sram_size,
    output wire [ 3:0]  inst_sram_wstrb,
    output wire [31:0]  inst_sram_addr,
    output wire [31:0]  inst_sram_wdata,
    input  wire         inst_sram_addr_ok,
    input  wire         inst_sram_data_ok,
    input  wire [31:0]  inst_sram_rdata,
    // data sram interface
    output wire         data_sram_req,
    output wire         data_sram_wr,
    output wire [ 1:0]  data_sram_size,
    output wire [ 3:0]  data_sram_wstrb,
    output wire [31:0]  data_sram_addr,
    output wire [31:0]  data_sram_wdata,
    input  wire         data_sram_addr_ok,
    input  wire         data_sram_data_ok,
    input  wire [31:0]  data_sram_rdata,
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);
    wire            id_allowin;
    wire            if_id_valid;
    wire    [ 96:0] if_id_bus;
    wire    [ 33:0] id_if_bus;
    wire            ex_allowin;
    wire            id_ex_valid;
    wire    [374:0] id_ex_bus;
    wire    [ 38:0] wb_id_bus;
    wire    [249:0] ex_mem_bus;
    wire            ex_mem_valid;
    wire            mem_allowin;
    wire            mem_wb_valid;
    wire    [241:0] mem_wb_bus;
    wire            wb_allowin;
    wire    [ 54:0] mem_id_bus;
    wire    [ 55:0] ex_id_bus;
    
    wire    [13:0]  csr_num;
    wire            csr_re;
    wire    [31:0]  csr_rvalue;
    wire    [31:0]  ertn_pc;
    wire    [31:0]  ex_entry;
    wire            csr_we;
    wire    [31:0]  csr_wvalue;
    wire    [31:0]  csr_wmask;
    wire            wb_ex;
    wire    [31:0]  wb_csr_pc; 
    wire            ertn_flush;
    wire    [31:0]  ertn_entry;
    wire    [5:0]   wb_ecode;
    wire    [8:0]   wb_esubcode;
    wire    [31:0]  wb_wrong_addr;
    wire    [31:0]  wb_vaddr;
    wire    [31:0]  coreid_in   = 32'b0;
    wire            has_int;
    wire    [7:0]   hw_int_in   = 8'b0;
    wire            ipi_int_in  = 1'b0;
    wire            mem_ex;
    wire            mem_ertn;
    wire            id_has_int;
    wire            reg_ex;

    // CSR exposed control
    wire            crmd_da;
    wire            crmd_pg;
    wire    [1:0]   crmd_plv;
    wire    [1:0]   crmd_datm;
    wire    [1:0]   crmd_datf;
    wire    [5:0]   estat_ecode;

    // CSR to TLB data path
    wire            w_tlb_e;
    wire    [5:0]   w_tlb_ps;
    wire    [5:0]   tlbidx_ps;
    wire    [18:0]  w_tlb_vppn;
    wire    [9:0]   w_tlb_asid;
    wire            w_tlb_g;
    wire    [19:0]  w_tlb_ppn0;
    wire    [1:0]   w_tlb_plv0;
    wire    [1:0]   w_tlb_mat0;
    wire            w_tlb_d0;
    wire            w_tlb_v0;
    wire    [19:0]  w_tlb_ppn1;
    wire    [1:0]   w_tlb_plv1;
    wire    [1:0]   w_tlb_mat1;
    wire            w_tlb_d1;
    wire            w_tlb_v1;
    wire    [3:0]   tlbidx_index;
    wire            tlbidx_ne;

    // EX <-> TLB search port 1 wires
    wire    [18:0]  s1_vppn;
    wire            s1_va_bit12;
    wire    [9:0]   s1_asid;
    wire            s1_found;
    wire    [3:0]   s1_index;
    wire    [19:0]  s1_ppn;
    wire    [5:0]   s1_ps;
    wire    [1:0]   s1_plv;
    wire    [1:0]   s1_mat;
    wire            s1_d;
    wire            s1_v;
    wire            invtlb_valid;
    wire    [4:0]   invtlb_op;

    // WB <-> TLB interface
    wire            inst_tlbsrch;
    wire            tlbsrch_got;
    wire    [3:0]   tlbsrch_index;
    wire            inst_tlbrd;
    wire            tlbrd_valid;
    wire            tlb_we;
    wire    [3:0]   tlb_w_index;
    wire            tlb_w_e;
    wire    [18:0]  tlb_w_vppn;
    wire    [5:0]   tlb_w_ps;
    wire    [9:0]   tlb_w_asid;
    wire            tlb_w_g;
    wire    [19:0]  tlb_w_ppn0;
    wire    [1:0]   tlb_w_plv0;
    wire    [1:0]   tlb_w_mat0;
    wire            tlb_w_d0;
    wire            tlb_w_v0;
    wire    [19:0]  tlb_w_ppn1;
    wire    [1:0]   tlb_w_plv1;
    wire    [1:0]   tlb_w_mat1;
    wire            tlb_w_d1;
    wire            tlb_w_v1;
    wire    [3:0]   tlb_r_index;
    wire            tlb_r_e;
    wire    [18:0]  tlb_r_vppn;
    wire    [5:0]   tlb_r_ps;
    wire    [9:0]   tlb_r_asid;
    wire            tlb_r_g;
    wire    [19:0]  tlb_r_ppn0;
    wire    [1:0]   tlb_r_plv0;
    wire    [1:0]   tlb_r_mat0;
    wire            tlb_r_d0;
    wire            tlb_r_v0;
    wire    [19:0]  tlb_r_ppn1;
    wire    [1:0]   tlb_r_plv1;
    wire    [1:0]   tlb_r_mat1;
    wire            tlb_r_d1;
    wire            tlb_r_v1;

    wire            tlb_reflush;
    wire    [31:0]  tlb_reflush_pc;
    wire            if_ws_crush_with_tlbsrch;
    wire            out_ex_tlb_refill;

    // TLBRD results forwarded to CSR
    wire    [18:0]  tlbrd_tlbehi_vppn;
    wire    [19:0]  tlbrd_tlbelo0_ppn;
    wire            tlbrd_tlbelo0_g;
    wire    [1:0]   tlbrd_tlbelo0_mat;
    wire    [1:0]   tlbrd_tlbelo0_plv;
    wire            tlbrd_tlbelo0_d;
    wire            tlbrd_tlbelo0_v;
    wire    [19:0]  tlbrd_tlbelo1_ppn;
    wire            tlbrd_tlbelo1_g;
    wire    [1:0]   tlbrd_tlbelo1_mat;
    wire    [1:0]   tlbrd_tlbelo1_plv;
    wire            tlbrd_tlbelo1_d;
    wire            tlbrd_tlbelo1_v;
    wire    [5:0]   tlbrd_tlbidx_ps;
    wire    [9:0]   tlbrd_asid_asid;
    
    IF my_IF (
        .clk                (clk),
        .resetn             (resetn),
        .id_allowin         (id_allowin),
        .if_id_valid        (if_id_valid),
        .if_id_bus          (if_id_bus),
        .id_if_bus          (id_if_bus),
        .inst_sram_req      (inst_sram_req),
        .inst_sram_wr       (inst_sram_wr),
        .inst_sram_size     (inst_sram_size),
        .inst_sram_wstrb    (inst_sram_wstrb),
        .inst_sram_wdata    (inst_sram_wdata),
        .inst_sram_addr     (inst_sram_addr),
        .inst_sram_addr_ok  (inst_sram_addr_ok),
        .inst_sram_data_ok  (inst_sram_data_ok),
        .inst_sram_rdata    (inst_sram_rdata),
        .ertn_flush         (ertn_flush),
        .ertn_entry         (ertn_entry),
        .wb_ex              (wb_ex),
        .ex_entry           (ex_entry)
    );
    ID my_ID (
        .clk                (clk),
        .resetn             (resetn),
        .if_id_valid        (if_id_valid),
        .id_allowin         (id_allowin),
        .if_id_bus          (if_id_bus),
        .id_if_bus          (id_if_bus),
        .ex_allowin         (ex_allowin),
        .id_ex_valid        (id_ex_valid),
        .id_ex_bus          (id_ex_bus),
        .wb_id_bus          (wb_id_bus),
        .mem_id_bus         (mem_id_bus),
        .ex_id_bus          (ex_id_bus),
        .ertn_flush         (ertn_flush),
        .id_has_int         (has_int),
        .wb_ex              (wb_ex | ertn_flush)
    );
    EX  my_EX (
        .clk                (clk),
        .resetn             (resetn),
        .ex_allowin         (ex_allowin),
        .id_ex_valid        (id_ex_valid),
        .id_ex_bus          (id_ex_bus),
        .ex_mem_valid       (ex_mem_valid),
        .mem_allowin        (mem_allowin),
        .ex_mem_bus         (ex_mem_bus),
        .data_sram_req      (data_sram_req),
        .data_sram_wr       (data_sram_wr),
        .data_sram_size     (data_sram_size),
        .data_sram_wstrb    (data_sram_wstrb),
        .data_sram_wdata    (data_sram_wdata),
        .data_sram_addr     (data_sram_addr),
        .data_sram_addr_ok  (data_sram_addr_ok),
        .ex_id_bus          (ex_id_bus),
        //ertn
        .ertn_flush         (ertn_flush),
        .mem_ex             (mem_ex),
        .mem_ertn           (mem_ertn),
        .wb_ex              (wb_ex | ertn_flush),
        .reg_ex             (reg_ex),
        .s1_vppn            (s1_vppn),
        .s1_va_bit12        (s1_va_bit12),
        .s1_asid            (s1_asid),
        .s1_found           (s1_found),
        .s1_index           (s1_index),
        .tlbehi_vppn        (w_tlb_vppn),
        .tlbasid_asid       (w_tlb_asid),
        .if_ms_crush_with_tlbsrch (1'b0),
        .if_ws_crush_with_tlbsrch (if_ws_crush_with_tlbsrch),
        .tlb_reflush        (tlb_reflush),
        .crmd_da            (crmd_da),
        .crmd_pg            (crmd_pg),
        .plv                (crmd_plv),
        .datm               (crmd_datm),
        .DMW0_PLV0          (1'b0),
        .DMW0_PLV3          (1'b0),
        .DMW0_MAT           (2'b0),
        .DMW0_PSEG          (3'b0),
        .DMW0_VSEG          (3'b0),
        .DMW1_PLV0          (1'b0),
        .DMW1_PLV3          (1'b0),
        .DMW1_MAT           (2'b0),
        .DMW1_PSEG          (3'b0),
        .DMW1_VSEG          (3'b0),
        .s1_ppn             (s1_ppn),
        .s1_plv             (s1_plv),
        .s1_d               (s1_d),
        .s1_v               (s1_v),
        .invtlb_valid       (invtlb_valid),
        .invtlb_op          (invtlb_op)
    );
    MEM my_MEM (
        .clk                (clk),
        .resetn             (resetn),
        .mem_allowin        (mem_allowin),
        .ex_mem_valid       (ex_mem_valid),
        .ex_mem_bus         (ex_mem_bus),
        .mem_wb_valid       (mem_wb_valid),
        .wb_allowin         (wb_allowin),
        .mem_wb_bus         (mem_wb_bus),
        .data_sram_data_ok  (data_sram_data_ok),
        .data_sram_rdata    (data_sram_rdata),

        .mem_id_bus         (mem_id_bus),
        //ertn
        .ertn_flush         (ertn_flush),
        .mem_ex             (mem_ex),
        .mem_ertn           (mem_ertn),
        .wb_ex              (wb_ex | ertn_flush),
        .reg_ex             (reg_ex)
    );
    WB my_WB (
        .clk                (clk),
        .resetn             (resetn),
        .wb_allowin         (wb_allowin),
        .mem_wb_valid       (mem_wb_valid),
        .mem_wb_bus         (mem_wb_bus),
        .wb_id_bus          (wb_id_bus),
        .debug_wb_pc        (debug_wb_pc),
        .debug_wb_rf_we     (debug_wb_rf_we),
        .debug_wb_rf_wnum   (debug_wb_rf_wnum),
        .debug_wb_rf_wdata  (debug_wb_rf_wdata),
        //csr
        .csr_num            (csr_num),
        .csr_re             (csr_re),
        .csr_rvalue         (csr_rvalue),
        .csr_we             (csr_we),
        .csr_wvalue         (csr_wvalue),
        .csr_wmask          (csr_wmask),
        .ertn_flush         (ertn_flush),
        .wb_ex              (wb_ex),
        .wb_csr_pc          (wb_csr_pc),
        .wb_ecode           (wb_ecode),
        .wb_esubcode        (wb_esubcode),
        .wb_vaddr           (wb_vaddr),
        .inst_tlbsrch       (inst_tlbsrch),
        .lbsrch_got         (tlbsrch_got),
        .tlbsrch_index      (tlbsrch_index),
        .tlbidx_index       (tlbidx_index),
        .inst_tlbrd         (inst_tlbrd),
        .tlbrd_valid        (tlbrd_valid),
        .tlbasid_asid       (w_tlb_asid),
        .tlbidx_ps          (tlbidx_ps),
        .tlbidx_ne          (tlbidx_ne),
        .tlbehi_vppn        (w_tlb_vppn),
        .tlbrd_tlbehi_vppn  (tlbrd_tlbehi_vppn),
        .tlbelo0_v          (w_tlb_v0),
        .tlbelo0_d          (w_tlb_d0),
        .tlbelo0_plv        (w_tlb_plv0),
        .tlbelo0_mat        (w_tlb_mat0),
        .tlbelo0_g          (w_tlb_g),
        .tlbelo0_ppn        (w_tlb_ppn0),
        .tlbelo1_v          (w_tlb_v1),
        .tlbelo1_d          (w_tlb_d1),
        .tlbelo1_plv        (w_tlb_plv1),
        .tlbelo1_mat        (w_tlb_mat1),
        .tlbelo1_g          (w_tlb_g),
        .tlbelo1_ppn        (w_tlb_ppn1),
        .we                 (tlb_we),
        .w_index            (tlb_w_index),
        .w_e                (tlb_w_e),
        .w_vppn             (tlb_w_vppn),
        .w_ps               (tlb_w_ps),
        .w_asid             (tlb_w_asid),
        .w_g                (tlb_w_g),
        .w_ppn0             (tlb_w_ppn0),
        .w_plv0             (tlb_w_plv0),
        .w_mat0             (tlb_w_mat0),
        .w_d0               (tlb_w_d0),
        .w_v0               (tlb_w_v0),
        .w_ppn1             (tlb_w_ppn1),
        .w_plv1             (tlb_w_plv1),
        .w_mat1             (tlb_w_mat1),
        .w_d1               (tlb_w_d1),
        .w_v1               (tlb_w_v1),
        .r_index            (tlb_r_index),
        .r_e                (tlb_r_e),
        .r_vppn             (tlb_r_vppn),
        .r_ps               (tlb_r_ps),
        .r_asid             (tlb_r_asid),
        .r_g                (tlb_r_g),
        .r_ppn0             (tlb_r_ppn0),
        .r_plv0             (tlb_r_plv0),
        .r_mat0             (tlb_r_mat0),
        .r_d0               (tlb_r_d0),
        .r_v0               (tlb_r_v0),
        .r_ppn1             (tlb_r_ppn1),
        .r_plv1             (tlb_r_plv1),
        .r_mat1             (tlb_r_mat1),
        .r_d1               (tlb_r_d1),
        .r_v1               (tlb_r_v1),
        .tlbrd_tlbelo0_ppn  (tlbrd_tlbelo0_ppn),
        .tlbrd_tlbelo0_g    (tlbrd_tlbelo0_g),
        .tlbrd_tlbelo0_mat  (tlbrd_tlbelo0_mat),
        .tlbrd_tlbelo0_plv  (tlbrd_tlbelo0_plv),
        .tlbrd_tlbelo0_d    (tlbrd_tlbelo0_d),
        .tlbrd_tlbelo0_v    (tlbrd_tlbelo0_v),
        .tlbrd_tlbelo1_ppn  (tlbrd_tlbelo1_ppn),
        .tlbrd_tlbelo1_g    (tlbrd_tlbelo1_g),
        .tlbrd_tlbelo1_mat  (tlbrd_tlbelo1_mat),
        .tlbrd_tlbelo1_plv  (tlbrd_tlbelo1_plv),
        .tlbrd_tlbelo1_d    (tlbrd_tlbelo1_d),
        .tlbrd_tlbelo1_v    (tlbrd_tlbelo1_v),
        .tlbrd_tlbidx_ps    (tlbrd_tlbidx_ps),
        .tlbrd_asid_asid    (tlbrd_asid_asid),
        .tlb_reflush        (tlb_reflush),
        .tlb_reflush_pc     (tlb_reflush_pc),
        .out_ex_tlb_refill  (out_ex_tlb_refill),
        .stat_ecode         (estat_ecode),
        .if_ws_crush_with_tlbsrch (if_ws_crush_with_tlbsrch)
    );
    csr_reg csr(
        .clk                (clk),
        .resetn             (resetn),
        .csr_re             (csr_re),
        .csr_num            (csr_num),
        .csr_rvalue         (csr_rvalue),
        .csr_we             (csr_we),
        .csr_wmask          (csr_wmask),
        .csr_wvalue         (csr_wvalue),

        .ex_entry           (ex_entry),
        .ertn_flush         (ertn_flush),
        .ertn_entry         (ertn_entry),

        .wb_ex              (wb_ex),
        .wb_csr_pc          (wb_csr_pc),
        .wb_vaddr           (wb_vaddr),
        .wb_ecode           (wb_ecode),
        .wb_esubcode        (wb_esubcode),
        .has_int            (has_int),
        .hw_int_in          (hw_int_in),
        .ipi_int_in         (ipi_int_in),
        .coreid_in          (coreid_in),

        .tlbsrch_we         (inst_tlbsrch),
        .tlbsrch_hit        (tlbsrch_got),
        .tlbrd_we           (inst_tlbrd),
        .tlbsrch_hit_index  (tlbsrch_index),

        .r_tlb_e            (tlb_r_e),
        .r_tlb_ps           (tlbrd_tlbidx_ps),
        .r_tlb_vppn         (tlbrd_tlbehi_vppn),
        .r_tlb_asid         (tlbrd_asid_asid),
        .r_tlb_g            (tlbrd_tlbelo0_g),
        .r_tlb_ppn0         (tlbrd_tlbelo0_ppn),
        .r_tlb_plv0         (tlbrd_tlbelo0_plv),
        .r_tlb_mat0         (tlbrd_tlbelo0_mat),
        .r_tlb_d0           (tlbrd_tlbelo0_d),
        .r_tlb_v0           (tlbrd_tlbelo0_v),
        .r_tlb_ppn1         (tlbrd_tlbelo1_ppn),
        .r_tlb_plv1         (tlbrd_tlbelo1_plv),
        .r_tlb_mat1         (tlbrd_tlbelo1_mat),
        .r_tlb_d1           (tlbrd_tlbelo1_d),
        .r_tlb_v1           (tlbrd_tlbelo1_v),

        .w_tlb_e            (w_tlb_e),
        .w_tlb_ps           (w_tlb_ps),
        .w_tlb_vppn         (w_tlb_vppn),
        .w_tlb_asid         (w_tlb_asid),
        .w_tlb_g            (w_tlb_g),
        .w_tlb_ppn0         (w_tlb_ppn0),
        .w_tlb_plv0         (w_tlb_plv0),
        .w_tlb_mat0         (w_tlb_mat0),
        .w_tlb_d0           (w_tlb_d0),
        .w_tlb_v0           (w_tlb_v0),
        .w_tlb_ppn1         (w_tlb_ppn1),
        .w_tlb_plv1         (w_tlb_plv1),
        .w_tlb_mat1         (w_tlb_mat1),
        .w_tlb_d1           (w_tlb_d1),
        .w_tlb_v1           (w_tlb_v1),
        .crmd_da            (crmd_da),
        .crmd_pg            (crmd_pg),
        .crmd_plv           (crmd_plv),
        .crmd_datf          (crmd_datf),
        .crmd_datm          (crmd_datm),
        .estat_ecode        (estat_ecode),
        .tlbidx_index       (tlbidx_index),
        .tlbidx_ps          (tlbidx_ps),
        .tlbidx_ne          (tlbidx_ne),
        .tlbehi_vppn        (w_tlb_vppn),
        .asid_asid          (w_tlb_asid)
    );

    // Search port 0 currently unused (direct map)
    wire [18:0] s0_vppn      = 19'b0;
    wire        s0_va_bit12  = 1'b0;
    wire [9:0]  s0_asid      = w_tlb_asid;
    wire        s0_found;
    wire [3:0]  s0_index;
    wire [19:0] s0_ppn;
    wire [5:0]  s0_ps;
    wire [1:0]  s0_plv;
    wire [1:0]  s0_mat;
    wire        s0_d;
    wire        s0_v;

    tlb u_tlb (
        .clk            (clk),
        .s0_vppn        (s0_vppn),
        .s0_va_bit12    (s0_va_bit12),
        .s0_asid        (s0_asid),
        .s0_found       (s0_found),
        .s0_index       (s0_index),
        .s0_ppn         (s0_ppn),
        .s0_ps          (s0_ps),
        .s0_plv         (s0_plv),
        .s0_mat         (s0_mat),
        .s0_d           (s0_d),
        .s0_v           (s0_v),

        .s1_vppn        (s1_vppn),
        .s1_va_bit12    (s1_va_bit12),
        .s1_asid        (s1_asid),
        .s1_found       (s1_found),
        .s1_index       (s1_index),
        .s1_ppn         (s1_ppn),
        .s1_ps          (s1_ps),
        .s1_plv         (s1_plv),
        .s1_mat         (s1_mat),
        .s1_d           (s1_d),
        .s1_v           (s1_v),

        .invtlb_valid   (invtlb_valid),
        .invtlb_op      (invtlb_op),

        .we             (tlb_we),
        .w_index        (tlb_w_index),
        .w_e            (tlb_w_e),
        .w_vppn         (tlb_w_vppn),
        .w_ps           (tlb_w_ps),
        .w_asid         (tlb_w_asid),
        .w_g            (tlb_w_g),
        .w_ppn0         (tlb_w_ppn0),
        .w_plv0         (tlb_w_plv0),
        .w_mat0         (tlb_w_mat0),
        .w_d0           (tlb_w_d0),
        .w_v0           (tlb_w_v0),
        .w_ppn1         (tlb_w_ppn1),
        .w_plv1         (tlb_w_plv1),
        .w_mat1         (tlb_w_mat1),
        .w_d1           (tlb_w_d1),
        .w_v1           (tlb_w_v1),

        .r_index        (tlb_r_index),
        .r_e            (tlb_r_e),
        .r_vppn         (tlb_r_vppn),
        .r_ps           (tlb_r_ps),
        .r_asid         (tlb_r_asid),
        .r_g            (tlb_r_g),
        .r_ppn0         (tlb_r_ppn0),
        .r_plv0         (tlb_r_plv0),
        .r_mat0         (tlb_r_mat0),
        .r_d0           (tlb_r_d0),
        .r_v0           (tlb_r_v0),
        .r_ppn1         (tlb_r_ppn1),
        .r_plv1         (tlb_r_plv1),
        .r_mat1         (tlb_r_mat1),
        .r_d1           (tlb_r_d1),
        .r_v1           (tlb_r_v1)
    );
endmodule