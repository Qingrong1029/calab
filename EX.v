`include "defines.vh"
module EX (
    input           clk,
    input           resetn,

    output          ex_allowin,
    input           id_ex_valid,
    input   [375:0] id_ex_bus,

    output          ex_mem_valid,
    input           mem_allowin,
    input           wb_ex,
    output  [250:0] ex_mem_bus,

    output          data_sram_req,
    output          data_sram_wr,
    output  [ 1:0]  data_sram_size,
    output  [ 3:0]  data_sram_wstrb,
    output  [31:0]  data_sram_addr,
    output  [31:0]  data_sram_wdata,
    input           data_sram_addr_ok,

    output  [55:0]  ex_id_bus,
    //ertn
    input           mem_ex,
    input           mem_ertn,
    input           ertn_flush,
    output          reg_ex,
    
    //port with tlb.v
    output  [18:0]  s1_vppn,
    output          s1_va_bit12,
    output  [ 9:0]  s1_asid,

    input           s1_found,
    input   [ 3:0]  s1_index,

    //tlb add
    input   [18:0]  tlbehi_vppn,
    input   [ 9:0]  tlbasid_asid,

    //tlb crush
    input        if_mem_crush_tlbsrch,
    input        if_wb_crush_tlbsrch,
    input        tlb_reflush,

    //for translate
    input crmd_da,
    input crmd_pg,

    input [1:0] plv,
    input [1:0] datm,

    input DMW0_PLV0,
    input DMW0_PLV3,
    input [1:0] DMW0_MAT,
    input [2:0] DMW0_PSEG,
    input [2:0] DMW0_VSEG,

    input DMW1_PLV0,        
    input DMW1_PLV3,       
    input [1:0] DMW1_MAT,  
    input [2:0] DMW1_PSEG,  
    input [2:0] DMW1_VSEG,

    //input s1_found,
    input [19:0] s1_ppn,
    input [1:0] s1_plv,
    input s1_d,
    input s1_v,

    output invtlb_valid,
    output [4:0] invtlb_op

);
    //exp13
    reg [63:0] cnt_value;
    
    always @(posedge clk) begin
        if (~resetn)
            cnt_value <= 64'b0;
        else
            cnt_value <= cnt_value + 1'b1;  // 每周期自增
    end
     
    reg             ex_valid;
    wire            ex_ready_go;
    wire    [ 31:0] ex_inst;
    wire    [ 31:0] ex_pc;
    reg     [375:0] id_ex_bus_vld;
    wire            ex_bypass;
    wire            ex_ld;
    wire    [  2:0] mem_type;
    wire            ex_syscall_ex;
    wire            ex_ale;           // ALE异常信号
    wire    [  4:0] ex_load_op;       // 需要从ID阶段传递过来
    wire    [  2:0] ex_store_op;
    wire    [ 31:0] alu_result;
    wire            ex_div_en;
    wire            tlb_zombie;  

    // 增加ALE检测逻辑
    wire ld_ale = ex_load_op[1] & alu_result[0]                        // ld_h地址错
            | ex_load_op[2] & (alu_result[1] | alu_result[0])      // ld_w地址错  
            | ex_load_op[4] & alu_result[0];                       // ld_hu地址错

    wire st_ale = ex_store_op[1] & alu_result[0]                       // st_h地址错
            | ex_store_op[2] & (alu_result[1] | alu_result[0]);    // st_w地址错

    //block
    assign  ex_ready_go = (~(~data_sram_req | data_sram_req & data_sram_addr_ok | reg_ex))? 1'b0:
                                                                     (ex_div_en) ? div_done : 1'b1;
    assign  ex_mem_valid = ex_ready_go & ex_valid;
    assign  ex_allowin = ex_mem_valid & mem_allowin | ~ex_valid;
    always @(posedge clk ) begin
        if (~resetn) begin
            ex_valid <= 1'b0;
        end
        else if(wb_ex) begin
            ex_valid <= 1'b0;
        end
        else if(ex_allowin) begin
            ex_valid <= id_ex_valid;
        end
    end
    always @(posedge clk ) begin
        if (id_ex_valid & ex_allowin) begin
            id_ex_bus_vld <= id_ex_bus; 
        end
    end

    wire            ex_gr_we;
    wire            res_from_mem;
    wire    [14:0]  alu_op;

    wire    [ 2:0]  ex_div_op;
    wire    [31:0]  alu_src1;
    wire    [31:0]  alu_src2;
    wire    [ 4:0]  ex_dest;
    wire    [31:0]  rkd_value;
    wire    [31:0]  rj_value;
    wire    [31:0]  st_data;
    //csr exp12
    wire            ex_csr_we;
    wire            ex_csr_re;
    wire    [13:0]  ex_csr_num;
    wire    [31:0]  ex_csr_wmask;
    wire    [31:0]  ex_csr_wvalue;
    wire            ex_ertn;

    wire            inst_st_w;
    wire            inst_st_b;
    wire            inst_st_h;
    wire            ex_rdcntvl;
    wire            ex_rdcntvh;

    wire            ex_adef;          // 从ID传递的ADEF
    wire    [31:0]  ex_wrong_addr;    // 错误地址
    wire            ex_ertn_flush;    // ERTN刷新
    wire            ex_ex;            // 异常信号
    wire    [ 8:0]  ex_esubcode;      // 异常子码
    wire    [ 5:0]  ex_ecode;         // 异常编码
    wire    [ 5:0]  final_ecode;
    wire            final_ex;
    
    wire            inst_tlbsrch;
    wire            inst_tlbrd;
    wire            inst_tlbwr;
    wire            inst_tlbfill;
    wire            inst_invtlb;
    wire    [ 4:0]  inst_invtlb_op;

    assign {
        ex_gr_we, inst_st_w, inst_st_b, inst_st_h, res_from_mem, mem_type,
        alu_op, ex_div_en, ex_div_op, alu_src1, alu_src2,
        ex_dest, rkd_value, rj_value, ex_inst, ex_pc, ex_csr_we, ex_csr_re, ex_csr_num, ex_csr_wmask, ex_csr_wvalue, 
        ex_ertn, ex_syscall_ex, ex_rdcntvl, ex_rdcntvh, ex_wrong_addr,ex_load_op, ex_store_op, ex_adef, ex_ex, ex_esubcode, ex_ecode,
        inst_tlbsrch, inst_tlbrd, inst_tlbwr, inst_tlbfill, inst_invtlb, inst_invtlb_op, tlb_zombie
    } = id_ex_bus_vld;

    alu my_alu (    
        .alu_op(alu_op),
        .alu_src1(alu_src1),
        .alu_src2(alu_src2),
        .alu_result(alu_result)
    );
    
    wire [ 1:0] mem_addr_low2 = alu_result[1:0];
    wire [31:0] div_result;
    wire        div_busy;
    wire        div_done;

    div my_div (
        .clk         (clk),
        .resetn      (resetn),
        .ex_div_en   (ex_div_en),
        .ex_div_op   (ex_div_op[1:0]),
        .alu_src1    (alu_src1),
        .alu_src2    (alu_src2),
        .signed_src1 ($signed(alu_src1)),
        .signed_src2 ($signed(alu_src2)),
        .div_result  (div_result),
        .div_busy    (div_busy),
        .div_done    (div_done)
    );

    wire [31:0] ex_final_result = ex_rdcntvl ? cnt_value[31:0]  : 
                                  ex_rdcntvh ? cnt_value[63:32] :
                                  ex_div_en  ? div_result       : alu_result;
    wire [31:0] ex_ale_addr = alu_result;

    wire [31:0] final_wrong_addr = ex_ale ? ex_ale_addr : ex_wrong_addr;
    assign st_data = inst_st_b ? {4{rkd_value[ 7:0]}} :
                     inst_st_h ? {2{rkd_value[15:0]}} :
                                    rkd_value[31:0];
    
    reg  addr_ok_reg;
    reg  ex_reg;
    reg  ertn_reg;
    assign reg_ex = (wb_ex | ertn_flush | ex_reg | ertn_reg);
    always @(posedge clk) begin
        if(~resetn) begin
            addr_ok_reg <= 1'b0;
        end 
        else if(data_sram_addr_ok & data_sram_req & ~mem_allowin) begin
            addr_ok_reg <= 1'b1;
        end 
        else if(mem_allowin) begin
            addr_ok_reg <= 1'b0;
        end
    end
    always @(posedge clk) begin
        if (~resetn) begin
            ex_reg   <= 1'b0;
            ertn_reg <= 1'b0;
        end 
        else if (wb_ex) begin
            ex_reg <= 1'b1;
        end 
        else if (ertn_flush) begin
            ertn_reg <= 1'b1;
        end 
        else if (id_ex_valid & ex_allowin)begin
            ex_reg   <= 1'b0;
            ertn_reg <= 1'b0;
        end 
    end
    
    assign s1_vppn = (inst_tlbsrch) ? tlbehi_vppn:
                      (inst_invtlb) ? rkd_value[31:13] : alu_result[31:13];        
    assign s1_va_bit12 = alu_result[12];
    assign s1_asid = (inst_tlbsrch) ? tlbasid_asid : 
                      (inst_invtlb) ? rj_value[9:0] : tlbasid_asid;
    assign invtlb_valid = inst_invtlb;
    assign invtlb_op    = inst_invtlb_op;
    
    wire [31:0] address_dt;
    assign address_dt = alu_result;
    
    wire [31:0] address_dmw0;
    assign address_dmw0 = {DMW0_PSEG, alu_result[28:0]};
    
    wire [31:0] address_dmw1;
    assign address_dmw1 = {DMW1_PSEG, alu_result[28:0]};
    
    wire [31:0] address_ptt;
    assign address_ptt = {s1_ppn, alu_result[11:0]};
    
    wire if_dt;
    assign if_dt = crmd_da & ~crmd_pg;
    
    wire if_indt;
    assign if_indt = ~crmd_da & crmd_pg;
    
    wire if_dmw0;
    assign if_dmw0 = ((plv == 0 && DMW0_PLV0) || (plv == 3 && DMW0_PLV3)) &&
                    (datm == DMW0_MAT) && (alu_result[31:29] == DMW0_VSEG);
                    
    wire if_dmw1;
    assign if_dmw1 = ((plv == 0 && DMW1_PLV0) || (plv == 3 && DMW1_PLV3)) &&
                    (datm == DMW1_MAT) && (alu_result[31:29] == DMW1_VSEG);
    
    wire [31:0] address_p;
    assign address_p = if_dt ? address_dt : if_indt ?
                (if_dmw0 ? address_dmw0 : if_dmw1 ? address_dmw1 : address_ptt) : 0;
                
    wire es_ex_loadstore_tlb_fill;
    wire es_ex_load_invalid;
    wire es_ex_store_invalid;
    wire es_ex_loadstore_plv_invalid;
    wire es_ex_store_dirty;
    
    wire if_ppt;
    assign if_ppt = if_indt & ~(if_dmw0 | if_dmw1);
    
    assign es_ex_loadstore_tlb_fill = if_ppt & (res_from_mem | ex_gr_we) & ~s1_found;
    assign es_ex_load_invalid = if_ppt & res_from_mem & s1_found & ~s1_v;
    assign es_ex_store_invalid = if_ppt & ex_gr_we & s1_found & ~s1_v;
    assign es_ex_loadstore_plv_invalid = if_ppt & (res_from_mem | ex_gr_we) & s1_found
                                    & s1_v & (plv > s1_plv);
    assign es_ex_store_dirty = if_ppt & ex_gr_we & s1_found & s1_v & ~s1_d & 
                            (plv == 2'b00 || (plv == 2'b01 &&(s1_plv == 2'b01 || s1_plv == 2'b10 || s1_plv == 2'b11)) ||
                            (plv == 2'b10 &&( s1_plv == 2'b10 || s1_plv == 2'b11)) ||
                            (plv == 2'b11 &&(s1_plv == 2'b11)) );

    
    assign data_sram_req = ((|ex_load_op) | (|ex_store_op)) & ex_valid & mem_allowin &
                    ~wb_ex & ~ertn_flush & ~reg_ex & ~addr_ok_reg;
    assign data_sram_wr = (|data_sram_wstrb) & ex_valid & ~wb_ex & ~mem_ex & ~final_ex;
    assign data_sram_wstrb = (~wb_ex & ~ertn_flush & ~mem_ex & ~ex_ale & ~mem_ertn & ~final_ex & ~ex_ertn) ? (
                    inst_st_b ? (
                        mem_addr_low2 == 2'b00 ? 4'b0001 :
                        mem_addr_low2 == 2'b01 ? 4'b0010 :
                        mem_addr_low2 == 2'b10 ? 4'b0100 :
                                                 4'b1000
                    ) : inst_st_h ? (
                        mem_addr_low2 == 2'b00 ? 4'b0011 :
                                                 4'b1100
                    ) : inst_st_w ? 4'b1111 : 4'b0000
                ) : 4'b0000;  // ERTN flush 时禁止写
    assign  data_sram_size = (mem_type[1:0] == 2'b01) ? 2'h1 : 
                             (mem_type[1:0] == 2'b11) ? 2'h2 : 
                              2'h0;
    assign  data_sram_addr = alu_result[31:0];
    assign  data_sram_wdata = st_data;
    assign  ex_mem_bus = {
        ex_gr_we, res_from_mem, mem_type, mem_addr_low2,
        ex_dest,ex_pc, ex_inst, ex_final_result, ex_csr_we, ex_csr_re, ex_csr_num, ex_csr_wmask, ex_csr_wvalue, 
        ex_ertn,ex_syscall_ex , final_wrong_addr,ex_ale, ex_adef, final_ex, ex_esubcode, final_ecode,
        inst_tlbsrch, inst_tlbrd, inst_tlbwr, inst_tlbfill, inst_invtlb, s1_found, s1_index, tlb_zombie
    };

    // 添加异常优先级处理逻辑
    assign final_ecode = ex_ale ? `ECODE_ALE : ex_ecode;
    assign final_ex = ex_ex | ex_ale | reg_ex;  // ALE或其他异常

    // 修改ALE检测，确保只在有效操作时检测
    assign ex_ale = (ld_ale | st_ale) & ex_valid & (|ex_load_op | |ex_store_op);
    assign ex_bypass = ex_valid & ex_gr_we& ~final_ex;
    assign ex_ld = ex_valid & res_from_mem;
    assign ex_div_busy = ex_valid & div_busy;
    assign ex_id_bus = {ex_bypass , ex_ld , ex_dest , ex_final_result , ex_div_busy , ex_gr_we ,ex_csr_re & ex_valid, ex_csr_num};
endmodule