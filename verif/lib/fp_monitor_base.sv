// verif/lib/fp_monitor_base.sv
//
// Generic, parameterized base class for a monitor. It uses a queue to handle
// pipelined designs and has a pure virtual task 'sample_inputs' that must
// be implemented by a child class.

`include "uvm_macros.svh"
import uvm_pkg::*;

virtual class fp_monitor_base #(
    type T_TRANS = uvm_sequence_item,
    type T_VIF
) extends uvm_monitor;

    T_VIF vif;
    uvm_analysis_port #(T_TRANS) ap;
    // Port to get the original transaction from the agent's FIFO
    uvm_get_port #(T_TRANS) get_port;

    T_TRANS input_queue[$];
    int pipeline_latency = -1; // Default to invalid
    int unsigned epsilon_delay = 1; // Default to a 1-timeunit delay

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
        get_port = new("get_port", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(T_VIF)::get(this, "", "dut_vif", vif))
            `uvm_fatal("NOVIF", "Could not get virtual interface handle")
        if(!uvm_config_db#(int)::get(this, "", "pipeline_latency", pipeline_latency))
            `uvm_fatal("NOPARAM", "Pipeline latency not set for monitor")
    endfunction

    virtual task run_phase(uvm_phase phase);
        if (pipeline_latency < 0) begin
            `uvm_fatal("BAD_LATENCY", $sformatf("Invalid pipeline_latency: %0d (was it set in command line?)", pipeline_latency))
        end
        // Fork the two parallel processes
        fork
            collect_inputs(phase);
            collect_outputs(phase);
        join
    endtask

    virtual task collect_inputs(uvm_phase phase);
        @(posedge vif.rst_n);
        forever begin
            T_TRANS trans;
            @(vif.monitor_cb);
            pre_sample(0);
            sample_inputs(trans);
            if (trans != null) begin
                input_queue.push_back(trans);
            end
        end
    endtask

    virtual task collect_outputs(uvm_phase phase);
        T_TRANS named_trans, trans_out;
        bit driver_is_active;
        bit local_q_has_items;
        bit started_flag = 0;

        @(posedge vif.rst_n);

        // +1 cycle seem to be needed in addition to DUT latency. 
        // It could be unstable here due to all generators and monitors align to posedge clk.
        repeat(pipeline_latency + 1) @(vif.monitor_cb);
        forever begin
            @(vif.monitor_cb);
            pre_sample(1);
            driver_is_active = get_port.can_get();
            local_q_has_items = (input_queue.size() > 0);
            if (driver_is_active && local_q_has_items) begin
                started_flag = 1;
                get_port.get(named_trans);
                trans_out = input_queue.pop_front();
                named_trans.inputs = trans_out.inputs;
                sample_output(named_trans); // DUT-specific
                `uvm_info(get_type_name(), $sformatf("Collected transaction"), UVM_HIGH)
                ap.write(named_trans);
            end else if (driver_is_active != local_q_has_items && !started_flag) begin
                // This else block helps debug synchronization problems.
                `uvm_warning("MON_SYNC_WARN", $sformatf("Queue mismatch! Driver FIFO has item: %b, Local input queue has item: %b",
                    get_port.can_get(), (input_queue.size() > 0) ))
            end
        end
    endtask

    // This task provides the #epsilon delay. It can be overridden in child
    // classes if a different delay is needed.
    virtual task pre_sample(int is_output);
        #epsilon_delay;
        #epsilon_delay; // Additionla delay to wait for driver.pre_drive() delay. Though it does not remove extra clock cycle.
        if (is_output) begin
            // Additional delay for sampling output, as we're also need input_queue data from parallel process
            #epsilon_delay;
        end
    endtask

    // This is a placeholder task that MUST be implemented by the DUT-specific monitor
    pure virtual task sample_inputs(output T_TRANS trans);

    pure virtual task sample_output(T_TRANS trans);

endclass
