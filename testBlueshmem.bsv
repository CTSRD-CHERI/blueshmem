/*****************************************************************************
 * Simple test of forking Bluesim simulations and communicating between them
 * via shared memory FIFOs.
 *****************************************************************************
 * Copyright (c) 2022 Simon W. Moore
 * All rights reserved
 * License: BSD 2-clause - see the LICENSE file
 *****************************************************************************/

import Vector :: *;
import FIFOF :: *;
import Blueshmem :: *;

typedef Bit#(80) MyShmemBufT;


module mkTestBlueshmem(Empty);

  Vector#(3,FIFOF#(MyShmemBufT)) shmem <- replicateM(mkBlueshmemFIFO);
  Reg#(Bool) shmem_init_done <- mkReg(False);
  Reg#(Bool) init_done <- mkReg(False);
  Reg#(BlueshmemUInt32) pid <- mkReg(-1);
  Reg#(Bit#(64)) ctr <- mkReg(0);
  Reg#(Bit#(20)) child_wait <- mkReg(0);
  Reg#(Bit#(20)) parent_wait <- mkReg(0);
  Reg#(UInt#(3)) child_number <- mkReg(0);
  
  // wait one sim cycle for dynamic allocation of BlueshmemFIFOs to complete before fork
  rule wait_shmem(!shmem_init_done); 
    shmem_init_done <= True;
  endrule
  
  rule do_init(!init_done && shmem_init_done);
    child_number <= child_number+1;
    let p <- blueshmem_fork();
    pid <= p; // PID>0 for parent, PID==0 for any children
    init_done <= (p==0) || (child_number>=2);
  endrule
  
  rule parent(init_done && (pid!=0));
    shmem[0].enq(zeroExtend(ctr));
    ctr <= ctr+1;
    $display("[0] %05t: Parent TX=%03d", $time, ctr);
    $fflush();
    if(ctr==1000000)
	$finish();
  endrule

  for(Integer j=1; j<=3; j=j+1)
    rule child(init_done && (pid==0) && (child_number==fromInteger(j)));
      MyShmemBufT v = shmem[j-1].first();
      shmem[j-1].deq();
      if(j<3) // forward message if not last child
	shmem[j].enq(v);
      Bit#(32) vi = truncate(v);
      $write("[%1d] %05t:", child_number, $time);
      for(Integer j=0; fromInteger(j)<child_number; j=j+1)
	$write("\t\t");
      $display("Child-%1d RX=%03d", child_number, vi);
      $fflush();
      if(vi==1000000) $finish();
    endrule
  
  rule child_active_indicator(init_done && (pid==0));
    child_wait <= child_wait+1;
    if(child_wait==0)
      begin
	$write("%1d",child_number);
	$fflush();
      end
  endrule
  
  rule parent_active_indicator(init_done && (pid==0));
    parent_wait <= parent_wait+1;
    if(parent_wait==0)
      begin
	if(shmem[0].notFull)
	  $write("-");
	else
	  $write("+");
	$fflush();
      end
  endrule
  
endmodule
