module ID (
    input           clk,
    input           resetn,

    input           if_id_valid,
    output          id_allowin,
    input   [63:0]  if_id_bus,
    output  [32:0]  id_if_bus,

    input           ex_allowin,
    output          id_ex_valid,
    output  [275:0] id_ex_bus,
    input   [ 38:0] wb_id_bus,
    input           wb_ex,

    input   [ 53:0] mem_id_bus,
    input   [ 55:0] ex_id_bus,
    input           ertn_flush,
    input           id_has_int
);
    reg             id_valid;
    wire            id_ready_go;
    wire    [31:0]  id_inst;
    wire    [31:0]  id_pc;
    wire            br_taken;
    wire    [31:0]  br_target;
    reg     [63:0]  if_id_bus_vld;
    wire            wb_ex;
    
    wire    [ 2:0]  mem_type;// 000: word, 001: halfword, 010: byte, 1xx: unsigned
    
    //conflict
    wire            need_addr1;
    wire            need_addr2;
    wire            ex_bypass;
    wire            ex_ld;
    wire            mem_bypass;
    wire    [31:0]  ex_wdata;
    wire    [31:0]  mem_wdata;
    wire    [ 4:0]  ex_dest;
    wire    [ 4:0]  mem_dest;
    wire            ex_div_busy;
    wire            mem_gr_we;
    wire            mem_csr;
    wire            ex_csr;
    wire            wb_csr;
    wire    [13:0]  ex_csr_num;
    wire    [13:0]  mem_csr_num;
    
    assign mem_type = inst_ld_w  ? 3'b000 :  // word
                  inst_st_w  ? 3'b000 :  // word
                  inst_ld_h  ? 3'b001 :  // halfword
                  inst_st_h  ? 3'b001 :  // halfword
                  inst_ld_hu ? 3'b101 :  // halfword unsigned
                  inst_ld_b  ? 3'b010 :  // byte
                  inst_st_b  ? 3'b010 :  // byte
                  inst_ld_bu ? 3'b110 :  // byte unsigned
                  3'b000;
    
    assign { ex_bypass , ex_ld , ex_dest , ex_wdata, ex_div_busy, ex_gr_we, ex_csr, ex_csr_num} =  ex_id_bus;
    assign { mem_bypass , mem_dest , mem_wdata, mem_gr_we, mem_csr ,mem_csr_num} = mem_id_bus;
    
    assign id_ex_valid = id_ready_go & id_valid & ~ertn_flush & ~wb_ex;
    assign id_allowin = id_ex_valid & ex_allowin | ~id_valid | ertn_flush;
    always @(posedge clk ) begin
        if(~resetn||wb_ex ) begin
            id_valid <= 1'b0;
        end
        else if (ertn_flush) begin
            // ertn_flush时立即清空ID阶段
            id_valid <= 1'b0;
        end
        else if( br_taken & id_ready_go) begin
            id_valid <= 1'b0;
        end
        else if(id_allowin) begin
            id_valid <= if_id_valid;
        end
    end
    always @(posedge clk ) begin
        if(if_id_valid & id_allowin)begin
            if_id_bus_vld <= if_id_bus;
        end
    end
    assign {id_pc, id_inst, id_adef} = if_id_bus_vld;
    //译码
    wire [14:0] alu_op;
    wire        src1_is_pc;
    wire        src2_is_imm;
    wire        res_from_mem;
    wire        dst_is_r1;
    wire        dst_is_rj;
    wire        id_gr_we;
    wire        src_reg_is_rd;
    wire [4:0]  id_dest;
    wire [31:0] rj_value;
    wire [31:0] rkd_value;    
    wire [31:0] imm;
    wire [31:0] br_offs;
    wire [31:0] jirl_offs;
    
    wire [ 5:0] op_31_26;
    wire [ 3:0] op_25_22;
    wire [ 1:0] op_21_20;
    wire [ 4:0] op_19_15;
    wire [ 1:0] op_25_24;
    wire [ 4:0] op_9_5;//exp12
    wire [ 4:0] rd;
    wire [ 4:0] rj;
    wire [ 4:0] rk;
    wire [11:0] i12;
    wire [19:0] i20;
    wire [15:0] i16;
    wire [25:0] i26;

    wire [63:0] op_31_26_d;
    wire [15:0] op_25_22_d;
    wire [ 3:0] op_21_20_d;
    wire [31:0] op_19_15_d;
    wire [ 3:0] op_25_24_d;
    wire [31:0] op_9_5_d;//exp12

    wire        inst_add_w;
    wire        inst_sub_w;
    wire        inst_slt;
    wire        inst_sltu;
    wire        inst_nor;
    wire        inst_and;
    wire        inst_or;
    wire        inst_xor;
    wire        inst_slli_w;
    wire        inst_srli_w;
    wire        inst_srai_w;
    wire        inst_addi_w;
    wire        inst_ld_w;
    wire        inst_ld_b;
    wire        inst_ld_h; 
    wire        inst_ld_bu;
    wire        inst_ld_hu;
    wire        inst_st_w;
    wire        inst_st_b;
    wire        inst_st_h;
    wire        inst_jirl;
    wire        inst_b;
    wire        inst_bl;
    wire        inst_beq;
    wire        inst_bne;
    wire        inst_blt;
    wire        inst_bge; 
    wire        inst_bltu;
    wire        inst_bgeu;
    wire        inst_lu12i_w;
    //calcu
    wire        inst_slti;
    wire        inst_sltui;
    wire        inst_andi;
    wire        inst_ori;
    wire        inst_xori;
    wire        inst_sll_w;
    wire        inst_srl_w;
    wire        inst_sra_w;
    wire        inst_pcaddu12i;
    //mul
    wire        inst_mul_w;
    wire        inst_mulh_w;
    wire        inst_mulh_wu;
    wire        inst_div_w;
    wire        inst_mod_w;
    wire        inst_div_wu;
    wire        inst_mod_wu;
    
    //csr exp12
    wire        inst_csrrd;
    wire        inst_csrwr;
    wire        inst_csrxchg;
    wire        inst_ertn;
    wire        inst_syscall;
    
    //exp13
    wire        inst_break;
    wire        inst_rdcntid;
    wire        inst_rdcntvl;
    wire        inst_rdcntvh;

    wire        need_ui5;
    wire        need_si12;
    wire        need_si16;
    wire        need_si20;
    wire        need_si26;
    wire        need_ui12;
    wire        src2_is_4;

    wire [ 4:0] rf_raddr1;
    wire [31:0] rf_rdata1;
    wire [ 4:0] rf_raddr2;
    wire [31:0] rf_rdata2;
    wire        rf_we   ;
    wire [ 4:0] rf_waddr;
    wire [31:0] rf_wdata;

    wire [31:0] alu_src1   ;
    wire [31:0] alu_src2   ;

    // 除法器控制信号
    wire        id_div_en;       // 是否使用除法器
    wire [2:0]  id_div_op;       // 操作类型：000 div.w, 001 mod.w, 010 div.wu, 011 mod.wu
    
    //csr exp12
    wire        id_csr_we;
    wire        id_csr_re;
    wire [13:0] id_csr_num;
    wire [31:0] id_csr_wmask;
    wire [31:0] id_csr_wvalue;

    //exception exp13
    wire        id_ine;
    wire        id_adef;
    wire        id_ecode;
    
    assign op_31_26  = id_inst[31:26];
    assign op_25_22  = id_inst[25:22];
    assign op_21_20  = id_inst[21:20];
    assign op_19_15  = id_inst[19:15];
    assign op_25_24  = id_inst[25:24];
    assign op_9_5    = id_inst[9:5];

    assign rd   = id_inst[ 4: 0];
    assign rj   = id_inst[ 9: 5];
    assign rk   = id_inst[14:10];

    assign i12  = id_inst[21:10];
    assign i20  = id_inst[24: 5];
    assign i16  = id_inst[25:10];
    assign i26  = {id_inst[ 9: 0], id_inst[25:10]};

    decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d ));
    decoder_4_16 u_dec1(.in(op_25_22 ), .out(op_25_22_d ));
    decoder_2_4  u_dec2(.in(op_21_20 ), .out(op_21_20_d ));
    decoder_5_32 u_dec3(.in(op_19_15 ), .out(op_19_15_d ));
    decoder_2_4  u_dec4(.in(op_25_24 ), .out(op_25_24_d ));
    decoder_5_32 u_dec5(.in(op_9_5   ), .out(op_9_5_d   ));//exp12

    assign inst_add_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
    assign inst_sub_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
    assign inst_slt    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
    assign inst_sltu   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
    assign inst_nor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
    assign inst_and    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
    assign inst_or     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
    assign inst_xor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];
    assign inst_slli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
    assign inst_srli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
    assign inst_srai_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
    assign inst_addi_w = op_31_26_d[6'h00] & op_25_22_d[4'ha];
    assign inst_ld_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
    assign inst_ld_b   = op_31_26_d[6'h0a] & op_25_22_d[4'h0];
    assign inst_ld_h   = op_31_26_d[6'h0a] & op_25_22_d[4'h1];
    assign inst_ld_bu  = op_31_26_d[6'h0a] & op_25_22_d[4'h8];
    assign inst_ld_hu  = op_31_26_d[6'h0a] & op_25_22_d[4'h9];
    assign inst_st_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
    assign inst_st_b   = op_31_26_d[6'h0a] & op_25_22_d[4'h4];
    assign inst_st_h   = op_31_26_d[6'h0a] & op_25_22_d[4'h5];
    assign inst_jirl   = op_31_26_d[6'h13];
    assign inst_b      = op_31_26_d[6'h14];
    assign inst_bl     = op_31_26_d[6'h15];
    assign inst_beq    = op_31_26_d[6'h16];
    assign inst_bne    = op_31_26_d[6'h17];
    assign inst_blt  = op_31_26_d[6'h18];  
    assign inst_bge  = op_31_26_d[6'h19];   
    assign inst_bltu = op_31_26_d[6'h1a];  
    assign inst_bgeu = op_31_26_d[6'h1b]; 
    assign inst_lu12i_w= op_31_26_d[6'h05] & ~id_inst[25];
    //calcu
    assign inst_slti   = op_31_26_d[6'h00] & op_25_22_d[4'h8];
    assign inst_sltui  = op_31_26_d[6'h00] & op_25_22_d[4'h9];
    assign inst_andi   = op_31_26_d[6'h00] & op_25_22_d[4'hd];
    assign inst_ori    = op_31_26_d[6'h00] & op_25_22_d[4'he];
    assign inst_xori   = op_31_26_d[6'h00] & op_25_22_d[4'hf];
    assign inst_sll_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0e];
    assign inst_srl_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0f];
    assign inst_sra_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h10];
    assign inst_pcaddu12i= op_31_26_d[6'h07] & ~id_inst[25];
    //mul
    assign inst_mul_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h18];
    assign inst_mulh_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h19];
    assign inst_mulh_wu= op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h1a];
    assign inst_div_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h00];
    assign inst_mod_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h01];
    assign inst_div_wu = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h02];
    assign inst_mod_wu = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h03];
    //csr exp12
    assign inst_csrrd  = op_31_26_d[6'h01] & op_25_24_d[2'h0] & op_9_5_d[5'h0];
    assign inst_csrwr  = op_31_26_d[6'h01] & op_25_24_d[2'h0] & op_9_5_d[5'h1];
    assign inst_csrxchg= op_31_26_d[6'h01] & op_25_24_d[2'h0] & ~op_9_5_d[5'h0] & ~op_9_5_d[5'h1];
    assign inst_ertn   = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & id_inst[14:10] == 5'b01110;
    assign inst_syscall= op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h16];
    //exp13
    assign inst_break  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h14];
    assign inst_rdcntid= op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & (rk == 5'h18) & (rd == 5'h00);
    assign inst_rdcntvl= op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & (rk == 5'h18) & (rj == 5'h00);
    assign inst_rdcntvh= op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & (rk == 5'h19) & (rj == 5'h00);
    
    assign alu_op[ 0] = inst_add_w | inst_addi_w
                      | inst_ld_w | inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu  
                      | inst_st_w | inst_st_b | inst_st_h
                      | inst_jirl | inst_bl | inst_pcaddu12i;
    assign alu_op[ 1] = inst_sub_w;
    assign alu_op[ 2] = inst_slt | inst_slti;
    assign alu_op[ 3] = inst_sltu | inst_sltui;
    assign alu_op[ 4] = inst_and | inst_andi;
    assign alu_op[ 5] = inst_nor;
    assign alu_op[ 6] = inst_or | inst_ori;
    assign alu_op[ 7] = inst_xor | inst_xori;
    assign alu_op[ 8] = inst_slli_w | inst_sll_w;
    assign alu_op[ 9] = inst_srli_w | inst_srl_w;
    assign alu_op[10] = inst_srai_w | inst_sra_w;
    assign alu_op[11] = inst_lu12i_w;
    
    // ALU expansion
    assign alu_op[12] = inst_mul_w;
    assign alu_op[13] = inst_mulh_w;
    assign alu_op[14] = inst_mulh_wu;

    //除法器调用
    assign id_div_en =  inst_div_w | inst_mod_w | inst_div_wu | inst_mod_wu;
    assign id_div_op =  inst_div_w  ? 3'b000 :
                        inst_mod_w  ? 3'b001 :
                        inst_div_wu ? 3'b010 :
                        inst_mod_wu ? 3'b011 : 3'b111;


    assign need_ui5   =  inst_slli_w | inst_srli_w | inst_srai_w;
    assign need_si12  =  inst_addi_w | inst_ld_w | inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu
                       | inst_st_w | inst_st_b | inst_st_h | inst_slti | inst_sltui;
    assign need_si16  =  inst_jirl | inst_beq | inst_bne;
    assign need_si20  =  inst_lu12i_w | inst_pcaddu12i;
    assign need_si26  =  inst_b | inst_bl;
    assign need_ui12  =  inst_andi | inst_ori | inst_xori;
    assign src2_is_4  =  inst_jirl | inst_bl;

    assign imm = src2_is_4 ? 32'h4                      :
                need_si20 ? {i20[19:0], 12'b0}          :
                need_ui5  ? {27'b0,rk[4:0]}             :   
                need_si12 ? {{20{i12[11]}}, i12[11:0]}  : 
                need_ui12 ? {20'b0,i12[11:0]}           :
                32'b0 ;

    assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :
                                {{14{i16[15]}}, i16[15:0], 2'b0} ;

    assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};

    assign src_reg_is_rd = inst_beq | inst_bne | inst_st_w | inst_st_b | inst_st_h | inst_blt | inst_bge | inst_bltu | inst_bgeu | inst_csrrd | inst_csrwr | inst_csrxchg;

    assign src1_is_pc    = inst_jirl | inst_bl | inst_pcaddu12i;

    assign src2_is_imm   = inst_slli_w |
                        inst_srli_w |
                        inst_srai_w |
                        inst_addi_w |
                        inst_ld_w   |
                        inst_ld_b   |
                        inst_ld_h   |
                        inst_ld_bu  |
                        inst_ld_hu  |
                        inst_st_w   |
                        inst_st_b   |
                        inst_st_h   |
                        inst_lu12i_w|
                        inst_jirl   |
                        inst_bl     |
                        inst_slti   |
                        inst_sltui  |
                        inst_andi   |
                        inst_ori    |
                        inst_xori   |   
                        inst_pcaddu12i;
                        
    assign res_from_mem  = inst_ld_w | inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu;
    assign dst_is_r1     = inst_bl;
    assign dst_is_rj     = inst_rdcntid;
    assign id_gr_we      = ~inst_st_w & ~inst_st_b & ~inst_st_h & ~inst_beq & ~inst_bne & ~inst_b &
                       ~inst_blt & ~inst_bge & ~inst_bltu & ~inst_bgeu;
    assign id_dest       = dst_is_r1 ? 5'd1 :
                           dst_is_rj ? rj   : rd;

    assign rf_raddr1 = rj;
    assign rf_raddr2 = src_reg_is_rd ? rd :rk;
    assign {
           rf_we, rf_waddr, rf_wdata, wb_csr
           } = wb_id_bus;
    regfile u_regfile(
        .clk    (clk      ),
        .raddr1 (rf_raddr1),
        .rdata1 (rf_rdata1),
        .raddr2 (rf_raddr2),
        .rdata2 (rf_rdata2),
        .we     (rf_we    ),
        .waddr  (rf_waddr ),
        .wdata  (rf_wdata )
        );

    assign rj_value  = (ex_bypass  & ( ex_dest  == rf_raddr1 )& need_addr1 & (rf_raddr1 != 0)) ? ex_wdata  :
                       (mem_bypass & ( mem_dest == rf_raddr1 )& need_addr1 & (rf_raddr1 != 0)) ? mem_wdata :
                       (rf_we      & ( rf_waddr == rf_raddr1 )& need_addr1 & (rf_raddr1 != 0)) ? rf_wdata  : rf_rdata1;
    assign rkd_value = (ex_bypass  & ( ex_dest  == rf_raddr2 )& need_addr2 & (rf_raddr2 != 0)) ? ex_wdata  :
                       (mem_bypass & ( mem_dest == rf_raddr2 )& need_addr2 & (rf_raddr2 != 0)) ? mem_wdata :
                       (rf_we      & ( rf_waddr == rf_raddr2 )& need_addr2 & (rf_raddr2 != 0)) ? rf_wdata  : rf_rdata2;
    assign rj_lt_rd_signed   = $signed(rj_value) < $signed(rkd_value);
    assign rj_ge_rd_signed   = $signed(rj_value) >= $signed(rkd_value);
    assign rj_lt_rd_unsigned = rj_value < rkd_value;  // 无符号比较就是直接比较
    assign rj_ge_rd_unsigned = rj_value >= rkd_value;


    assign rj_eq_rd = (rj_value == rkd_value);
    assign br_taken = (   inst_beq  &&  rj_eq_rd
                   || inst_bne  && !rj_eq_rd
                   || inst_blt  &&  rj_lt_rd_signed    
                   || inst_bge  &&  rj_ge_rd_signed    
                   || inst_bltu &&  rj_lt_rd_unsigned  
                   || inst_bgeu &&  rj_ge_rd_unsigned  
                   || inst_jirl
                   || inst_bl
                   || inst_b
                  ) & id_valid;

    assign br_target = (inst_beq || inst_bne || inst_bl || inst_b||inst_blt || inst_bge || inst_bltu || inst_bgeu) ? (id_pc + br_offs) :
                                                    /*inst_jirl*/ (rj_value + jirl_offs);
    assign alu_src1 = src1_is_pc  ? id_pc : rj_value;
    assign alu_src2 = src2_is_imm ? imm : rkd_value;
    //csr exp12
    assign id_csr_re  = inst_csrrd | inst_csrwr | inst_csrxchg | inst_rdcntid ;
    assign id_csr_we  = inst_csrwr | inst_csrxchg;
    assign id_csr_num = inst_rdcntid ? 14'H40 : id_inst[23:10];
    assign id_csr_wmask  = inst_csrxchg ? rj_value : 32'hffffffff;
    assign id_csr_wvalue = rkd_value;
    assign id_syscall_ex = inst_syscall & id_valid;
    //修改：增加除法器传递信号
    assign id_ex_bus = {
        id_gr_we, inst_st_w, inst_st_b, inst_st_h, res_from_mem, mem_type,
        alu_op, id_div_en, id_div_op,alu_src1, alu_src2,
        id_dest, rkd_value, id_inst, id_pc , id_csr_we, id_csr_re, id_csr_num, id_csr_wmask, id_csr_wvalue, 
        inst_ertn, id_syscall_ex, inst_rdcntvl, inst_rdcntvh
    };

    assign id_if_bus = {
        br_taken & id_ready_go , br_target
    };
    
    //csr_block
    wire csr_block;
    assign csr_block = ((id_csr_re|id_csr_we)&
                      ((ex_csr  & ex_gr_we  & (ex_csr_num == id_csr_num))
                    || (mem_csr & mem_gr_we & (mem_csr_num == id_csr_num)))
                    || (ex_csr  & (ex_gr_we & ((ex_dest == rf_raddr1) & need_addr1 & (rf_raddr1 != 0)
                                            || (ex_dest == rf_raddr2) & need_addr2 & (rf_raddr2 != 0))))
                    || (mem_csr & (mem_gr_we &((mem_dest == rf_raddr1) & need_addr1 & (rf_raddr1 != 0)
                                             || (mem_dest == rf_raddr2) & need_addr2 & (rf_raddr2 != 0))))
                    || (wb_csr & (rf_we &((rf_waddr == rf_raddr1) & need_addr1 & (rf_raddr1 != 0)
                                       || (rf_waddr == rf_raddr2) & need_addr2 & (rf_raddr2 != 0)))));

    assign csr_unblock = 
            (ex_csr  & ex_gr_we  & (ex_csr_num  == id_csr_num)) ||
            (mem_csr & mem_gr_we & (mem_csr_num == id_csr_num)) ||
            (wb_csr  & rf_we     & (rf_waddr    == id_csr_num));

    assign block_not = csr_unblock || 
                    (rf_we & (rf_waddr != 0) & 
                      ((ex_dest == rf_raddr1) &( need_addr1 & (rf_raddr1 != 0) & (rf_waddr == rf_raddr1)) |
                      (ex_dest == rf_raddr2) & (need_addr2 & (rf_raddr2 != 0) & (rf_waddr == rf_raddr2))));
    
    reg block_not_prev;  // 记录上一拍的block_not状态
    
    wire csr_unblock;

    always @(posedge clk) begin
        if (~resetn) begin
            block_not_prev <= 1'b0;
        end else begin
            block_not_prev <= block_not;
        end
    end
    assign id_ready_go =  ertn_flush ? 1'b1 :
                        ~( (ex_ld & 
                         ((ex_dest == rf_raddr1) & need_addr1 & (rf_raddr1 != 0) | 
                          (ex_dest == rf_raddr2) & need_addr2 & (rf_raddr2 != 0)))
                         | ex_div_busy | csr_block)|block_not_prev;  // 只要 EX 报 busy，就阻塞 ID 发射
    assign need_addr1   = inst_add_w | inst_sub_w | inst_slt | inst_addi_w | inst_sltu | inst_nor | 
                          inst_and | inst_or | inst_xor | inst_srli_w | inst_slli_w | inst_srai_w | 
                          inst_ld_w | inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu |
                          inst_st_w | inst_st_b | inst_st_h | inst_bne  | inst_beq | inst_jirl |inst_blt | inst_bge | inst_bltu | inst_bgeu|
                          inst_slti | inst_sltui | inst_andi | inst_ori | inst_xori | 
                          inst_sll_w | inst_srl_w |inst_sra_w | inst_pcaddu12i| inst_mul_w | inst_mulh_w | inst_mulh_wu|
                          inst_div_w | inst_mod_w | inst_div_wu | inst_mod_wu| inst_csrxchg;
    assign need_addr2   = inst_add_w | inst_sub_w | inst_slt | inst_sltu | inst_and | inst_or | inst_nor | 
                          inst_xor | inst_st_w | inst_st_b | inst_st_h |
                          inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu|inst_sll_w | inst_srl_w | inst_sra_w|
                          inst_mul_w | inst_mulh_w | inst_mulh_wu| inst_div_w | inst_mod_w | inst_div_wu | inst_mod_wu | inst_csrrd | inst_csrwr | inst_csrxchg;

    //指令不存在
    assign id_ine = ~ ( inst_add_w     | inst_sub_w   | inst_slt     | inst_sltu      |
                        inst_nor       | inst_and     | inst_or      | inst_xor       |   
                        inst_slli_w    | inst_srli_w  | inst_srai_w  | inst_addi_w    | 
                        inst_ld_w      | inst_st_w    | inst_jirl    | inst_b         |
                        inst_bl        | inst_beq     | inst_bne     | inst_lu12i_w   |
                        inst_slti      | inst_sltui   | inst_andi    | inst_ori       | 
                        inst_xori      | inst_sll_w   | inst_srl_w   | inst_sra_w     |
                        inst_mul_w     | inst_mulh_w  | inst_mulh_wu | inst_div_w     | 
                        inst_mod_w     | inst_div_wu  | inst_mod_wu  | inst_pcaddu12i |
                        inst_blt       | inst_bge     | inst_bltu    | inst_bgeu      | 
                        inst_ld_b      | inst_ld_h    | inst_ld_bu   | inst_ld_hu     |
                        inst_st_b      | inst_st_h    | inst_csrrd   | inst_csrwr     |
                        inst_csrxchg   | inst_ertn    | inst_syscall | inst_break     |
                        inst_rdcntvl   | inst_rdcntvh | inst_rdcntid );

    assign id_ex = id_valid & (inst_syscall | inst_break | id_ine | id_has_int | id_adef);
    assign id_ecode = id_has_int   ? `ECODE_INT
                    : id_adef      ? `ECODE_ADE
                    : id_ine       ? `ECODE_INE
                    : inst_break   ? `ECODE_BRK
                    : inst_syscall ? `ECODE_SYS : 6'b0;
endmodule