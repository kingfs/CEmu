/*
 * Copyright (c) 2014 The KnightOS Group
 * Modified to support the eZ80 processor by CEmu developers
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated 
 * documentation files (the "Software"), to deal in the Software without restriction, including without limitation 
 * the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software,
 * and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in all copies or substantial portions 
 * of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED 
 * TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL 
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF 
 * CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER 
 * DEALINGS IN THE SOFTWARE.
*/

#ifndef CPU_H
#define CPU_H

#ifdef __cplusplus
extern "C" {
#endif

#include "registers.h"
#include "mem.h"
#include "apb.h"

/* eZ80 CPU State */
typedef struct eZ80cpu {
    eZ80portrange_t prange[0x10];    /* 0x0000-0xF000 */
    eZ80registers_t registers;
    struct {
        uint8_t IEF1        : 1;  /* IFlag1                 */
        uint8_t IEF2        : 1;  /* IFlag2                 */
        uint8_t ADL         : 1;  /* ADL bit                */
        uint8_t MADL        : 1;  /* Mixed-Memory modes     */
        uint8_t IM          : 2;  /* Current interrupt mode */

        /* Internal use: */
        uint8_t PREFIX      : 2;  /* Which index register is in use. 0: hl, 2: ix, 3: iy                                         */
        uint8_t SUFFIX      : 1;  /* There was an explicit suffix                                                                */
        uint8_t S           : 1;  /* The CPU data block operates in Z80 mode using 16-bit registers. All addresses use MBASE.    */
        uint8_t L           : 1;  /* The CPU data block operates in ADL mode using 24-bit registers. Addresses do not use MBASE. */
        uint8_t IS          : 1;  /* The CPU control block operates in Z80 mode.                                                 */
        uint8_t IL          : 1;  /* The CPU control block operates in ADL mode.                                                 */
        uint8_t IEF_wait    : 1;  /* Wait for interrupt                                                                          */
        uint8_t halted      : 1;  /* Have we halted the CPU?                                                                     */
    };
    int cycles;
    uint8_t bus;  /* TODO */
    uint8_t (*read_byte)(uint32_t address);
    void (*write_byte)(uint32_t address, uint8_t byte);
    int interrupt;
} eZ80cpu_t;

/* Externals */
extern eZ80cpu_t cpu;

/* Available Functions */
void cpu_init(void);

void cpu_execute(void);

#ifdef __cplusplus
}
#endif

#endif
