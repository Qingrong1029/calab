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
    wire   [112:0] if_id_bus;
    wire    [ 33:0] id_if_bus;
    wire            ex_allowin;
    wire            id_ex_valid;
    wire    [332:0] id_ex_bus;
    wire    [ 38:0] wb_id_bus;
    wire    [239:0] ex_mem_bus;
    wire            ex_mem_valid;
    wire            mem_allowin;
    wire            mem_wb_valid;
    wire    [231:0] mem_wb_bus;
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
    wire    [31:0]  coreid_in;
    wire            has_int;
    wire    [7:0]   hw_int_in  = 8'b0;
    wire            ipi_int_in = 1'b0;
    wire            mem_ex;
    wire            mem_ertn;
    wire            id_has_int;
    wire            reg_ex;
    wire    [1:0]   csr_crmd_plv;
    wire   [18:0]   if_s0_vppn;
    wire            if_s0_va_bit12;
    wire            tlb_enable;
    wire            s0_found;
    wire   [19:0]   s0_ppn;
    wire   [5:0]    s0_ps;
    wire   [1:0]    s0_plv;
    wire   [1:0]    s0_mat;
    wire            s0_d;
    wire            s0_v;
    wire   [18:0]   ex_s1_vppn;
    wire            ex_s1_va_bit12;
    wire            s1_found;
    wire   [19:0]   s1_ppn;
    wire   [5:0]    s1_ps;
    wire   [1:0]    s1_plv;
    wire   [1:0]    s1_mat;
    wire            s1_d;
    wire            s1_v;
    wire   [9:0]    tlb_asid_value;

    localparam      TLBNUM = 16;
    localparam      TLBNUM_IDX_WIDTH = (TLBNUM <= 1) ? 1 : $clog2(TLBNUM);
    wire [TLBNUM_IDX_WIDTH-1:0] tlb_s0_index_unused;
    wire [TLBNUM_IDX_WIDTH-1:0] tlb_s1_index_unused;
    wire [TLBNUM_IDX_WIDTH-1:0] tlb_r_index;
    wire                        tlb_r_e;
    wire [18:0]                 tlb_r_vppn;
    wire [5:0]                  tlb_r_ps;
    wire [9:0]                  tlb_r_asid;
    wire                        tlb_r_g;
    wire [19:0]                 tlb_r_ppn0;
    wire [1:0]                  tlb_r_plv0;
    wire [1:0]                  tlb_r_mat0;
    wire                        tlb_r_d0;
    wire                        tlb_r_v0;
    wire [19:0]                 tlb_r_ppn1;
    wire [1:0]                  tlb_r_plv1;
    wire [1:0]                  tlb_r_mat1;
    wire                        tlb_r_d1;
    wire                        tlb_r_v1;

    assign tlb_enable = 1'b1;
    assign tlb_r_index = {TLBNUM_IDX_WIDTH{1'b0}};

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
        .ex_entry           (ex_entry),
        .s0_vppn            (if_s0_vppn),
        .s0_va_bit12        (if_s0_va_bit12),
        .tlb_enable         (tlb_enable),
        .s0_found           (s0_found),
        .s0_ppn             (s0_ppn),
        .s0_ps              (s0_ps),
        .s0_plv             (s0_plv),
        .s0_mat             (s0_mat),
        .s0_d               (s0_d),
        .s0_v               (s0_v),
        .csr_plv            (csr_crmd_plv)
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
        .s1_vppn            (ex_s1_vppn),
        .s1_va_bit12        (ex_s1_va_bit12),
        .tlb_enable         (tlb_enable),
        .s1_found           (s1_found),
        .s1_ppn             (s1_ppn),
        .s1_ps              (s1_ps),
        .s1_plv             (s1_plv),
        .s1_mat             (s1_mat),
        .s1_d               (s1_d),
        .s1_v               (s1_v),
        .csr_plv            (csr_crmd_plv)
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
        .wb_vaddr           (wb_vaddr)
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
        .csr_crmd_plv_o     (csr_crmd_plv),
        .csr_asid_value     (tlb_asid_value)
        
    );
    tlb u_tlb (
        .clk         (clk),
        .s0_vppn     (if_s0_vppn),
        .s0_va_bit12 (if_s0_va_bit12),
        .s0_asid     (tlb_asid_value),
        .s0_found    (s0_found),
        .s0_index    (tlb_s0_index_unused),
        .s0_ppn      (s0_ppn),
        .s0_ps       (s0_ps),
        .s0_plv      (s0_plv),
        .s0_mat      (s0_mat),
        .s0_d        (s0_d),
        .s0_v        (s0_v),
        .s1_vppn     (ex_s1_vppn),
        .s1_va_bit12 (ex_s1_va_bit12),
        .s1_asid     (tlb_asid_value),
        .s1_found    (s1_found),
        .s1_index    (tlb_s1_index_unused),
        .s1_ppn      (s1_ppn),
        .s1_ps       (s1_ps),
        .s1_plv      (s1_plv),
        .s1_mat      (s1_mat),
        .s1_d        (s1_d),
        .s1_v        (s1_v),
        .invtlb_valid(1'b0),
        .invtlb_op   (5'b0),
        .we          (1'b0),
        .w_index     ({TLBNUM_IDX_WIDTH{1'b0}}),
        .w_e         (1'b0),
        .w_vppn      (19'b0),
        .w_ps        (6'b0),
        .w_asid      (10'b0),
        .w_g         (1'b0),
        .w_ppn0      (20'b0),
        .w_plv0      (2'b0),
        .w_mat0      (2'b0),
        .w_d0        (1'b0),
        .w_v0        (1'b0),
        .w_ppn1      (20'b0),
        .w_plv1      (2'b0),
        .w_mat1      (2'b0),
        .w_d1        (1'b0),
        .w_v1        (1'b0),
        .r_index     (tlb_r_index),
        .r_e         (tlb_r_e),
        .r_vppn      (tlb_r_vppn),
        .r_ps        (tlb_r_ps),
        .r_asid      (tlb_r_asid),
        .r_g         (tlb_r_g),
        .r_ppn0      (tlb_r_ppn0),
        .r_plv0      (tlb_r_plv0),
        .r_mat0      (tlb_r_mat0),
        .r_d0        (tlb_r_d0),
        .r_v0        (tlb_r_v0),
        .r_ppn1      (tlb_r_ppn1),
        .r_plv1      (tlb_r_plv1),
        .r_mat1      (tlb_r_mat1),
        .r_d1        (tlb_r_d1),
        .r_v1        (tlb_r_v1)
    );
endmodule