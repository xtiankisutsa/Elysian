//
//  ViewController.m
//  Elysian
//
//  Created by chr1spwn3d on 3/2/20.
//  Copyright © 2020 chr1s_0x1. All rights reserved.
//

#import "ViewController.h"
#import "exploit.h"
#import "jelbrekLib.h"
#import "offsets.h"
#import "utils.h"

#define SYSTEM_VERSION_GREATER_THAN(v)              ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedDescending)

#define SYSTEM_VERSION_LESS_THAN(v)                 ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)


@interface ViewController ()

@property (weak, nonatomic) IBOutlet UILabel *Label;

@property (strong, nonatomic) IBOutlet UIView *section;

@end


@implementation ViewController




- (void)viewDidLoad {
    
    // Version check
    if(SYSTEM_VERSION_GREATER_THAN(@"13.3") || SYSTEM_VERSION_LESS_THAN(@"13.0")){
    printf("[-] Unsupported Firmware!\n");
    [JBButton setTitle:@"Unsupported" forState:UIControlStateNormal];
        JBButton.enabled = NO;
    }
    
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}




- (IBAction)JBGo:(id)sender {
    [JBButton setEnabled:NO];
    LOG("[*] Starting Exploit\n");
    __block mach_port_t tfpzero = MACH_PORT_NULL;
    tfpzero = get_tfp0();
    if(!MACH_PORT_VALID(tfpzero)){
        LOG("[-] Exploit Failed \n");
        LOG("[i] Please reboot and try again \n");
        [JBButton setTitle:@"Exploit Failed" forState:UIControlStateNormal];
        return;
    }
    LOGM("[i] tfp0 : 0x%x \n", tfpzero);
    
/* Start of Elysian Jailbreak **********************************************/
    LOG("[*] Starting Jailbreak Process \n");
    
    LOG("[+] Unsandboxing \n");
        // find our task
    uint64_t our_task = find_self_task();
    LOGM("[i] our_task: 0x%llx\n", our_task);
        // find the sandbox slot
    uint64_t our_proc = rk64(our_task + koffset(KSTRUCT_OFFSET_TASK_BSD_INFO));
    LOGM("[i] our_proc: 0x%llx\n", our_proc);
    uint64_t our_ucred = rk64(our_proc + 0x100); // 0x100 - off_p_ucred
    LOGM("[i] ucred: 0x%llx\n", our_ucred);
    uint64_t cr_label = rk64(our_ucred + 0x78); // 0x78 - off_ucred_cr_label
    LOGM("[i] cr_label: 0x%llx\n", cr_label);
    uint64_t sandbox = rk64(cr_label + 0x10);
    LOGM("[i] sandbox_slot: 0x%llx\n", sandbox);
    
    LOG("[+] Setting Sandbox Pointer to 0\n");
        // Set sandbox pointer to 0;
    wk64(cr_label + 0x10, 0);
        // Do we have root?
    createFILE("/var/mobile/.elytest", nil);
    FILE *f = fopen("/var/mobile/.elytest", "w");
    if(!f){
    LOG("[-] Failed to Unsanbox \n");
     [JBButton setTitle:@"Unsanbox failed" forState:UIControlStateNormal];
     return;
    }
    LOG("[*} Successfully set Sandbox Pointer to 0 \n");
    LOG("[*] Escaped Sandbox \n");
    
    LOG("[i] Here comes the fun..\n");
    // Initiate jelbrekLibE
    int ret = init_with_kbase(tfpzero, KernelBase, NULL);
    LOG("[i] Does this log run?");
    if(ret != 0) {
        LOG("[-] Failed to initiate jelbrekLibE\n");
     [JBButton setTitle:@"Failed to initiate jelbrekLibE" forState:UIControlStateNormal];
    }
    
    
    // Remount..
    LOG("[+] Remounting \n");
    
}

@end
