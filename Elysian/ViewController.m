//
//  ViewController.m
//  Elysian
//
//  Created by chr1spwn3d on 3/2/20.
//  Copyright © 2020 chr1s_0x1. All rights reserved.
//

#include <sys/mount.h>
#include <sys/snapshot.h>
#include <spawn.h>


#import "ViewController.h"
#import "exploit.h"
#import "jelbrekLib.h"
#import "jbtools.h"
#import "offsets.h"
#import "jboffsets.h"
#import "sethsp4.h"
#import "utils.h"
#import "remount.h"
#import "ESpeed.h"
#import "amfidestroyer.h"
#import "csblobmanipulate.h"
#import "bootstrap.h"
#include "pac/kernel_call.h"
#include "pac/parameters.h"
#include "pac/kernel.h"

bool ESpeedMode; // lets Elysian know if we're running off of HSP4
uint64_t kernel_proc;
uint64_t launchd_proc;
uint64_t our_proc;
UInt32 amfi_pid;

#define SYSTEM_VERSION_GREATER_THAN(v)              ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedDescending)

#define SYSTEM_VERSION_LESS_THAN(v)                 ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)

#define SetButtonText(what)\
[self->JBButton setTitle:@(what) forState:UIControlStateNormal]

                        // Setup important processes and pids
void FillProcs() {
    LOG("[proc] Filling procs..");
    
    kernel_proc = proc_of_pid(0);
    if(!ADDRISVALID(kernel_proc)) {
        LOG("[proc] ERR: Couldn't get kern proc");
        return;
    }
    LOG("[proc] Got kernel proc");
    
    launchd_proc = proc_of_pid(1);
    if(!ADDRISVALID(launchd_proc)) {
        LOG("[proc] ERR: Couldn't get launchd proc");
        return;
    }
    LOG("[proc] Got launchd proc");
    
    our_proc = proc_of_pid(getpid());
    if(!ADDRISVALID(our_proc)) {
        LOG("[proc] ERR: Couldn't get our proc");
        return;
    }
    LOG("[proc] Got our proc");
    
    uint64_t proc = rk64(Find_allproc());
    while(proc != 0) {
        char name[32];
        var pid = rk32(proc + (UInt64)(0x68));
        uint64_t procname = proc + 0x258;
        kread(procname, name, 32);
        if(strncmp(name, "amfid", 32) == 0) {
            LOG("[proc] Found amfid");
            amfi_pid = pid;
            break;
        }
        proc = rk64(proc);
    }
    
    LOG("[proc] Filled all procs");
    return;
}
                        // Setup for ESpeed to use the tfp0 in HSP4
int PreSpeed(mach_port_t ktaskport) {
    if(!MACH_PORT_VALID(ktaskport)) {
        LOG("[PreSpeed] ERR: tfp0 is invalid!");
        return 1;
    }
    LOG("[PreSpeed] Setting up..");
    
    // get port address of tfp0
    uint64_t kportaddr = find_port(ktaskport);
    if(!ADDRISVALID(kportaddr)) {
        LOG("[PreSpeed] ERR: Couldn't find tfp0 port address");
        return 1;
    }
    
    // get the tfp0 task
    uint64_t ktask = rk64(kportaddr + koffset(KSTRUCT_OFFSET_IPC_PORT_IP_KOBJECT));
    if(!ADDRISVALID(ktask)) {
        LOG("[PreSpeed] ERR: Couldn't find tfp0 task");
        return 1;
    }
    
    // add things to struct xD
    struct kernel_all_image_info_addr kernelstuff = {};
    kernelstuff.kernproc = kernel_proc;
    if(!ADDRISVALID(kernelstuff.kernproc)) {
        LOG("[PreSpeed] ERR: Couldn't set kernproc");
        return 1;
    }
    kernelstuff.kernel_base_address = KernelBase;
    if(!ADDRISVALID(kernelstuff.kernel_base_address)) {
        LOG("[PreSpeed] ERR: Couldn't set kernel base");
        return 1;
    }
    
     // set up the struct
    uint64_t kernel_all_image_info_addr_struct = kalloc(pagesize);
    uint64_t kernel_slide = KernelBase - 0xfffffff007004000;
    kernelstuff.kernel_all_image_info_addr_size = kernelstuff.kernel_all_image_info_addr_size = sizeof(kernelstuff);
    kwrite(kernel_all_image_info_addr_struct, &kernelstuff, sizeof(kernelstuff));
    wk64(ktask + 0x3d0, kernel_all_image_info_addr_struct);
    wk64(ktask + 0x3d8, kernel_slide);
    
    LOG("[PreSpeed] Done");
    return 0;
}


@interface ViewController ()

@property (weak, nonatomic) IBOutlet UILabel *Label;

@property (strong, nonatomic) IBOutlet UIView *section;

@end


@implementation ViewController


- (void)viewDidLoad {
    
    // iOS Compatibility check
    if(SYSTEM_VERSION_GREATER_THAN(@"13.3") || SYSTEM_VERSION_LESS_THAN(@"13.0")) {
    JBButton.enabled = NO; // should disable this first
    LOG("ERR: Unsupported Firmware");
    SetButtonText("Error: Unsupported");
}
    
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}


- (IBAction)JBGo:(id)sender {
    [self->JBButton setEnabled:NO];
        LOG("[*] Starting Exploit");
        int espeed = 0;
        __block mach_port_t tfpzero = MACH_PORT_NULL;
        espeed = ESpeed();
        if(espeed == 0) {
            ESpeedMode = YES;
        } else {
        tfpzero = get_tfp0();
        if(!MACH_PORT_VALID(tfpzero)){
            LOG("ERR: Exploit Failed");
            LOG("Please reboot and try again");
            SetButtonText("Error: Exploiting Kernel");
            return;
            }
        }
        LOG("Exploited kernel");
    
    /* Start of Elysian Jailbreak ************************************/
       
        // used for checks
        int errs;
        
        LOG("Starting Jailbreak Process..");
        
            // ------------ Unsandbox ------------ //
        if (espeed != 0) {
        LOG("Unsandboxing..");
            // find our task
        uint64_t our_task = find_self_task();
        LOG("our_task: 0x%llx", our_task);
            // find the sandbox slot
        uint64_t proc = rk64(our_task + koffset(KSTRUCT_OFFSET_TASK_BSD_INFO));
        LOG("our_proc: 0x%llx", proc);
        uint64_t our_ucred = rk64(proc + 0x100); // 0x100 - off_p_ucred
        LOG("ucred: 0x%llx", our_ucred);
        uint64_t cr_label = rk64(our_ucred + 0x78); // 0x78 - off_ucred_cr_label
        LOG("cr_label: 0x%llx", cr_label);
        uint64_t sandbox = rk64(cr_label + 0x10);
        LOG("sandbox_slot: 0x%llx", sandbox);
        
        LOG("Setting sandbox_slot to 0");
            // Set sandbox pointer to 0;
        wk64(cr_label + 0x10, 0);
            // Are we free?
        createFILE("/var/mobile/.elytest", nil);
        FILE *f = fopen("/var/mobile/.elytest", "w");
        if(!f){
        LOG("ERR: Failed to set Sandbox_slot to 0");
        LOG("ERR: Failed to Unsanbox");
        SetButtonText("Error: Escaping Sandbox");
        CredsTool(0, 1, NO, NO);
        goto out;
        }
        
        LOG("Escaped Sandbox");
        

        LOG("Here comes the fun..");
            // Initiate jelbrekLibE
        errs = init_with_kbase(tfpzero, KernelBase, kernel_exec);
        if(errs != 0) {
        LOG("ERR: Failed to initialize jelbrekLibE");
        SetButtonText("Error: Initializing JelbrekLibE");
        goto out;
        }
        LOG("[*] Initialized jelbrekLibE");
        
        LOG("Exporting tfp0 to HSP4..");
        
        // Export tfp0
        Set_tfp0HSP4(tfpzero);
        
        // wait for export to finish
        usleep(1000);
        
        // Platform ourselves
        errs = EscalateTask(our_task);
        ASSERT(errs == 0, "ERR: Failed to platform ourselves", "Error: Escalating Task");
    }
        
        // Get offsets to kernel functions
        errs = GatherOffsets();
        ASSERT(errs == 0, "ERR: Failed to get offsets", "Error: Gathering Offsets");
    
        FillProcs(); // grab important processes and etc.
        PreSpeed(tfpzero); // gang gang
        
        // ------------ Remount RootFS -------------- //
        
        // remount.m for code
        errs = RemountFS(kernel_proc);
        
    /* error checks in remount - its not pretty but "it's honest work" */
        
        if (errs == _NOKERNPROC) {
            SetButtonText("Error: Kernel Process");
            goto out;
        } else if (errs == _NODISK) {
            SetButtonText("Error: Finding disk0s1s1");
            goto out;
        } else if (errs == _NOKERNCREDS) {
            SetButtonText("Error: Grabbing Kerncreds");
            goto out;
        } else if (errs == _NOMNTPATH) {
            SetButtonText("Error: Creating Mount Path");
            goto out;
        } else if(errs == _REVERTMNTFAILED) {
            SetButtonText("Error: Reverting MntPath");
            goto out;
        } else if (errs == _MOUNTFAILED) {
            SetButtonText("Error: Mounting FS");
            goto out;
        } else if (errs == _MOUNTFAILED2) {
            SetButtonText("Error: Mounting FS in new path");
            goto out;
        } else if (errs == _NONEWDISK) {
            SetButtonText("Error: Finding New Disk");
            goto out;
        } else if (errs == _RENAMEFAILED) {
            SetButtonText("Error: Renaming Snapshot");
            goto out;
        }
        
        // After renaming the snapshot
        if (errs == _RENAMEDSNAP) {
            // - broken lol - MESSAGE("Snapshot successfully renamed, device will be rebooted. Run Elysian again to finish Jailbreaking", true);
            usleep(2000);
            reboot(0);
        } else if (errs == _NOSNAP) {
            SetButtonText("Error: Finding BootSnapshot");
            goto out;
        } else if (errs == _NOUPDATEDDISK) {
            SetButtonText("Error: Updating disk01s1");
            goto out;
        } else if (errs == _FSTESTFAILED){
            SetButtonText("Error: RootFS Test File");
            goto out;
        } else if (errs == _REMOUNTSUCCESS) {
            LOG("Remounted RootFS");
        } else { // idk how this would happen
            SetButtonText("Error: Unkown Remount Error");
            goto out;
        }
        
        CredsTool(kernel_proc, 0, NO, YES); // get kern creds for amfidestroyer
        
        // Nuke AMFI >:)
        errs = amfidestroyer(amfi_pid, our_proc);
        ASSERT(errs == 0, "ERR: Failed to patch amfid!", "Error: Patching amfid");
    
        // setup bootstrap
        errs = createbootstrap(kernel_proc);
        ASSERT((bool)errs == true, "ERR: Failed creating bootstrap!", "Error: Creating Bootstrap");
    
        

        out:
        // clean up
        term_jelbrek();
        CredsTool(0, 1, NO, NO);
        return;
 
}

@end

