/*****************************************************************************
 * Simple proof-of-concept library to allow Bluesim simulations to be forked
 * with FIFO communication via shared memory.
 *****************************************************************************
 * Copyright (c) 2022 Simon W. Moore
 * All rights reserved
 * License: BSD 2-clause - see the LICENSE file
 *****************************************************************************/

package Blueshmem;


import FIFOF :: *;

typedef Bit#(1024) BlueshmemBufT; // maximum size of any shared memory data transfer (multiples of 32-bits)
typedef Bit#(64) BlueshmemPtr;    // pointer to buffer
typedef Bit#(64) BlueshmemSem;    // pointer to semaphore
typedef Bit#(32) BlueshmemUInt32; // unsigned 32-bit integer

// C imports
import "BDPI" function ActionValue#(BlueshmemUInt32) blueshmem_fork();
import "BDPI" function Action blueshmem_wait();
import "BDPI" function ActionValue#(BlueshmemPtr) blueshmem_allocate(BlueshmemUInt32 nint);
import "BDPI" function Action blueshmem_write(BlueshmemPtr shmem_addr, BlueshmemBufT data, BlueshmemUInt32 nint);
import "BDPI" function BlueshmemBufT blueshmem_read(BlueshmemPtr shmem_addr, BlueshmemUInt32 nint);
import "BDPI" function ActionValue#(BlueshmemSem) blueshmem_flag_allocate();
import "BDPI" function BlueshmemUInt32 blueshmem_flag_val(BlueshmemSem sem_addr);
import "BDPI" function Action blueshmem_flag_inc(BlueshmemSem sem_addr);
import "BDPI" function Action blueshmem_flag_dec_wait(BlueshmemSem sem_addr);


module mkBlueshmemFIFO(FIFOF#(BlueshmemBufT));
  
  Reg#(Bool) init_done <- mkReg(False);
  Reg#(BlueshmemPtr) shmem <- mkReg(0);
  Reg#(BlueshmemSem) sem <- mkReg(0);
  Wire#(Bool) empty <- mkDWire(False);
  
  rule dynamic_allocation(!init_done);
    init_done <= True;
    BlueshmemPtr new_shmem <- blueshmem_allocate(fromInteger(valueOf(SizeOf#(BlueshmemBufT))/32));
    shmem <= new_shmem;
    let new_sem <- blueshmem_flag_allocate();
    sem <= new_sem;
  endrule

  rule poll_for_space(init_done);
    BlueshmemUInt32 flag = blueshmem_flag_val(sem);
    empty <= flag!=0;
  endrule

  method Action enq(BlueshmemBufT d) if (empty && init_done);
    blueshmem_write(shmem, d, fromInteger(valueOf(SizeOf#(BlueshmemBufT))/32));
    blueshmem_flag_dec_wait(sem);
  endmethod

  method Action deq() if(!empty && init_done);
    blueshmem_flag_inc(sem);
  endmethod
  
  method BlueshmemBufT first if (!empty && init_done);
    return blueshmem_read(shmem, fromInteger(valueOf(SizeOf#(BlueshmemBufT))/32));
  endmethod
  
  method Action clear if (init_done);
    if(!empty)
      blueshmem_flag_inc(sem); // unsafe?
  endmethod

  method Bool notFull = empty;
  method Bool notEmpty = !empty;
  
endmodule


endpackage
