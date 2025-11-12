module IF (
    input           clk,
    input           resetn,
    
    input           id_allowin,
    
    output          if_id_valid,
    output  [96:0]  if_id_bus,
    input   [33:0]  id_if_bus,
    input           wb_ex,
    
    output          inst_sram_req,
    output          inst_sram_wr,
    output  [ 1:0]  inst_sram_size,
    output  [ 3:0]  inst_sram_wstrb,
    output  [31:0]  inst_sram_addr,
    output  [31:0]  inst_sram_wdata,
    input           inst_sram_addr_ok,
    input           inst_sram_data_ok,
    input   [31:0]  inst_sram_rdata,

    input           ertn_flush,
    input   [31:0]  ex_entry,
    input   [31:0]  ertn_entry
);
    reg             if_valid;
    wire            if_ready_go;
    wire            pre_if_ready_go;
    wire            if_allowin;
    wire            if_br_taken;
    wire            br_stall;
    reg     [31:0]  if_pc;
    wire    [31:0]  if_inst;
    wire    [31:0]  if_nextpc;
    wire    [31:0]  br_target;
    wire    [31:0]  seq_pc;
    wire            if_adef;
    wire    [31:0]  if_wrong_addr;
    
    reg             wb_ex_reg;
    reg             ertn_flush_reg;
    reg             br_taken_reg;
    reg     [31:0]  ex_entry_reg;
    reg     [31:0]  ertn_entry_reg;
    reg     [31:0]  br_target_reg;
    
    wire            cancel_req;
    reg             req_accepted;
    reg     [31:0]  accepted_addr;
    reg     [31:0]  inst_buffer;
    reg             inst_buffer_valid;
    reg             discard_next_data;
    
    assign  pre_if_ready_go = inst_sram_req & inst_sram_addr_ok;
    
    always @(posedge clk) begin
        if(~resetn) begin
            wb_ex_reg      <= 1'b0;
            ertn_flush_reg <= 1'b0;
            br_taken_reg   <= 1'b0;
            ex_entry_reg   <= 32'b0;
            ertn_entry_reg <= 32'b0;
            br_target_reg  <= 32'b0;
        end
        else if(wb_ex & ~pre_if_ready_go) begin
            ex_entry_reg <= ex_entry;
            wb_ex_reg <= 1'b1;
        end
        else if(ertn_flush & ~pre_if_ready_go) begin
            ertn_entry_reg <= ertn_entry;
            ertn_flush_reg <= 1'b1;
        end    
        else if(if_br_taken & ~pre_if_ready_go) begin
            br_target_reg <= br_target;
            br_taken_reg <= 1'b1;
        end
        else if(pre_if_ready_go) begin
            wb_ex_reg      <= 1'b0;
            ertn_flush_reg <= 1'b0;
            br_taken_reg   <= 1'b0;
        end
    end
    
    assign  seq_pc = if_pc + 3'h4;
    assign  { if_br_taken, br_target, br_stall } = id_if_bus;
    assign  if_nextpc =  wb_ex_reg       ? ex_entry_reg  : 
                         wb_ex           ? ex_entry      :
                         ertn_flush_reg  ? ertn_entry_reg: 
                         ertn_flush      ? ertn_entry    :
                         br_taken_reg    ? br_target_reg : 
                         if_br_taken     ? br_target     : seq_pc;
    
    assign  cancel_req = wb_ex | ertn_flush | if_br_taken;

    assign  if_ready_go = (inst_sram_data_ok | inst_buffer_valid ) & ~discard_next_data;
    assign  if_allowin = ~resetn | (if_ready_go & id_allowin) | cancel_req | ~if_valid;
  always @(posedge clk) begin
        if(~resetn) begin
            if_valid <= 1'b0;
        end
        else if (if_allowin) begin
            if_valid <= pre_if_ready_go;
        end
        else if (cancel_req) begin
            if_valid <= 1'b0;
        end
    end
    assign  if_id_valid =  if_valid && if_ready_go && ~cancel_req;
    assign  if_id_bus = {if_adef,if_wrong_addr,if_pc, if_inst};
       
    assign  if_adef = if_nextpc[1] | if_nextpc[0];
    assign  if_wrong_addr = if_nextpc;
    
    always @(posedge clk ) begin
        if(~resetn)begin
            if_pc <= 32'h1bfffffc;
        end
        else if(pre_if_ready_go && if_allowin)begin
            if_pc <= if_nextpc;
        end
    end
    
    always @(posedge clk) begin
        if (~resetn) begin
            discard_next_data <= 1'b0;
        end
        else if (cancel_req) begin
            if (req_accepted || (if_valid && !if_ready_go)) begin
                discard_next_data <= 1'b1;
            end
        end
        else if (inst_sram_data_ok && discard_next_data) begin
            discard_next_data <= 1'b0;
        end
    end
    
    always @(posedge clk) begin
        if (!resetn) begin
            inst_buffer_valid <= 1'b0;
            inst_buffer       <= 32'b0;
        end 
        else if (cancel_req) begin
            inst_buffer_valid <= 1'b0;
        end
        else if (inst_sram_data_ok && ~discard_next_data && ~inst_buffer_valid && ~id_allowin) begin
            inst_buffer       <= inst_sram_rdata;
            inst_buffer_valid <= 1'b1;
        end 
        else if (inst_buffer_valid && if_ready_go && id_allowin) begin
            inst_buffer       <= 32'b0;
            inst_buffer_valid <= 1'b0;
        end
    end
    
    assign  if_inst = inst_buffer_valid ? inst_buffer : inst_sram_rdata;
    
   always @(posedge clk) begin
        if (~resetn) begin
            req_accepted <= 1'b0;
            accepted_addr <= 32'b0;
        end 
        else if (cancel_req) begin
            req_accepted <= 1'b0;
        end
        else if (inst_sram_req && inst_sram_addr_ok && !req_accepted) begin
            req_accepted <= 1'b1;
            accepted_addr <= if_nextpc;
        end
        else if (req_accepted && if_allowin) begin
            req_accepted <= 1'b0;
        end
    end
    
    assign  inst_sram_req   = ~req_accepted & ~br_stall & if_allowin ;
    assign  inst_sram_addr  = if_nextpc;
    assign  inst_sram_wr    = 1'b0;
    assign  inst_sram_size  = 2'b10;
    assign  inst_sram_wstrb = 4'b0;
    assign  inst_sram_wdata = 32'b0;
endmodule