# mini-project-os

Operating Systems Mini-Project — compile and install a Linux kernel on Ubuntu 24.04 LTS, with a step-by-step worklog of everything actually done.

## Members

| Nickname | Name | Student ID | Folder |
|----------|------|------------|--------|
| — | Kamonnat Seetakai | 67070501001 | — |
| Pink | Benyapha Rattanakhunodom | 67070501030 | `member/Pink/` |
| Posh | Pawarisa Thongchua | 67070501032 | `member/Posh/` |
| — | Chanya Poolketkij | 67070501058 | — |
| Japan | Theeraphat Jaingam | 67070501063 | `member/Japan/` |
| Fuse | Onsinee Chotchuangsakulchai | 67070501078 | `member/Fuse/` |

Each member's work and worklog lives in their own folder under `member/`.

## File Structure

```
mini-project-os/
├── README.md
└── member/
    ├── Fuse/
    │   ├── Kernel-Compilation-Worklog.md
    │   └── Image/        
    ├── Pink/
    └── Posh/
```

## Project Status

| Member | Environment | Status |
|--------|-------------|--------|
| Fuse | WSL2 Ubuntu 24.04 | Build + boot passed (`6.8.12-fuse2005`), worklog done |
| Pink | — | Pending |
| Posh | — | Pending |
| Japan | — | Pending |

## Build Results Summary

| Member | CPU / RAM | Build time (`make -j`) | Kernel result | Boot test |
|--------|-----------|------------------------|---------------|-----------|
| Fuse | Ryzen 7 8840U, 16 vCPU / 15 GiB | ~27 min (`-j16`) | `6.8.12-fuse2005` | Passed (WSL2 + rollback round-trip) |
| Pink | TBD | TBD | TBD | TBD |
| Posh | TBD | TBD | TBD | TBD |
| Japan | TBD | TBD | TBD | TBD |

Each member fills in their own row after their build finishes (spec section 5.1).

## Deliverables Checklist

- [x] Fuse worklog (`member/Fuse/Kernel-Compilation-Worklog.md`)
- [ ] Pink worklog
- [ ] Posh worklog
- [ ] Japan worklog
- [ ] Screenshots in each member's `Image/` folder (GRUB menu, `uname -r`, rollback)
- [ ] Team comparison table completed (all rows filled)
- [ ] Final group report (`REPORT.md`)

## References

- [Ubuntu Kernel Build Guide](https://ubuntu.com/kernel/docs/how-to/develop-customise/build-kernel/)
- [Enable kernel source repositories](https://ubuntu.com/kernel/docs/how-to/source-code/enable-source-repositories/)
- [Obtain kernel source with Git](https://ubuntu.com/kernel/docs/how-to/source-code/obtain-kernel-source-git/)
- [Linux kernel archives](https://cdn.kernel.org/pub/linux/kernel/v6.x/)

---

# CPE 333 Operating Systems: Mini-Project 1 Specification

**Course:** CPE 333 Operating Systems
**Department:** Computer Engineering, Faculty of Engineering, KMUTT
**Project Title:** Ubuntu Kernel Compilation and Installation Report

## 1. Project Overview & Objective

This mini-project provides hands-on experience in compiling and installing a new Ubuntu kernel. The primary goal is to understand operating system internals, kernel deployment procedures, hardware configuration management, and system recovery mechanisms.

## 2. Requirements & Instructions

1. **Team Formation:**
   - Group size: 6 – 8 members.
   - Task strategy: Decentralized parallel trials (each member independently compiles and installs the kernel on their own machine/VM to compare performance and mitigate technical risk).

2. **Official Documentation & Resources:**
   - Study and follow the official build instructions: [Ubuntu Kernel Build Guide](https://ubuntu.com/kernel/docs/how-to/develop-customise/build-kernel/)

3. **Deployment Environment (Recommended Hint):**
   - Deploy the new kernel within a Linux Virtual Machine using virtualization software (e.g., **VMware Workstation** or **Oracle VirtualBox**).
   - *Reason:* Using a VM ensures full control over boot parameters and enables safe rollback to the previous kernel version via the GRUB bootloader in case the system becomes unstable.

## 3. Scope of Work & Report Structure

The group must submit a comprehensive report detailing the step-by-step process of how to compile and install the kernel. The report is structured into 5 primary sections:

### Section 1: System Environment Setup

- **1.1 Hardware Specifications and VM Allocation:** Host specs, VM CPU cores, RAM allocation, and storage space.
- **1.2 Virtualization Software and OS Details:** Virtualization platform version, OS release (`Ubuntu 24.04 LTS`), and initial kernel version (`uname -r`).

### Section 2: Kernel Compilation and Installation Procedure

- **2.1 Environment Setup and Package Dependencies:** Repository setup (`deb-src`) and installation of required build dependencies (`build-essential`, `libncurses-dev`, `bison`, `flex`, `libssl-dev`, `libelf-dev`, `dwarves`, etc.).
- **2.2 Obtaining and Extracting Kernel Source Code:** Downloading and unpacking the target kernel source code.
- **2.3 Kernel Configuration (`menuconfig`):** Setting up kernel options using `make menuconfig`.
- **2.4 Compiling the Kernel Source:** Executing parallel compilation (`make -j$(nproc)`), recording total build time and system resource usage.
- **2.5 Installing Kernel Modules and System Kernel:** Installing kernel modules (`make modules_install`) and deploying the kernel image (`make install`).

### Section 3: System Verification and Boot Testing

- **3.1 Boot Menu Configuration (GRUB):** Updating GRUB (`update-grub`) and capturing the bootloader selection menu.
- **3.2 Kernel Version Verification (`uname -r`):** Verifying the active kernel version after reboot.
- **3.3 Kernel Rollback Testing:** Demonstrating system recovery by reverting to the previous kernel version via GRUB.

### Section 4: Technical Challenges and Problem Resolution

- **4.1 Package and Source Repository Errors:** Documenting issues such as missing `deb-src` or WSL source incompatibilities and their resolutions.
- **4.2 System Resource Limitations:** Addressing disk space shortages or memory constraints during compilation.
- **4.3 Build Configuration and Compilation Errors:** Troubleshooting compile-time errors.

### Section 5: Comparison & Conclusion

- **5.1 Team Performance and Build Time Comparison:** Matrix table comparing hardware specifications, compilation duration, and build outcomes across all team members.
- **5.2 Project Conclusion and Key Learnings:** Summary of technical insights gained regarding OS kernel management.

## 4. Submission Deliverables

- A structured technical report (`REPORT.md` / Document) covering all step-by-step processes, screenshots, verification tests, and team comparison tables.
