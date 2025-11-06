module IF (
    input           clk,
    input           resetn,
    
    input           id_allowin,
    
    output          if_id_valid,
    output  [96:0]  if_id_bus,
    input   [32:0]  id_if_bus,
    input           wb_ex,
    
    output          inst_sram_en,
    output  [3:0]   inst_sram_we,
    output  [31:0]  inst_sram_addr,
    output  [31:0]  inst_sram_wdata,
    input   [31:0]  inst_sram_rdata,

    input           ertn_flush,
    input   [31:0]  ex_entry,
    input   [31:0]  ertn_entry
);
    reg             if_valid;
    wire            if_ready_go;
    wire            if_allowin;
    wire            if_br_taken;
    reg     [31:0]  if_pc;
    wire    [31:0]  if_inst;
    wire    [31:0]  if_nextpc;
    wire    [31:0]  br_target;
    wire    [31:0]  seq_pc;
    wire            if_adef;
    wire    [31:0]  if_wrong_addr;

    assign  if_ready_go = 1'b1;
    assign  if_allowin = ~resetn | if_ready_go & id_allowin |ertn_flush |wb_ex;
    always @(posedge clk ) begin
        if(~resetn )begin
            if_valid <= 1'b0;
        end
        else if(if_allowin)begin
            if_valid <= 1'b1;
        end
        else if(if_br_taken)begin
            if_valid <= 1'b0;
        end
    end
    assign  if_id_valid = if_ready_go & if_valid & ~ertn_flush & ~wb_ex; 
    assign  if_id_bus = {if_adef,if_wrong_addr,if_pc, if_inst};

    assign  seq_pc = if_pc + 3'h4;
    assign  { if_br_taken, br_target } = id_if_bus;
    assign  if_nextpc = wb_ex? ex_entry:
                 if_br_taken ? br_target :
                 ertn_flush  ? ertn_entry:seq_pc;
    assign if_adef = if_nextpc[1] | if_nextpc[0];

    always @(posedge clk ) begin
        if(~resetn)begin
            if_pc <= 32'h1bfffffc;
        end
        else if(if_allowin)begin
            if_pc <= if_nextpc;
        end
    end

    assign  if_wrong_addr = if_nextpc;
    
    assign  inst_sram_en = if_allowin | ertn_flush;
    assign  inst_sram_addr = if_nextpc;
    assign  if_inst = inst_sram_rdata;
    assign  inst_sram_we = 4'b0;
    assign  inst_sram_wdata = 32'b0;
endmodule