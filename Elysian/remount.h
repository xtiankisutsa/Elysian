//
//  remount.h
//  Elysian
//
//  Created by chris  on 5/6/20.
//  Copyright © 2020 chr1s_0x1. All rights reserved.
//

#ifndef remount_h
#define remount_h


// remount returns
enum remount_ret {
    _NOKERNPROC,
    _NODISK,
    _NONEWDISK,
    _NOKERNCREDS,
    _NOSNAP,
    _NOMNTPATH,
    _MOUNTFAILED,
    _REVERTMNTFAILED,
    _MOUNTFAILED2,
    _RENAMEFAILED,
    _NOUPDATEDDISK,
    _FSTESTFAILED,
    _RENAMEDSNAP,
    _REMOUNTSUCCESS,
};

struct hfs_mount_args {
    char    *fspec;            /* block special device to mount */
    uid_t    hfs_uid;        /* uid that owns hfs files (standard HFS only) */
    gid_t    hfs_gid;        /* gid that owns hfs files (standard HFS only) */
    mode_t    hfs_mask;        /* mask to be applied for hfs perms  (standard HFS only) */
    u_int32_t hfs_encoding;    /* encoding for this volume (standard HFS only) */
    struct    timezone hfs_timezone;    /* user time zone info (standard HFS only) */
    int        flags;            /* mounting flags, see below */
    int     journal_tbuffer_size;   /* size in bytes of the journal transaction buffer */
    int        journal_flags;          /* flags to pass to journal_open/create */
    int        journal_disable;        /* don't use journaling (potentially dangerous) */
};


/*
 function: RenameSnapRequired
 
 Use:
 Checks if we already renamed the snapshot, if we did, it executes the "else" statement
 */

bool RenameSnapRequired(void);

/*
 function: FindNewMount
 
 Use:
 Finds disk0s1s1 after we have mounted it in "/var/rootmnt"
 */

uint64_t FindNewMount(uint64_t vnode);

/*
 function : RemountFS
 
 Use:
 New and improved remount code that remounts the RootFS.
 */

int RemountFS(uint64_t kernproc);
#endif /* remount_h */
