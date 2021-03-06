//
//  ESpeed.m
//  Elysian
//
//  Created by chris  on 6/23/20.
//  Copyright © 2020 chr1s_0x1. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "pac/kernel.h"
#import "kernel_memory.h"
#import "IOSurface_stuff.h"
#import "utils.h"
#import "offsets.h"
#import "jbtools.h"
#import "jelbrekLib.h"
#import "ESpeed.h"

mach_port_t tfp0hsp4 = MACH_PORT_NULL;
uint64_t selfproc = 0;
uint64_t selftask = 0;

// Not fully finished yet
int ESpeed(void) {
    LOG("[ESpeed] Trying to grab tfp0 from HSP4..");
    host_t myself = mach_host_self();
    mach_port_t hsp4 = MACH_PORT_NULL;
    host_get_special_port(myself, HOST_LOCAL_NODE, 4, &hsp4);
    mach_port_deallocate(mach_task_self(), myself);
    if(MACH_PORT_VALID(hsp4)) {
        LOG("[ESpeed] Got tfp0 from HSP4");
        tfp0hsp4 = hsp4;
    } else {
        LOG("[ESpeed] ERR: Couldn't get tfp0 from HSP4");
        return 1;
    }
    
    init_offsets();
    
    // init rk64, wk64 etc.
    init_read_write(tfp0hsp4);
    
    // took this from oob_timestamp
    // Call task_info(TASK_DYLD_INFO) to get the kernel_all_image_info_addr struct address.
    if (kernel_all_image_info_addr == 0) {
        struct task_dyld_info info = {};
        mach_msg_type_number_t count = TASK_DYLD_INFO_COUNT;
        kern_return_t kr = task_info(tfp0hsp4, TASK_DYLD_INFO,
                (task_info_t) &info, &count);
        if (kr != KERN_SUCCESS) {
            LOG("[ESpeed] task_info(TASK_DYLD_INFO) failed: %d", kr);
            return 1;
        }
        kernel_all_image_info_addr = info.all_image_info_addr;
    }
    
    /* -------- Finding our own process -------- */
     
    UInt32 mypid = getpid();

    if(mypid == 0) return 1;
    
    // took this from oob_timestamp x2
    uint64_t kproc = rk64(kernel_all_image_info_addr + offsetof(struct kernel_all_image_info_addr, kernproc));
    uint64_t proclist = kproc;
    if(!ADDRISVALID(kproc)) {
        LOG("[ESpeed] ERR: Couldn't grab kernproc from struct");
        return 1;
    }
    for(;;) {
        if(proclist == 0 || proclist == -1) break;
        UInt32 procpid = rk32(proclist + koffset(KSTRUCT_OFFSET_PROC_PID));
        if(procpid == mypid) {
            selfproc = proclist;
            break;
        }
        proclist = rk64(proclist + 0x8);
    }
    selftask = rk64(selfproc + 0x10);
    LOG("[ESpeed] Found our task: 0x%llx", selftask);
    
    // now init with our task
    init_kernel_memory(tfp0hsp4, selftask);
    
    // -------- Now Unsandbox -------- //
    
    LOG("[ESpeed] Unsandboxing..");
    uint64_t proc = rk64(selftask + koffset(KSTRUCT_OFFSET_TASK_BSD_INFO));
    LOG("[ESpeed] our_proc: 0x%llx", proc);
    uint64_t our_ucred = rk64(proc + 0x100); // 0x100 - off_p_ucred
    LOG("[ESpeed] ucred: 0x%llx", our_ucred);
    uint64_t cr_label = rk64(our_ucred + 0x78); // 0x78 - off_ucred_cr_label
    LOG("[ESpeed] cr_label: 0x%llx", cr_label);
    uint64_t sandbox = rk64(cr_label + 0x10);
    LOG("[ESpeed] sandbox_slot: 0x%llx", sandbox);
    
    LOG("[ESpeed] Setting sandbox_slot to 0");
        // Set sandbox pointer to 0;
    wk64(cr_label + 0x10, 0);
        // Are we free?
    createFILE("/var/mobile/.elytest", nil);
    FILE *f = fopen("/var/mobile/.elytest", "w");
    if(!f){
    LOG("[ESpeed] ERR: Failed to set Sandbox_slot to 0");
    LOG("[ESpeed] ERR: Failed to Unsanbox");
    CredsTool(0, 1, NO, NO);
    return 1;
    }
    
    LOG("[Espeed] Escaped Sandbox");
     
    // ------ grab the kernel base ------ \\
    
    // check if we can get the kernel base from the kernel struct
    KernelBase = rk64(kernel_all_image_info_addr +
    offsetof(struct kernel_all_image_info_addr, kernel_base_address));
    if(!ADDRISVALID(KernelBase)) {
        LOG("[ESpeed] ERR: Couldn't grab KernelBase from struct");
        return 1;
    }
    
    LOG("[ESpeed] Got our KernelBase: 0x%llx", KernelBase);
    
    // now initiate jelbrekLibE
    int init = init_with_kbase(tfp0hsp4, KernelBase, kernel_exec);
    if(init != 0) {
        LOG("[ESpeed] ERR: Couldn't initiate jelbrekLibE");
        CredsTool(0, 1, NO, NO);
        term_IOSurface();
        return 1;
    }
    
    EscalateTask(selftask);
    
    LOG("[ESpeed] Finished with speed..");
    return 0;
}
