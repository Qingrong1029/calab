module transfer_axi_bridge(
    input wire         clk    ,
    input wire         resetn ,
 
    // ar 
    output wire    [ 3:0] arid   ,
    output wire    [31:0] araddr ,
    output wire    [ 7:0] arlen  , 
    output wire    [ 2:0] arsize , 
    output wire    [ 1:0] arburst, 
    output wire    [ 1:0] arlock , 
    output wire    [ 3:0] arcache, 
    output wire    [ 2:0] arprot ,
    output wire           arvalid, 
    input  wire           arready,

    // r
    input  wire    [ 3:0] rid   , 
    input  wire    [31:0] rdata , 
    input  wire    [ 1:0] rresp , 
    input  wire           rlast , 
    input  wire           rvalid,
    output wire           rready, 

    // aw
    output wire    [ 3:0] awid   ,
    output wire    [31:0] awaddr , 
    output wire    [ 7:0] awlen  ,
    output wire    [ 2:0] awsize ,
    output wire    [ 1:0] awburst,
    output wire    [ 1:0] awlock , 
    output wire    [ 3:0] awcache,
    output wire    [ 2:0] awprot , 
    output wire           awvalid,
    input  wire           awready, 

    // w
    output wire    [ 3:0] wid   , 
    output wire    [31:0] wdata , 
    output wire    [ 3:0] wstrb , 
    output wire           wlast , 
    output wire           wvalid,
    input  wire           wready, 
 
    // b 
    input  wire   [ 3:0] bid   , 
    input  wire   [ 1:0] bresp ,  
    input  wire          bvalid, 
    output wire          bready, 

    // inst sram interface    
    input  wire          inst_sram_en    ,
    input  wire          inst_sram_wr     ,
    input  wire   [ 1:0] inst_sram_size   ,
    input  wire   [ 3:0] inst_sram_wstrb  ,
    input  wire   [31:0] inst_sram_addr   ,
    input  wire   [31:0] inst_sram_wdata  ,
    output wire   [31:0] inst_sram_rdata  ,
    output wire          inst_sram_addr_ok,
    output wire          inst_sram_data_ok,
    
    // data sram interface
    input  wire          data_sram_en    ,
    input  wire          data_sram_wr     ,
    input  wire   [ 3:0] data_sram_wstrb  ,
    input  wire   [ 1:0] data_sram_size   , 
    input  wire   [31:0] data_sram_addr   ,
    input  wire   [31:0] data_sram_wdata  ,
    output wire   [31:0] data_sram_rdata  ,
    output wire          data_sram_addr_ok,
    output wire          data_sram_data_ok
);
    // ar
    reg  [3:0] arid_reg;
    reg [31:0] araddr_reg;
    reg  [2:0] arsize_reg;
    reg        arvalid_reg;   
    // aw
    reg [31:0] awaddr_reg;
    reg [2:0]  awsize_reg;
    reg        awvalid_reg;  
    // w
    reg [31:0] wdata_reg;
    reg [3:0]  wstrb_reg;
    reg        wvalid_reg;
    //b
    reg bready_reg;


    // ar
    assign arid = arid_reg;
    assign araddr = araddr_reg;
    assign arsize = arsize_reg;
    assign arvalid = arvalid_reg;
    assign arlen    = 8'b0;
    assign arburst  = 2'b01;
    assign arlock   = 2'b0;
    assign arcache  = 4'b0;
    assign arprot   = 3'b0;
    // r
    assign rready = r_business_cnt_inst != 2'b0 || r_business_cnt_data != 2'b0;
    // aw
    assign awaddr = awaddr_reg;
    assign awsize = awsize_reg;
    assign awvalid = awvalid_reg;
    assign awid     = 4'b1;
    assign awlen    = 8'b0;
    assign awburst  = 2'b01;
    assign awlock   = 2'b0;
    assign awcache  = 4'b0;
    assign awprot   = 3'b0;
    // w
    assign wdata = wdata_reg;
    assign wstrb = wstrb_reg;
    assign wvalid = wvalid_reg;
    assign wid      = 4'b1;
    assign wlast    = 1'b1;
    // b
    assign bready = bready_reg;

    //block signal
    wire block;
    assign block = (awaddr == araddr) && awvalid && arvalid;

    //FSM
    parameter READ_REQ_RST          = 5'b00001;
    parameter READ_DATA_REQ_START   = 5'b00010;
    parameter READ_INST_REQ_START   = 5'b00100;
    parameter READ_DATA_REQ_CHECK   = 5'b01000;
    parameter READ_REQ_END          = 5'b10000;
    reg  [ 4:0] rreq_cur_state;
    reg  [ 4:0] rreq_next_state;

    parameter READ_DATA_RST         = 3'b001;
    parameter READ_DATA_START       = 3'b010;
    parameter READ_DATA_END         = 3'b100;
    reg  [ 2:0] rdata_cur_state;
    reg  [ 2:0] rdata_next_state;

    parameter WRITE_RST             = 4'b0001;
    parameter WRITE_CHECK           = 4'b0010;
    parameter WRITE_START           = 4'b0100;
    parameter WRITE_END             = 4'b1000;
    reg  [ 3:0] wrd_cur_state;
    reg  [ 3:0] wrd_next_state;


    parameter WRITE_RSP_RST         = 3'b001;
    parameter WRITE_RSP_START       = 3'b010;
    parameter WRITE_RSP_END         = 3'b100;
    reg  [ 2:0] wrsp_cur_state;
    reg  [ 2:0] wrsp_next_state;

    reg [1:0] r_business_cnt_inst;
    reg [1:0] r_business_cnt_data;
    reg [1:0] w_business_cnt;

    // FSM state transition
    always @(posedge clk) begin
        if(!resetn) begin
            rreq_cur_state  <= READ_REQ_RST;
            rdata_cur_state <= READ_DATA_RST;
            wrd_cur_state   <= WRITE_RST;
            wrsp_cur_state  <= WRITE_RSP_RST;
        end    
        else begin
            rreq_cur_state  <= rreq_next_state;
            rdata_cur_state <= rdata_next_state;
            wrd_cur_state   <= wrd_next_state;
            wrsp_cur_state  <= wrsp_next_state;
        end 
    end


    //read
    //read request FSM
    always @(*) begin
         case(rreq_cur_state)
            READ_REQ_RST: begin
                if(data_sram_en & ~data_sram_wr)
                    rreq_next_state = READ_DATA_REQ_CHECK;
                else if(inst_sram_en)
                    rreq_next_state = READ_INST_REQ_START;
                else
                    rreq_next_state = rreq_cur_state;
            end           
            READ_DATA_REQ_CHECK: begin
                if(bready & block) // wait for write response
                    rreq_next_state = rreq_cur_state;
                else
                    rreq_next_state = READ_DATA_REQ_START;
            end
            READ_DATA_REQ_START, READ_INST_REQ_START: begin
                if(arvalid & arready)
                    rreq_next_state = READ_REQ_END;
                else
                    rreq_next_state = rreq_cur_state;
            end           
            READ_REQ_END: begin
                rreq_next_state = READ_REQ_RST;
            end
            default:
                rreq_next_state = READ_REQ_RST;
        endcase
    end

    // read data FSM
    always @(*) begin
            case(rdata_cur_state)
                READ_DATA_RST: begin
                    if((arready && arvalid) || r_business_cnt_inst != 2'b0 || r_business_cnt_data != 2'b0) // exists unaddressed read business
                        rdata_next_state = READ_DATA_START;
                    else
                        rdata_next_state = rdata_cur_state;
                end           
                READ_DATA_START: begin
                    if(rvalid & rready)
                        rdata_next_state = READ_DATA_END;
                    else
                        rdata_next_state = rdata_cur_state;
                end           
                READ_DATA_END: begin
                    if(rvalid & rready)
                        rdata_next_state = rdata_cur_state;
                    else if(r_business_cnt_inst != 2'b0 || r_business_cnt_data != 2'b0)
                        rdata_next_state = READ_DATA_START;
                    else
                        rdata_next_state = READ_DATA_RST;
                end
                default:
                    rdata_next_state = READ_DATA_RST;
            endcase
    end

    //other AXI signal assignments
    //ar
    always @(posedge clk) begin
        if(!resetn) begin
            arid_reg     <= 4'b0;
            araddr_reg   <= 32'b0;
            arsize_reg   <= 3'b0;
        end
        else if(rreq_next_state == READ_DATA_REQ_START || rreq_cur_state == READ_DATA_REQ_START) begin
            arid_reg    <= 4'b0;
            araddr_reg  <= data_sram_addr;
            arsize_reg  <= {1'b0, data_sram_size};
        end
        else if(rreq_next_state == READ_INST_REQ_START || rreq_cur_state == READ_INST_REQ_START) begin
            arid_reg    <= 4'b0;
            araddr_reg  <= inst_sram_addr;
            arsize_reg  <= {1'b0, inst_sram_size};
        end
        else begin
            arid_reg     <= 4'b0;
            araddr_reg   <= 32'b0;
            arsize_reg   <= 3'b0;
        end
    end

    //ar valid
    always @(posedge clk) begin
        if(!resetn)
            arvalid_reg <= 1'b0;
        else if(rreq_next_state == READ_DATA_REQ_START || rreq_cur_state == READ_DATA_REQ_START)
            arvalid_reg <= 1'b1;
        else if(arvalid & arready)
            arvalid_reg <= 1'b0;
    end

    //rid
    reg [3:0] rid_reg;
    always @(posedge clk) begin
        if(!resetn || rdata_next_state == READ_DATA_RST)
            rid_reg <= 4'b0;
        else if(rvalid & rready)
            rid_reg <= rid;
    end

    //counters
    //r read business counter
    always @(posedge clk) begin
        if(!resetn) begin
            r_business_cnt_inst <= 2'b0;
            r_business_cnt_data <= 2'b0;
        end
        else if(arready & arvalid & rvalid & rready) begin
            if(~arid[0] && ~rid[0]) begin
                r_business_cnt_inst <= r_business_cnt_inst;
            end else if(~arid[0] && rid[0]) begin
                r_business_cnt_inst <= r_business_cnt_inst + 2'b1;
                r_business_cnt_data <= r_business_cnt_data - 2'b1;
            end else if(arid[0] && ~rid[0]) begin
                r_business_cnt_inst <= r_business_cnt_inst - 2'b1;
                r_business_cnt_data <= r_business_cnt_data + 2'b1;
            end else if(arid[0] && rid[0]) begin
                r_business_cnt_data <= r_business_cnt_data;
            end
        end
        else if(arready & arvalid) begin
            if(~arid[0]) begin
                r_business_cnt_inst <= r_business_cnt_inst + 2'b1;
            end else begin
                r_business_cnt_data <= r_business_cnt_data + 2'b1;
            end
        end
        else if(rvalid & rready) begin
            if(~rid[0]) begin
                r_business_cnt_inst <= r_business_cnt_inst - 2'b1;
            end else begin
                r_business_cnt_data <= r_business_cnt_data - 2'b1;
            end
        end
    end


    //write
    //write request FSM
    always @(*) begin
            case(wrd_cur_state)
                WRITE_RST: begin
                    if(data_sram_en & data_sram_wr)
                        wrd_next_state = WRITE_CHECK;
                    else
                        wrd_next_state = wrd_cur_state;
                end           
                WRITE_CHECK: begin
                    if(rready & block) // wait for write response
                        wrd_next_state = wrd_cur_state;
                    else
                        wrd_next_state = WRITE_START;
                end           
                WRITE_START: begin
                    if(wvalid & wready)
                        wrd_next_state = WRITE_END;
                    else
                        wrd_next_state = wrd_cur_state;
                end           
                WRITE_END: begin
                    wrd_next_state = WRITE_RST;
                end
                default:
                    wrd_next_state = WRITE_RST;
            endcase
    end

    // write response FSM
    always @(*) begin
        case(wrsp_cur_state)
            WRITE_RSP_RST: begin
                if(wvalid & wready) 
                    wrsp_next_state = WRITE_RSP_START;
                else
                    wrsp_next_state = wrsp_cur_state;
            end
            WRITE_RSP_START: begin
                if(bvalid & bready)
                    wrsp_next_state = WRITE_RSP_END;
                else
                    wrsp_next_state = wrsp_cur_state;
            end
            WRITE_RSP_END: begin
                if(bvalid & bready)
                    wrsp_next_state = wrsp_cur_state;
                else if(wvalid & wready || w_business_cnt != 2'b0)
                    wrsp_next_state = WRITE_RSP_START;
                else
                    wrsp_next_state = WRITE_RSP_RST;
            end
            default:
                wrsp_next_state = WRITE_RSP_RST;
        endcase
    end

    //other AXI signal assignments
    //aw
    always @(posedge clk) begin
        if(!resetn) begin
            awaddr_reg   <= 32'b0;
            awsize_reg   <= 3'b0;
        end
        else if(wrd_next_state == WRITE_START || wrd_cur_state == WRITE_START) begin
            awaddr_reg  <= data_sram_addr;
            awsize_reg  <= {1'b0, data_sram_size};
        end
        else begin
            awaddr_reg   <= 32'b0;
            awsize_reg   <= 3'b0;
        end
    end

    //wr transport
    reg wr_transport;
    always @(posedge clk) begin
        if(!resetn)
            wr_transport <= 1'b0;
        else if(awvalid && awready)
            wr_transport <= 1'b1;
        else if(wrd_next_state == WRITE_END || wrd_cur_state == WRITE_END)
            wr_transport <= 1'b0;
    end

    //aw valid
    always @(posedge clk) begin
        if(!resetn)
            awvalid_reg <= 1'b0;
        else if(wrd_cur_state == WRITE_START)
            awvalid_reg <= 1'b1;
        else if(awvalid & (awready | wr_transport))
            awvalid_reg <= 1'b0;
    end

    //w data
    always @(posedge clk) begin
        if(!resetn) begin
            wdata_reg <= 32'b0;
            wstrb_reg <= 4'b0;
        end
        else if(wrd_cur_state == WRITE_START || wrd_next_state == WRITE_START) begin
            wdata_reg <= data_sram_wdata;
            wstrb_reg <= data_sram_wstrb;
        end
        else begin
            wdata_reg <= 32'b0;
            wstrb_reg <= 4'b0;
        end
    end

    //w valid
    always @(posedge clk) begin
        if(!resetn)
            wvalid_reg <= 1'b0;
        else if(wrd_cur_state == WRITE_START)
            wvalid_reg <= 1'b1;
        else if(wvalid & wready)
            wvalid_reg <= 1'b0;
    end

    //b ready
    always @(posedge clk) begin
        if(!resetn)
            bready_reg <= 1'b0;
        else if(wrsp_cur_state == WRITE_RSP_START)
            bready_reg <= 1'b1;
        else if(bvalid & bready)
            bready_reg <= 1'b0;
    end

    //counters
    //w write business counter
    always @(posedge clk) begin
        if(!resetn) begin
            w_business_cnt <= 2'b0;
        end
        else if(wvalid & wready & bvalid & bready) begin
            w_business_cnt <= w_business_cnt;
        end
        else if(wvalid & wready) begin
            w_business_cnt <= w_business_cnt + 2'b1;
        end
        else if(bvalid & bready) begin
            w_business_cnt <= w_business_cnt - 2'b1;
        end
    end


    //sram addr/data ok signals
    assign inst_sram_addr_ok = rreq_cur_state == READ_REQ_END && ~arid[0];
    assign inst_sram_data_ok = rdata_cur_state == READ_DATA_END && ~rid_reg[0];
    assign data_sram_addr_ok = (rreq_cur_state == READ_REQ_END && arid[0]) || (wrd_cur_state == WRITE_END); //read or write
    assign data_sram_data_ok = (rdata_cur_state == READ_DATA_END && rid_reg[0]) || (wrsp_cur_state == WRITE_RSP_END); //read or write

    //sram data output
    reg [31:0] inst_sram_rdata_reg;
    reg [31:0] data_sram_rdata_reg;
    assign inst_sram_rdata = inst_sram_rdata_reg;
    assign data_sram_rdata = data_sram_rdata_reg;

    always @(posedge clk) begin
        if(!resetn) begin
            inst_sram_rdata_reg <= 32'b0;
            data_sram_rdata_reg <= 32'b0;
        end
        else if(rvalid && rready) begin
            if(~rid_reg[0])
                inst_sram_rdata_reg <= rdata;
            else
                data_sram_rdata_reg <= rdata;
        end
    end


endmodule
