# Kernel-networking-testsuite
Infrastructure for kernel networking tests.

## Usage
```bash
cd tests/single_tcp_tx/
./single_tcp_tx.sh
```

## Configuration
Most of the configurations (TSO, Affinity, etc) are automatic on both local and remote hosts. 
However, it is recommended to manually configure the tested kernel command line:

```bash
sudo vim /etc/default/grub
# Add this line
GRUB_CMDLINE_LINUX="noibrs noibpb mds=off tsx_async_abort=off nx_huge_pages=off nospectre_v1 spec_store_bypass_disable=off intel_iommu=off pti=off spectre_v2=off l1tf=off nospec_store_bypass_disable no_stf_barrier intel_pstate=disable mitigations=off idle=poll"

sudo update-grub
sudo reboot
```
