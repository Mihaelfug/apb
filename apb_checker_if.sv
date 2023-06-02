`ifndef APB_DATA_WIDTH
   `define APB_DATA_WIDTH 32
`endif
`ifndef APB_ADDR_WIDTH
   `define APB_ADDR_WIDTH 32
`endif

interface apb_checker_if (input PCLK);
   logic                         PRESETn  ; 
   logic [`APB_ADDR_WIDTH-1  :0] PADDR    ;
   logic [2 :0]                  PPROT    ;
   logic                         PSEL     ;
   logic                         PENABLE  ;
   logic                         PWRITE   ;
   logic [`APB_DATA_WIDTH-1  :0] PWDATA   ;
   logic [`APB_DATA_WIDTH/8-1:0] PSTRB    ;
   logic                         PREADY   ;
   logic [`APB_DATA_WIDTH-1  :0] PRDATA   ;
   logic                         PSLVERR  ;
  
//----- Sequences -----
//phases
sequence idle_phase ;
   !PSEL ;
endsequence
sequence setup_phase ;
   PSEL && !PENABLE ;
endsequence
sequence access_phase_wait ;
   PSEL && PENABLE && !PREADY ;
endsequence
sequence access_phase_last ;
   PSEL && PENABLE && PREADY ;
endsequence

//----- Properties -----
//parametric property to check signal is not X/Z
property pr_generic_not_unknown (signal) ;
   @(posedge PCLK) disable iff(!PRESETn)
      !$isunknown(signal) ;
endproperty 
//parametric property to check if signal stable during the transfer. If the signal changed means the state became IDLE or SETUP, i.e. the transfer just finished.
property pr_generic_stable(signal) ;
   @(posedge PCLK) disable iff(!PRESETn)
      !$stable(signal) |-> setup_phase or idle_phase ;
endproperty
//same as pr_generic_stable but for PWDATA. it should be stable only in WRITE transfers, i.e. PWRITE=1
property pwrite_in_wr_transfer ;
   @(posedge PCLK) disable iff(!PRESETn)
      !$stable(PWDATA) |-> (!PWRITE) or (setup_phase or idle_phase) ;
endproperty
// for PENABLE and PSEL i can't use phases, since the phases are defined using these lines
property penable_in_transfer ;
   @(posedge PCLK) disable iff(!PRESETn)
      $fell(PENABLE) |-> idle_phase or ($past(PENABLE) && $past(PREADY)) ;
endproperty
//check if PSEL stable during transfer. i.e. PSEL can fall only after tranfer completed (PREADY=1)
property psel_stable_in_transfer ;
   @(posedge PCLK) disable iff(!PRESETn)
      !PSEL && $past(PSEL) |-> $past(PENABLE) && $past(PREADY) ; //The antecedent is NOT equal to ($fell) since 'X'->'0' also activates $fell
endproperty
//PSRTB must be driven low at read transfer
property pstrb_low_at_read ;
   @(posedge PCLK) disable iff(!PRESETn)
      PSEL && !PWRITE |-> PSTRB == {(`APB_DATA_WIDTH/8){1'b0}} ;
endproperty

//Operating States (see chapter 4 in APB5 documentation)
property idle_state ;
   @(posedge PCLK) disable iff(!PRESETn)
      idle_phase |=> idle_phase or setup_phase ;
endproperty
property setup_state ;
   @(posedge PCLK) disable iff(!PRESETn)
      setup_phase |=> access_phase_wait or access_phase_last ;
endproperty
property access_wait_state ;
   @(posedge PCLK) disable iff(!PRESETn)
      access_phase_wait |=> access_phase_wait or access_phase_last ;
endproperty
property access_last_state ;
   @(posedge PCLK) disable iff(!PRESETn)
      access_phase_last |=> idle_phase or setup_phase ;
endproperty

//----- Assertions -----
// check all signal for being valid. The protocol doesn't actualy require this. only PSEL must be always valid.
PSEL_never_X    : assert property (pr_generic_not_unknown(PSEL   )) else $display("[%0t] Error! PSEL is unknown (=X/Z)", $time) ;
PWRITE_never_X  : assert property (pr_generic_not_unknown(PWRITE )) else $display("[%0t] Error! PWRITE is unknown (=X/Z)", $time) ;
PENABLE_never_X : assert property (pr_generic_not_unknown(PENABLE)) else $display("[%0t] Error! PENABLE is unknown (=X/Z)", $time) ;
PREADY_never_X  : assert property (pr_generic_not_unknown(PREADY )) else $display("[%0t] Error! PREADY is unknown (=X/Z)", $time) ;
PADDR_never_X   : assert property (pr_generic_not_unknown(PADDR  )) else $display("[%0t] Error! PADDR is unknown (=X/Z)", $time) ;
PWDATA_never_X  : assert property (pr_generic_not_unknown(PWDATA )) else $display("[%0t] Error! PWDATA is unknown (=X/Z)", $time) ;
PRDATA_never_X  : assert property (pr_generic_not_unknown(PRDATA )) else $display("[%0t] Error! PRDATA is unknown (=X/Z)", $time) ;
PSTRB_never_X   : assert property (pr_generic_not_unknown(PSTRB  )) else $display("[%0t] Error! PSTRB is unknown (=X/Z)", $time) ;
PPROT_never_X   : assert property (pr_generic_not_unknown(PPROT  )) else $display("[%0t] Error! PPROT is unknown (=X/Z)", $time) ;

//check signals stability during a transfer (section 4.1 in APB5 documentation)
PADDR_stable_in_transfer     : assert property (pr_generic_stable(PADDR ))  else $display("[%0t] Error! PADDR must not change throughout the transfer", $time) ;
PWRITE_stable_in_transfer    : assert property (pr_generic_stable(PWRITE))  else $display("[%0t] Error! PWRITE must not change throughout the transfer", $time) ;
PENABLE_stable_in_transfer   : assert property (penable_in_transfer)        else $display("[%0t] Error! PENABLE must not change throughout the access phase", $time) ;
PSEL_stable_in_transfer      : assert property (psel_stable_in_transfer)    else $display("[%0t] Error! PSEL must not change throughout the transfer", $time) ;
PWDATA_stable_in_wr_transfer : assert property (pwrite_in_wr_transfer)      else $display("[%0t] Error! PWDATA must not change throughout the write transfer", $time) ;
PSTRB_stable_in_transfer     : assert property (pr_generic_stable(PSTRB))   else $display("[%0t] Error! PSTRB must not change throughout the transfer", $time) ;
PSTRB_low_in_read_transfer   : assert property (pstrb_low_at_read)          else $display("[%0t] Error! PSTRB must be driven low in read transfer", $time) ;
PPROT_stable_in_transfer     : assert property (pr_generic_stable(PPROT))   else $display("[%0t] Error! PPROT must not change throughout the transfer", $time) ;
PSLVERR_stable_in_transfer   : assert property (pr_generic_stable(PSLVERR)) else $display("[%0t] Error! PSLVERR must not change throughout the transfer", $time) ;

//check transition between operational states of the protocol (section 4)
  Operating_state_idle        : assert property (idle_state)     
                                  else $display("[%0t] Error! The transfer must start with setup phase (PSEL=1, PENABLE=0).", $time) ;
  Operating_state_setup       : assert property (setup_state) 
                                  else $display("[%0t] Error! The setup phase must proceed to access phase (PSEL=1, PENABLE=0) after 1 clk.", $time) ;
  Operating_state_access_wait : assert property (access_wait_state) 
                                  else $display("[%0t] Error! The transfer must stay in access phase (wait state (PREADY=0) or proceed to finish (PREADY=1).", $time) ;
  Operating_state_access_last : assert property (access_last_state) 
                                  else $display("[%0t] Error! After a transfer finished, must proceed to IDLE (PSEL=0) or setup phase (PSEL=1, PENABLE=0).",  $time) ;

endinterface
