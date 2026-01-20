// agents/my_driver.sv
class my_driver extends uvm_driver #(seq_item);
  `uvm_component_utils(my_driver)

  virtual my_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual my_if)::get(this, "", "vif", vif))
      `uvm_fatal(get_type_name(), "virtual interface not set for driver")
  endfunction

  virtual task run_phase(uvm_phase phase);
    reset_signals(); 
    
    forever begin
      seq_item req;
      
      seq_item_port.get_next_item(req);

      `uvm_info(get_type_name(), $sformatf("Driver received: %s", req.convert2string()), UVM_MEDIUM)
      
      if (req.is_write) begin
        do_axi_write(req.addr, req.wdata);
      end else begin
        do_axi_read(req.addr, req.rdata); 
      end
      
      seq_item_port.item_done();
    end
  endtask : run_phase

  virtual task do_axi_write(input bit [31:0] addr, input bit [31:0] wdata);

    @(posedge vif.ACLK);
    vif.S_AXI_AWVALID <= 1'b1;
    vif.S_AXI_AWADDR  <= addr;
    vif.S_AXI_AWPROT  <= 3'b0;
    

    do begin
        @(posedge vif.ACLK);
    end while (vif.S_AXI_AWREADY !== 1'b1);
    
    vif.S_AXI_AWVALID <= 1'b0;
    
    vif.S_AXI_WVALID <= 1'b1;
    vif.S_AXI_WDATA  <= wdata;
    vif.S_AXI_WLAST  <= 1'b1;
    vif.S_AXI_WSTRB  <= 4'b1111;
    

    do begin
        @(posedge vif.ACLK);
    end while (vif.S_AXI_WREADY !== 1'b1);

    vif.S_AXI_WVALID <= 1'b0;
    vif.S_AXI_WLAST  <= 1'b0;

    vif.S_AXI_BREADY <= 1'b1;
    
 
    do begin
        @(posedge vif.ACLK);
    end while (vif.S_AXI_BVALID !== 1'b1);

    vif.S_AXI_BREADY <= 1'b0;
  endtask : do_axi_write

  virtual task do_axi_read(input bit [31:0] addr, output bit [31:0] rdata);

    @(posedge vif.ACLK);
    vif.S_AXI_ARVALID <= 1'b1;
    vif.S_AXI_ARADDR  <= addr;
    vif.S_AXI_ARPROT  <= 3'b0;
    

    do begin
        @(posedge vif.ACLK);
    end while (vif.S_AXI_ARREADY !== 1'b1);

    vif.S_AXI_ARVALID <= 1'b0;

    vif.S_AXI_RREADY <= 1'b1;
    

    do begin
        @(posedge vif.ACLK);
    end while (vif.S_AXI_RVALID !== 1'b1);
    
    rdata = vif.S_AXI_RDATA; 
    
    if (vif.S_AXI_RLAST !== 1'b1) begin
      `uvm_warning("DRIVER", "RLAST was not high with RVALID")
    end
    
    vif.S_AXI_RREADY <= 1'b0;
  endtask : do_axi_read

  virtual task reset_signals();
    @(posedge vif.ACLK);
    vif.S_AXI_AWVALID <= 1'b0;
    vif.S_AXI_AWADDR  <= 32'b0;
    vif.S_AXI_AWPROT  <= 3'b0;
    vif.S_AXI_WVALID  <= 1'b0;
    vif.S_AXI_WDATA   <= 32'b0;
    vif.S_AXI_WSTRB   <= 4'b1111;
    vif.S_AXI_WLAST   <= 1'b0;
    vif.S_AXI_BREADY  <= 1'b0;
    vif.S_AXI_ARVALID <= 1'b0;
    vif.S_AXI_ARADDR  <= 32'b0;
    vif.S_AXI_ARPROT  <= 3'b0;
    vif.S_AXI_RREADY  <= 1'b0;
  endtask : reset_signals

endclass : my_driver