// Scoreboard: receives observed transactions and checks vs expected

class scoreboard extends uvm_component;
  `uvm_component_utils(scoreboard)

  // Analysis export to connect from monitor
  uvm_analysis_imp #(seq_item, scoreboard) analysis_export;

  // Expected value defined in our Dummy Slave
  const bit [31:0] EXPECTED_VAL = 32'hCAFEBABE;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_export = new("analysis_export", this);
  endfunction

  // write() gets called by the monitor via analysis_port
  virtual function void write(seq_item t);
    // TODO: Compare t against expected model; track pass/fail
    
    if (t.is_write) begin
      // For writes, just confirm we saw it
      `uvm_info("SCB", $sformatf("PASS: Observed WRITE -> Addr: 0x%h, Data: 0x%h", t.addr, t.wdata), UVM_LOW)
    end 
    else begin
      // For reads, verify the data matches the dummy slave
      if (t.rdata == EXPECTED_VAL) begin
        `uvm_info("SCB", $sformatf("PASS: Observed READ  -> Addr: 0x%h, Data: 0x%h (MATCH)", t.addr, t.rdata), UVM_LOW)
      end else begin
        `uvm_error("SCB", $sformatf("FAIL: Data Mismatch! Expected: 0x%h, Got: 0x%h", EXPECTED_VAL, t.rdata))
      end
    end

  endfunction
endclass : scoreboard
