/*****************************************************************************
 * C Library to provide access to fork() for process creation and
 * shared memory for communication
 *****************************************************************************
 * Copyright (c) 2022 Simon W. Moore
 * All rights reserved
 * License: BSD 2-clause - see the LICENSE file
 *****************************************************************************/

#include <semaphore.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

// fork simulation
unsigned int blueshmem_fork()
{
  int pid = fork();
  if(pid<0) {
    perror("Fork failed");
    exit(1);
  }
  return pid;
}

// wait for child process to finish
void blueshmem_wait()
{
  int pid = wait(NULL);
  if(pid<0)
    perror("Wait failed");
}

// returns pointer to a semaphore used to indicate empty/full
unsigned long long blueshmem_flag_allocate()
{
  sem_t *sem = mmap(NULL, sizeof(sem_t), PROT_READ |PROT_WRITE,MAP_SHARED|MAP_ANONYMOUS, -1, 0);
  if(sem_init(sem, 1, 1)!=0) {
    perror("Failed to initialise semaphore");
    exit(1);
  }
  return (unsigned long long) sem;
}


// returns state of flag (semaphore)
unsigned int blueshmem_flag_val(unsigned long long sem_addr)
{
  sem_t *sem = (sem_t *) sem_addr;
  int sval;
  if(sem_getvalue(sem, &sval)!=0) {
    perror("Failed to get semaphore value");
    exit(1);
  }
  return (unsigned int) sval;
}


// increment flag (semaphore)
void blueshmem_flag_inc(unsigned long long sem_addr)
{
  sem_t *sem = (sem_t *) sem_addr;
  sem_post(sem);
}


// decrement flag (semaphore), wait if semaphore is zero
void blueshmem_flag_dec_wait(unsigned long long sem_addr)
{
  sem_t *sem = (sem_t *) sem_addr;
  sem_wait(sem);
}


// returns pointer to allocated buffer in shared memory of size nint integers
unsigned long long blueshmem_allocate(unsigned int nint)
{
  unsigned int * shared = mmap(NULL, nint * sizeof(int), PROT_READ | PROT_WRITE, MAP_SHARED | MAP_ANONYMOUS, -1, 0);
  return (unsigned long long) shared;
}


// write nint integers to shared memory buffer
void blueshmem_write(unsigned long long buf_addr, unsigned int *data, unsigned int nint)
{
  // TODO: use memcpy?
  int * buf = (int *) buf_addr;
  int j;
  for(j=0; j<nint; j++)
    buf[j] = data[j];
}


// read nint integers from shared memory buffer
void blueshmem_read(unsigned int *data, unsigned long long buf_addr, unsigned int nint)
{
  // TODO: use memcpy?
  int * buf = (int *) buf_addr;
  int j;
  for(j=0; j<nint; j++)
    data[j] = buf[j];
}

