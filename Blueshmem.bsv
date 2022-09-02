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

typedef Bit#(64) BlueshmemPtr;    // pointer to buffer
typedef Bit#(64) BlueshmemSem;    // pointer to semaphore
typedef Bit#(32) BlueshmemUInt32; // unsigned 32-bit integer

// C imports
import "BDPI" function ActionValue#(BlueshmemUInt32) blueshmem_fork();
import "BDPI" function Action blueshmem_wait();
import "BDPI" function ActionValue#(BlueshmemPtr) blueshmem_allocate(BlueshmemUInt32 nint);
import "BDPI" function Action blueshmem_write(BlueshmemPtr shmem_addr, Bit#(n) data, BlueshmemUInt32 nint);
import "BDPI" function Bit#(n) blueshmem_read(BlueshmemPtr shmem_addr, BlueshmemUInt32 nint);
import "BDPI" function ActionValue#(BlueshmemSem) blueshmem_flag_allocate();
import "BDPI" function BlueshmemUInt32 blueshmem_flag_val(BlueshmemSem sem_addr);
import "BDPI" function Action blueshmem_flag_inc(BlueshmemSem sem_addr);
import "BDPI" function Action blueshmem_flag_dec_wait(BlueshmemSem sem_addr);


module mkBlueshmemFIFO(FIFOF#(bufT))
  provisos (
     Bits#(bufT,bufT_size_bits),
     Max#(65, bufT_size_bits, bufT_size_bits), // bufT_size_bits>64 to ensure pass by reference of buffers to/from C functions
     Div#(bufT_size_bits,32, bufT_size_32b_words)
     );
  
  Reg#(Bool) init_done <- mkReg(False);
  Reg#(BlueshmemPtr) shmem <- mkReg(0);
  Reg#(BlueshmemSem) sem <- mkReg(0);
  Wire#(Bool) empty <- mkDWire(False);
  
  rule dynamic_allocation(!init_done);
    init_done <= True;
    BlueshmemPtr new_shmem <- blueshmem_allocate(fromInteger(valueOf(bufT_size_32b_words)));
    shmem <= new_shmem;
    let new_sem <- blueshmem_flag_allocate();
    sem <= new_sem;
  endrule

  rule poll_for_space(init_done);
    BlueshmemUInt32 flag = blueshmem_flag_val(sem);
    empty <= flag!=0;
  endrule

  method Action enq(bufT d) if (empty && init_done);
    blueshmem_write(shmem, pack(d), fromInteger(valueOf(bufT_size_32b_words)));
    blueshmem_flag_dec_wait(sem);
  endmethod

  method Action deq() if(!empty && init_done);
    blueshmem_flag_inc(sem);
  endmethod
  
  method bufT first if (!empty && init_done);
    return unpack(blueshmem_read(shmem, fromInteger(valueOf(bufT_size_32b_words))));
  endmethod
  
  method Action clear if (init_done);
    if(!empty)
      blueshmem_flag_inc(sem); // unsafe?
  endmethod

  method Bool notFull = empty;
  method Bool notEmpty = !empty;
  
endmodule


endpackage
