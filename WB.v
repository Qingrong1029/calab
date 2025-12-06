`include "defines.vh"

module WB (
    input           clk,
    input           resetn,

    output          wb_allowin,
    input           mem_wb_valid,
    input   [242:0] mem_wb_bus,

    output  [ 38:0] wb_id_bus,

    output  [ 31:0] debug_wb_pc,
    output  [  3:0] debug_wb_rf_we,
    output  [  4:0] debug_wb_rf_wnum,
    output  [ 31:0] debug_wb_rf_wdata,
    
    //csr
    output  [13:0]  csr_num,
    output          csr_re,
    input   [31:0]  csr_rvalue,

    output          csr_we,
    output  [31:0]  csr_wvalue,
    output  [31:0]  csr_wmask,
    output          ertn_flush,
    output          wb_ex,
    output  [31:0]  wb_csr_pc,
    output  [ 5:0]  wb_ecode,
    output  [ 8:0]  wb_esubcode,
    output  [31:0]  wb_vaddr,
   
    output          if_fetch_plv_ex,
    output          if_fetch_tlb_refill,

    //tlbsrch
    output          inst_tlbsrch,
    output          tlbsrch_got,
    output [3:0]    tlbsrch_index,

    //tlbrd
    input [3:0]     tlbidx_index,     //from csr
    output          inst_tlbrd,
    output          tlbrd_valid,

    //tlbwr
    input  [9:0]    tlbasid_asid,
    input  [5:0]    tlbidx_ps,
    input           tlbidx_ne,

    input  [18:0]   tlbehi_vppn,
    output [18:0]   tlbrd_tlbehi_vppn,

    input           tlbelo0_v,
    input           tlbelo0_d,
    input  [1:0]    tlbelo0_plv,
    input  [1:0]    tlbelo0_mat,
    input           tlbelo0_g,
    input  [19:0]   tlbelo0_ppn,

    input           tlbelo1_v,
    input           tlbelo1_d,
    input  [1:0]    tlbelo1_plv,
    input  [1:0]    tlbelo1_mat,
    input           tlbelo1_g,
    input  [19:0]   tlbelo1_ppn,

    output          we,
    output [3:0]    w_index,
    output          w_e,
    output [18:0]   w_vppn,
    output [5:0]    w_ps,
    output [9:0]    w_asid,
    output          w_g,

    output [19:0]   w_ppn0,
    output [1:0]    w_plv0,
    output [1:0]    w_mat0,
    output          w_d0,
    output          w_v0,

    output [19:0]   w_ppn1,
    output [1:0]    w_plv1,
    output [1:0]    w_mat1,
    output          w_d1,
    output          w_v1,
    output [3:0]    r_index,
    //tlb_reflush
    output          tlb_reflush,
    output [31:0]   tlb_reflush_pc,

    output          out_ex_tlb_refill,
    input  [5:0]    stat_ecode,

    //tlb crush
    output          if_wb_crush_tlbsrch,
    input           s1_found,
    input [3:0]     s1_index,
    input [9:0]     s1_asid
);

    reg             wb_valid;
    reg     [242:0] mem_wb_bus_vld;
    wire            wb_ready_go;
    wire            wb_gr_we;
    wire            rf_we;
    wire    [ 31:0] wb_pc;
    wire    [ 31:0] wb_inst;
    wire    [ 31:0] final_result;
    wire    [  4:0] rf_waddr;
    wire    [ 31:0] rf_wdata;
    wire    [  4:0] wb_dest;
    wire    [ 31:0] wb_wdata; 
    //csr exp12
    wire            wb_csr_we;
    wire            wb_csr_re;
    wire    [13:0]  wb_csr_num;
    wire    [31:0]  wb_csr_wmask;
    wire    [31:0]  wb_csr_wvalue;
    wire            wb_ertn;

    wire    [31:0]  wb_wrong_addr;
    wire     [31:0] wb_vaddr;
    wire            wb_ex_id;         // 从ID传来的异常
    wire    [ 8:0]  wb_esubcode_tmp;      // 异常子码
    
    assign tlbsrch_got   = s1_found;
    assign tlbsrch_index = s1_index;
    
    //for tlbrd
    assign r_index = tlbidx_index;
    //for tlbwr
    reg [3:0] random_index;
    reg if_keep;
    
    always @(posedge clk)
        begin
            if(~resetn)
                random_index <= 0;
            else if(inst_tlbfill && mem_wb_valid)
            //prepare next random for next tlbfill inst
                random_index <= ( {$random()} % 16 );
        end
    assign we = (inst_tlbwr | inst_tlbfill);
    assign w_index = inst_invtlb ? tlbsrch_index : inst_tlbwr ? tlbidx_index : random_index;
    assign w_e = (stat_ecode != 6'h3f)? ~tlbidx_ne: 1'b1;
    assign w_vppn = tlbehi_vppn;
    assign w_ps = tlbidx_ps;
    assign w_asid = inst_invtlb ? s1_asid : tlbasid_asid;
    assign w_g = tlbelo0_g && tlbelo1_g; 
   
    assign w_ppn0 = tlbelo0_ppn;
    assign w_plv0 = tlbelo0_plv;
    assign w_mat0 = tlbelo0_mat;
    assign w_d0   = tlbelo0_d;
    assign w_v0   = tlbelo0_v;
   
    assign w_ppn1 = tlbelo1_ppn;
    assign w_plv1 = tlbelo1_plv;
    assign w_mat1 = tlbelo1_mat;
    assign w_d1   = tlbelo1_d;
    assign w_v1   = tlbelo1_v;
    

    wire if_csr_crush_with_tlbsrch;
    assign if_csr_crush_with_tlbsrch = csr_we && (csr_num == `CSR_ASID 
                                               || csr_num == `CSR_TLBEHI);
    wire if_tlbrd_crush_with_tlbsrch;
    assign if_tlbrd_crush_with_tlbsrch = inst_tlbrd;

    assign if_ws_crush_with_tlbsrch = if_csr_crush_with_tlbsrch
                                    || if_tlbrd_crush_with_tlbsrch;
    
    assign wb_ready_go = 1'b1;
    assign wb_allowin = wb_ready_go | ~wb_valid;
    always @(posedge clk ) begin
        if (~resetn) begin
            wb_valid <= 1'b0;
        end
        else if (wb_ex) begin
            wb_valid <= 1'b0;
        end
        else if (ertn_flush) begin
            wb_valid <= 1'b0;
        end
        else if (wb_allowin) begin
            wb_valid <= mem_wb_valid;
        end
    end
    always @(posedge clk ) begin
        if (mem_wb_valid & wb_allowin) begin
            mem_wb_bus_vld <= mem_wb_bus;
        end
    end
    assign  {
        wb_gr_we, wb_pc, wb_inst, final_result, wb_dest,
        wb_csr_we, wb_csr_re, wb_csr_num, wb_csr_wmask, wb_csr_wvalue, wb_ertn, wb_syscall_ex, wb_wrong_addr, wb_ex_id, wb_esubcode_tmp, wb_ecode,
        inst_tlbsrch, inst_tlbrd, inst_tlbwr, inst_tlbfill, inst_invtlb, s1_found, s1_index, tlb_zombie
    } = mem_wb_bus_vld;

    assign  rf_we = wb_valid & wb_gr_we & ~wb_ex;
    assign  rf_waddr = wb_dest; 
    assign  rf_wdata = wb_wdata;
    assign  wb_id_bus = {
        rf_we, rf_waddr, rf_wdata, csr_re
    };
    assign  wb_ex = wb_valid & wb_ex_id ;//可以加别的异常
    assign  wb_esubcode = wb_ex_id ? wb_esubcode_tmp : 9'b0;  // syscall没有子编码
    assign  wb_csr_pc = wb_pc;
    assign  ertn_flush = wb_valid & wb_ertn;
    //csr 
    assign  wb_wdata = csr_re ? csr_rvalue : final_result;
    assign  csr_num = wb_csr_num;
    assign  csr_re = wb_csr_re | wb_csr_we;
    assign  csr_we = wb_csr_we;
    assign  csr_wvalue = wb_csr_wvalue;
    assign  csr_wmask = wb_csr_wmask;
    assign  wb_vaddr  = wb_wrong_addr;
    assign  tlb_reflush_pc = wb_pc;
    assign  tlb_reflush = tlb_zombie;


    assign  debug_wb_pc = wb_pc;
    assign  debug_wb_rf_we = {4{rf_we}};
    assign  debug_wb_rf_wnum = wb_dest;
    assign  debug_wb_rf_wdata = wb_wdata;
endmodule