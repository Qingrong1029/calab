`define RREQ_WAIT 5'b00001
`define RREQ_INST 5'b00010
`define RREQ_TRAW 5'b00100
`define RREQ_DATA 5'b01000
`define RREQ_END  5'b10000
`define RVAL_WAIT 3'b001
`define RVAL_DATA 3'b010
`define RVAL_END  3'b100
`define WREQ_WAIT 4'b0001
`define WREQ_TRAW 4'b0010
`define WREQ_DATA 4'b0100
`define WREQ_END  4'b1000
`define WRSP_WAIT 3'b001
`define WRSP_BEGN 3'b010
`define WRSP_END  3'b100
module transfer_axi_bridge (
    input wire         aclk    ,
    input wire         aresetn ,
 
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
    input  wire          inst_sram_req   ,
    input  wire          inst_sram_wr     ,
    input  wire   [ 1:0] inst_sram_size   ,
    input  wire   [ 3:0] inst_sram_wstrb  ,
    input  wire   [31:0] inst_sram_addr   ,
    input  wire   [31:0] inst_sram_wdata  ,
    output wire   [31:0] inst_sram_rdata  ,
    output wire          inst_sram_addr_ok,
    output wire          inst_sram_data_ok,
    
    // data sram interface
    input  wire          data_sram_req   ,
    input  wire          data_sram_wr     ,
    input  wire   [ 3:0] data_sram_wstrb  ,
    input  wire   [ 1:0] data_sram_size   , 
    input  wire   [31:0] data_sram_addr   ,
    input  wire   [31:0] data_sram_wdata  ,
    output wire   [31:0] data_sram_rdata  ,
    output wire          data_sram_addr_ok,
    output wire          data_sram_data_ok
);
//读请�?
    reg     [ 4:0]      rreq_state;
    reg     [ 4:0]      rreq_next_state;
    always @(posedge aclk ) begin
        if(~aresetn)begin
            rreq_state <= `RREQ_WAIT;
        end
        else begin
            rreq_state <= rreq_next_state;
        end
    end
    always @(*) begin
        case (rreq_state)
            `RREQ_WAIT:
                if(data_sram_req && !data_sram_wr) //读数据请�?
                    rreq_next_state = `RREQ_TRAW;
                else if(inst_sram_req)
                    rreq_next_state = `RREQ_INST;
                else
                    rreq_next_state = `RREQ_WAIT;
            `RREQ_DATA:
                if(arvalid && arready)
                    rreq_next_state = `RREQ_END;
                else
                    rreq_next_state = `RREQ_DATA;
            `RREQ_INST://可以合并
                if(arvalid && arready)
                    rreq_next_state = `RREQ_END;
                else
                    rreq_next_state = `RREQ_INST;
            `RREQ_TRAW:
                if(bready && raw_blk)
                    rreq_next_state = `RREQ_TRAW;
                else
                    rreq_next_state = `RREQ_DATA;
            `RREQ_END:
                rreq_next_state = `RREQ_WAIT;
            default: 
                rreq_next_state = `RREQ_WAIT;
        endcase
    end
//读数�?
    reg     [2:0]   rval_state;
    reg     [2:0]   rval_next_state;
    always @(posedge aclk ) begin
        if(~aresetn)begin
            rval_state <= `RVAL_WAIT;
        end
        else begin
            rval_state <= rval_next_state;
        end
    end
    always @(*) begin
        case (rval_state)
            `RVAL_WAIT: 
                if((|rinst_cnt)||(|rdata_cnt)||(arready&&arvalid))
                    rval_next_state = `RVAL_DATA;
                else 
                    rval_next_state = `RVAL_WAIT;
            `RVAL_DATA:
                if(rvalid && rready)
                    rval_next_state = `RVAL_END;
                else 
                    rval_next_state = `RVAL_DATA;
            `RVAL_END:
                if(rvalid && rready)
                    rval_next_state = `RVAL_END;
                else if((|rinst_cnt)||(|rdata_cnt))
                    rval_next_state = `RVAL_DATA;
                else
                    rval_next_state = `RVAL_WAIT;
            default: 
                    rval_next_state = `RVAL_WAIT;
        endcase
    end
//写请�?
    reg     [3:0]   wreq_state;
    reg     [3:0]   wreq_next_state;
    always @(posedge aclk ) begin
        if (~aresetn) begin
            wreq_state <= `WREQ_WAIT;
        end
        else begin
            wreq_state <= wreq_next_state;
        end
    end
    always @(*) begin
        case (wreq_state)
            `WREQ_WAIT: 
                if(data_sram_req && data_sram_wr)
                    wreq_next_state = `WREQ_TRAW;
                else
                    wreq_next_state = `WREQ_WAIT;
            `WREQ_TRAW:
                if(rready && raw_blk)
                    wreq_next_state = `WREQ_TRAW;
                else 
                    wreq_next_state = `WREQ_DATA;
            `WREQ_DATA:
                if(wvalid && wready)
                    wreq_next_state = `WREQ_END;
                else
                    wreq_next_state = `WREQ_DATA;
            `WREQ_END:
                wreq_next_state = `WREQ_WAIT;
            default: 
                wreq_next_state = `WREQ_WAIT;
        endcase
    end
//写响�?
    reg     [2:0]   wrsp_state;
    reg     [2:0]   wrsp_next_state;
    always @(posedge aclk ) begin
        if(~aresetn)begin
            wrsp_state <= `WRSP_WAIT;
        end
        else begin
            wrsp_state <= wrsp_next_state;
        end
    end
    always @(*) begin
        case (wrsp_state)
            `WRSP_WAIT:
                if(wvalid && wready)
                    wrsp_next_state = `WRSP_BEGN;
                else
                    wrsp_next_state = `WRSP_WAIT;
            `WRSP_BEGN:
                if(bvalid && bready) 
                    wrsp_next_state = `WRSP_END;
                else 
                    wrsp_next_state = `WRSP_BEGN;
            `WRSP_END:
                if(bvalid && bready)
                    wrsp_next_state = `WRSP_END;
                else if((wvalid && wready) || (wtask_cnt != 2'b0))//ontest
                    wrsp_next_state = `WRSP_BEGN;
                else 
                    wrsp_next_state = `WRSP_WAIT;
            default: 
                wrsp_next_state = `WRSP_WAIT;
        endcase
    end
//ports
    //ar
    reg     [ 3:0]      arid_r;
    reg     [ 2:0]      arsize_r;
    reg     [31:0]      araddr_r;
    reg                 arvalid_r;
    assign arid = arid_r;
    assign araddr = araddr_r;
    assign arlen = 8'b0;
    assign arsize = arsize_r;
    assign arburst = 2'b1;
    assign arlock = 2'b0;
    assign arcache = 4'b0;
    assign arprot = 3'b0;
    assign arvalid = arvalid_r;
    always @(posedge aclk ) begin
        if(~aresetn)begin
            arid_r <= 4'b0;
            arsize_r <= 3'b0;
            araddr_r <= 32'b0;
        end
        else if(rreq_state[3]|rreq_next_state[3])begin
            arid_r <= 4'b1;
            arsize_r <= {1'b0,data_sram_size};
            araddr_r <= data_sram_addr;
        end
        else if(rreq_next_state[1]|rreq_state[1])begin
            arid_r <= 4'b0;
            arsize_r <= {1'b0,inst_sram_size};
            araddr_r <= inst_sram_addr;
        end
        else begin
            arid_r <= 4'b0;
            arsize_r <= 3'b0;
            araddr_r <= 32'b0;
        end
    end
    always @(posedge aclk) begin
        if(~aresetn|arready) begin
            arvalid_r <= 1'b0;
        end 
        else if(rreq_state[1]|rreq_state[3]) begin
            arvalid_r <= 1'b1;
        end 
        else begin
            arvalid_r <= arvalid_r;
        end
    end
    //r
    assign rready=rinst_cnt!=2'b0 || rdata_cnt!=2'b0;
    reg [3:0]   rid_r;
    always @(posedge aclk) begin
        if(~aresetn|rval_next_state[0]) begin
            rid_r <= 4'b0;
        end 
        else if(rvalid) begin
            rid_r <= rid;
        end
    end
    //aw
    reg     [31:0]  awaddr_r;
    reg     [ 2:0]  awsize_r;
    reg             awvalid_r;
    reg             awready_r;
    assign awid    = 4'b1;
    assign awaddr  = awaddr_r;
    assign awlen   = 8'b0;
    assign awsize  = awsize_r;
    assign awburst = 2'b01;
    assign awlock  = 2'b0;
    assign awcache = 4'b0;
    assign awprot  = 3'b0;
    assign awvalid = awvalid_r;
    always @(posedge aclk) begin
        if(~aresetn) begin
            awaddr_r <= 32'b0;
            awsize_r <= 3'b0;
        end 
        else if(wreq_state[2])begin
            awaddr_r <= data_sram_addr;
            awsize_r <= {1'b0,data_sram_size};
        end 
        else begin
            awaddr_r <= 32'b0;
            awsize_r <= 3'b0;
        end
    end
    always @(posedge aclk) begin
        if(~aresetn || awready || awready_r) begin
            awvalid_r <= 1'b0;
        end
        else if(wreq_state[2]) begin
            awvalid_r <= 1'b1;
        end
    end
    always @(posedge aclk) begin
        if(~aresetn) begin
            awready_r <= 1'b0;
        end
        else if(awvalid && awready) begin
            awready_r <= 1'b1;
        end 
        else if(wreq_next_state[3]) begin
            awready_r <= 1'b0;
        end
    end
    //w
    reg     [31:0]  wdata_r;
    reg     [ 3:0]  wstrb_r;
    reg             wvalid_r;
    assign wid     = 4'b1;
    assign wdata   = wdata_r;
    assign wstrb   = wstrb_r;
    assign wlast   = 1'b1;
    assign wvalid  = wvalid_r;
    always @(posedge aclk) begin
        if(~aresetn) begin
            wdata_r <= 32'b0;
            wstrb_r <= 4'b0;
        end 
        else if(wreq_state[2]) begin
            wdata_r <= data_sram_wdata;
            wstrb_r <= data_sram_wstrb;
        end
    end
    always @(posedge aclk) begin
        if(~aresetn || wready) begin
            wvalid_r <= 1'b0;
        end 
        else if(wreq_state[2]) begin
            wvalid_r <= 1'b1;
        end 
        else begin
            wvalid_r <= 1'b0;
        end
    end
    //b
    reg     bready_r;
    assign bready  = bready_r;
    always @(posedge aclk) begin
        if(~aresetn || bvalid) begin
            bready_r <= 1'b0;
        end 
        else if(wrsp_next_state[1]) begin
            bready_r <= 1'b1;
        end 
        else begin
            bready_r <= 1'b0;
        end
    end    
//任务计数�?
    reg [1:0]   rinst_cnt;
    reg [1:0]   rdata_cnt;
    reg [1:0]   wtask_cnt;
    always @(posedge aclk ) begin
        if(~aresetn)
            rinst_cnt<=2'b0;
        else if ((arready&&arvalid)&&(rready&&rvalid))begin
            if(arid==4'b0&&rid==4'b1)
                rinst_cnt<=rinst_cnt+2'b1;
            else if(arid==4'b1&&rid==4'b0)
                rinst_cnt<=rinst_cnt-2'b1;
        end
        else if(rready&&rvalid)
            rinst_cnt<=rinst_cnt-2'b1;
        else if(arready&&arvalid)
            rinst_cnt<=rinst_cnt+2'b1;
    end
    always @(posedge aclk ) begin
        if(~aresetn)
            rdata_cnt<=2'b0;
        else if ((arready&&arvalid)&&(rready&&rvalid))begin
            if(arid==4'b0&&rid==4'b1)
                rdata_cnt<=rdata_cnt-2'b1;
            else if(arid==4'b1&&rid==4'b0)
                rdata_cnt<=rdata_cnt+2'b1;
        end
        else if(rready&&rvalid)
            rdata_cnt<=rdata_cnt-2'b1;
        else if(arready&&arvalid)
            rdata_cnt<=rdata_cnt+2'b1;
    end
    always @(posedge aclk) begin
        if(~aresetn) begin
            wtask_cnt <= 2'b0;
        end 
        else if((bvalid&&bready)&&(wvalid&&wready)) begin
            wtask_cnt <= wtask_cnt;
        end 
        else if(wvalid&&wready) begin
            wtask_cnt<=wtask_cnt+2'b1;
        end 
        else if(bvalid&&bready) begin
            wtask_cnt<=wtask_cnt-2'b1;
        end
    end
//写后读相关检�?
    wire    raw_blk;
    assign raw_blk = arvalid_r && awvalid_r && (awaddr_r == araddr_r);
//ok信号与数�?
    reg     [31:0]  inst_buffer;
    reg     [31:0]  data_buffer;
    always @(posedge aclk) begin
        if(~aresetn) begin
            inst_buffer <= 32'b0;
        end 
        else if(rvalid && rready && ~rid[0]) begin
            inst_buffer <= rdata;
        end
    end
    always @(posedge aclk) begin
        if(~aresetn) begin
            data_buffer <= 32'b0;
        end 
        else if(rvalid && rready && rid[0]) begin
            data_buffer <= rdata;
        end
    end
    assign inst_sram_rdata = inst_buffer;
    assign data_sram_rdata = data_buffer;
    assign inst_sram_addr_ok = rreq_state[4]&~arid[0];
    assign inst_sram_data_ok = rval_state[2]&~rid_r[0];
    assign data_sram_addr_ok = rreq_state[4]&arid[0]|wreq_state[3];
    assign data_sram_data_ok = rval_state[2]&rid_r[0]|wrsp_state[2];
endmodule