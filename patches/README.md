# Patch Deck

The QEMU-UAE integration patches originated from `reinauer/uae-ppc-plugin` commit
`f0eac22850ecedd1f874ee16d6ea06609be182cc`; this repository maintains its own
ordered deck, including downstream Windows-linking and PPC JIT-flush fixes.
They are applied to the official QEMU 11.1.3 release archive:

```text
https://download.qemu.org/qemu-11.1.3.tar.xz
SHA-256: 5a8289c7940dc77d3873c81a6c29ba3afe1446fc9d36e77fa1658cdbecb84b22
```

The archive signature is published alongside it as `qemu-11.1.3.tar.xz.sig`;
it was verified with QEMU's published release key during this update. The build
script verifies the pinned archive SHA-256 before extraction.

| Patch | Purpose | Scope |
| --- | --- | --- |
| `0001` | Adds the QEMU-UAE plugin API, PPC integration, and UAE host callbacks. | Runtime |
| `0002` | Allows PPC instruction encodings used by UAE guests. | Runtime compatibility |
| `0003` | Routes unassigned-memory diagnostics through UAE logging. | Diagnostics |
| `0004` | Adds the minimal QEMU shared-library build and symbol exports. | Build |
| `0005` | Initializes QEMU subsystems and PPC system state for the plugin. | Runtime |
| `0006` | Integrates modern libslirp with the UAE network callbacks. | Networking |
| `0007` | Selects static GLib, GModule, and zlib dependencies for Windows. | Windows build |
| `0008` | Links iconv for statically linked Windows dependencies. | Windows build |
| `0009` | Exports `ppc_cpu_flush_jit()` to notify QEMU of PPC code changes. | Runtime correctness |
| `0010` | Performs the requested TLB/TB flush at a safe PPC vCPU execution point. | Runtime correctness |
| `0011` | Keeps one RAMBlock per mapped region so code-change detection survives remaps. | Runtime correctness |

Patches `0001`–`0006` provide the plugin integration and guest compatibility;
`0007`–`0008` are needed only for static Windows builds. `0009`–`0011` keep PPC
execution coherent when UAE modifies shared PPC code or page tables, or remaps
memory. `0003` adds diagnostics rather than changing emulation behavior.
