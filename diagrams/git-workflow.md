# Git and Repository Workflow Diagrams

This file contains mermaid diagrams explaining the git workflow and repository structure for the vscode-performance-fix project.

---

## 1. Repository Structure & Organization

```mermaid
graph TB
    subgraph "Documentation"
        README[README.md<br/>Main Entry Point]
        COMPLETE[COMPLETE_SOLUTION_SUMMARY.md<br/>Phase 1 Results]
        PERF[PERFORMANCE_FIX_SUCCESS.md<br/>Success Metrics]
        DIAGRAMS[diagrams/<br/>Mermaid Visualizations]
    end

    subgraph "Problem Analysis Docs"
        BACKPRESSURE[backpressure_analysis_report.md]
        NVME_ANALYSIS[NVME_* Analysis Docs]
        IRQ_ANALYSIS[IRQ_* Analysis Docs]
        NETWORK_ANALYSIS[NETWORK_* Analysis Docs]
        POLICY[POLICY_ROUTING_EXPLAINED.md]
    end

    subgraph "Diagnostic Tools"
        DIAG_IO[diagnose_io_freeze_nosudo.sh]
        COUNT_GIT[count_all_git_files.sh]
        ANALYZE_GIT[analyze_git_repos.sh]
        ANALYZE_IRQ[analyze_all_irq_starvation.sh]
    end

    subgraph "Cleanup Tools"
        CLEANUP_PY[cleanup_python_cache.sh]
        GIT_SMART[git_smart_cleanup.sh]
        GIT_COMP[git_cleanup_comprehensive.sh]
        AGGRESSIVE[aggressive_git_cleanup.sh]
        DEGIT[aggressive_degit_phase2.sh]
    end

    subgraph "Fix Scripts"
        FIX_DIRTY[fix_dirty_page_freeze.sh]
        FIX_NVME[fix_nvme_irq_starvation*.sh]
        FIX_NET[fix_network_*.sh]
        CONFIG_POLICY[configure_policy_routing.sh]
        CONFIG_IRQ[configure_irqbalance_oneshot.sh]
    end

    subgraph "Monitoring Tools"
        MONITOR_NVME[monitor_nvme_performance.sh]
        NVME_STATUS[nvme-status.sh]
        VSCODE_GPU[vscode_gpu_status.sh]
        SYS_STATUS[system-status-motd.sh]
    end

    README --> DIAGRAMS
    README --> COMPLETE
    README --> PERF

    COMPLETE --> Problem Analysis Docs
    PERF --> Problem Analysis Docs

    README --> Diagnostic Tools
    README --> Cleanup Tools
    README --> Fix Scripts

    classDef docStyle fill:#e1f5ff,stroke:#01579b
    classDef toolStyle fill:#fff3e0,stroke:#e65100
    classDef fixStyle fill:#e8f5e9,stroke:#2e7d32

    class README,COMPLETE,PERF,DIAGRAMS docStyle
    class DIAG_IO,COUNT_GIT,ANALYZE_GIT,ANALYZE_IRQ toolStyle
    class FIX_DIRTY,FIX_NVME,FIX_NET,CONFIG_POLICY fixStyle
```

---

## 2. Git Branch Strategy

```mermaid
gitGraph
    commit id: "Initial: VS Code stuttering"
    commit id: "Identify backpressure issue"
    branch investigation/file-bloat
    checkout investigation/file-bloat
    commit id: "Add diagnostic scripts"
    commit id: "Analyze 1.9M files"
    commit id: "Find 338K Python cache"
    checkout main
    merge investigation/file-bloat tag: "v1.0-diagnostics"

    branch fix/python-cache
    checkout fix/python-cache
    commit id: "Create cleanup script"
    commit id: "Remove 338K cache files"
    checkout main
    merge fix/python-cache tag: "v1.1-cache-cleanup"

    branch fix/dirty-pages
    checkout fix/dirty-pages
    commit id: "Identify vm.dirty_ratio issue"
    commit id: "Create fix script"
    commit id: "Test freeze elimination"
    checkout main
    merge fix/dirty-pages tag: "v1.2-freeze-fix"

    branch feature/network-optimization
    checkout feature/network-optimization
    commit id: "Analyze network freezes"
    commit id: "Implement policy routing"
    commit id: "Fix service conflicts"
    commit id: "Post-reboot verification"
    checkout main
    merge feature/network-optimization tag: "v2.0-network"

    branch feature/nvme-irq
    checkout feature/nvme-irq
    commit id: "Analyze NVMe IRQ starvation"
    commit id: "Configure write queues"
    commit id: "Optimize IRQ distribution"
    checkout main
    merge feature/nvme-irq tag: "v2.1-nvme"

    branch feature/documentation
    checkout feature/documentation
    commit id: "Add mermaid diagrams"
    commit id: "Restructure README"
    checkout main
    merge feature/documentation tag: "v3.0-docs"
```

---

## 3. Development Workflow

```mermaid
flowchart TD
    A[User Reports Issue] --> B[Create Diagnostic Script]
    B --> C{Issue Identified?}
    C -->|No| D[Investigate Further]
    D --> B
    C -->|Yes| E[Document Root Cause]

    E --> F[Create Fix Script]
    F --> G[Test Fix]
    G --> H{Fix Works?}
    H -->|No| I[Refine Fix]
    I --> F
    H -->|Yes| J[Document Solution]

    J --> K[Create Verification Script]
    K --> L[Test Persistence]
    L --> M{Survives Reboot?}
    M -->|No| N[Create Systemd Service]
    N --> L
    M -->|Yes| O[Update Documentation]

    O --> P[Commit Changes]
    P --> Q[Push to Branch]
    Q --> R[Create PR]
    R --> S[Merge to Main]

    style A fill:#ffebee
    style E fill:#fff3e0
    style J fill:#e8f5e9
    style S fill:#e1f5ff
```

---

## 4. Tool Dependency Graph

```mermaid
graph LR
    subgraph "User Actions"
        USER[User Experience:<br/>Stuttering/Freezes]
    end

    subgraph "Diagnostics"
        DIAG1[diagnose_io_freeze_nosudo.sh]
        DIAG2[count_all_git_files.sh]
        DIAG3[analyze_git_repos.sh]
        DIAG4[analyze_all_irq_starvation.sh]
    end

    subgraph "Analysis Output"
        METRICS[Performance Metrics:<br/>Files, IRQs, Queues]
    end

    subgraph "Fix Selection"
        DECISION{Which Fix?}
    end

    subgraph "Cleanup Path"
        CLEAN1[cleanup_python_cache.sh]
        CLEAN2[git_smart_cleanup.sh]
        CLEAN3[aggressive_git_cleanup.sh]
    end

    subgraph "System Fix Path"
        FIX1[fix_dirty_page_freeze.sh]
        FIX2[fix_nvme_irq_starvation.sh]
        FIX3[fix_network_irq_distribution.sh]
        FIX4[configure_policy_routing.sh]
    end

    subgraph "Verification"
        VERIFY[monitor_* scripts]
        STATUS[*-status scripts]
    end

    subgraph "Persistence"
        SYSTEMD[Systemd Services]
        GRUB[GRUB Config]
        SYSCTL[Sysctl Settings]
    end

    USER --> DIAG1
    USER --> DIAG2
    USER --> DIAG3
    USER --> DIAG4

    DIAG1 --> METRICS
    DIAG2 --> METRICS
    DIAG3 --> METRICS
    DIAG4 --> METRICS

    METRICS --> DECISION

    DECISION -->|File Bloat| CLEAN1
    DECISION -->|Git Overhead| CLEAN2
    DECISION -->|System Freeze| FIX1
    DECISION -->|NVMe Issues| FIX2
    DECISION -->|Network Issues| FIX4

    CLEAN1 --> VERIFY
    CLEAN2 --> VERIFY
    FIX1 --> VERIFY
    FIX2 --> VERIFY
    FIX4 --> VERIFY

    VERIFY --> STATUS
    STATUS --> SYSTEMD
    STATUS --> GRUB
    STATUS --> SYSCTL

    classDef userClass fill:#ffebee,stroke:#c62828
    classDef diagClass fill:#fff3e0,stroke:#ef6c00
    classDef fixClass fill:#e8f5e9,stroke:#2e7d32
    classDef verifyClass fill:#e1f5ff,stroke:#01579b

    class USER userClass
    class DIAG1,DIAG2,DIAG3,DIAG4 diagClass
    class FIX1,FIX2,FIX3,FIX4,CLEAN1,CLEAN2,CLEAN3 fixClass
    class VERIFY,STATUS verifyClass
```

---

## 5. System Architecture - Full Stack

```mermaid
graph TB
    subgraph "User Space"
        VSCODE[VS Code<br/>Electron App]
        CHROME[Chrome Browser]
        OTHER[Other Apps]
    end

    subgraph "File System Layer"
        INOTIFY[Inotify<br/>File Watchers]
        GITFS[Git Repositories<br/>113K→6.5K files]
        CACHE[Python Cache<br/>338K→0 files]
    end

    subgraph "Kernel VM Layer"
        DIRTY[Dirty Page Cache<br/>ratio: 3%→20%<br/>bg_ratio: 1%→10%]
        SCHED[CPU Scheduler]
    end

    subgraph "Network Stack"
        POLICY[Policy Routing<br/>3 NICs, 3 IPs]
        QUEUES[Network Queues<br/>4→8 combined]
        IRQ_NET[Network IRQs<br/>Distributed]
    end

    subgraph "Storage Stack"
        NVME0[NVMe0 Intel 660P<br/>9 queues]
        NVME1[NVMe1 WD SN750<br/>49 queues, 16 write]
        IRQ_NVME[NVMe IRQs<br/>Balanced]
    end

    subgraph "Hardware"
        CPU[AMD Threadripper<br/>Multi-core]
        NIC[Intel X540-T2<br/>Dual 10G]
        STORAGE[Dual NVMe SSDs]
    end

    VSCODE --> INOTIFY
    CHROME --> Kernel VM Layer
    OTHER --> Kernel VM Layer

    INOTIFY --> GITFS
    INOTIFY --> CACHE

    GITFS --> DIRTY
    CACHE --> DIRTY

    DIRTY --> NVME0
    DIRTY --> NVME1

    POLICY --> QUEUES
    QUEUES --> IRQ_NET
    IRQ_NET --> CPU

    NVME0 --> IRQ_NVME
    NVME1 --> IRQ_NVME
    IRQ_NVME --> CPU

    QUEUES --> NIC
    NVME0 --> STORAGE
    NVME1 --> STORAGE

    classDef problemFixed fill:#e8f5e9,stroke:#2e7d32,stroke-width:3px
    classDef optimized fill:#e1f5ff,stroke:#01579b,stroke-width:2px

    class DIRTY,GITFS,CACHE problemFixed
    class POLICY,QUEUES,NVME1 optimized
```

---

## 6. Commit Message Pattern

This repository follows a consistent commit message pattern:

```
<type>: <description>

<optional body>

<optional footer>
```

### Commit Types

- **Fix**: Bug fixes and issue resolutions
- **Add**: New features, scripts, or documentation
- **Update**: Modifications to existing functionality
- **Refactor**: Code restructuring without behavior change
- **Docs**: Documentation-only changes
- **Test**: Test-related changes
- **Chore**: Maintenance tasks

### Examples from This Repo

```mermaid
gantt
    title Commit Timeline (Chronological)
    dateFormat YYYY-MM-DD
    section Phase 1: File Bloat
    Add diagnostic scripts         :2025-10-17, 1d
    Fix: Python cache cleanup      :2025-10-17, 1d
    Fix: Git global excludes       :2025-10-17, 1d
    section Phase 2: System Freezes
    Fix: Dirty page writeback      :2025-10-18, 1d
    Add kernel parameter docs      :2025-10-18, 1d
    section Phase 3: Network
    Fix: Network service conflict  :2025-10-18, 1d
    Add policy routing             :2025-10-18, 1d
    Update: Post-reboot verify     :2025-10-18, 1d
    section Phase 4: NVMe
    Add: NVMe IRQ analysis         :2025-10-18, 1d
    Fix: IRQ balancing oneshot     :2025-10-18, 1d
    section Phase 5: Docs
    Add: Mermaid diagrams          :2025-11-14, 1d
    Update: readme.md              :2025-11-14, 1d
```

---

## 7. File Organization Strategy

```mermaid
mindmap
  root((Repository))
    Documentation
      README.md - Main guide
      *_SUMMARY.md - Phase summaries
      *_ANALYSIS.md - Technical deep dives
      diagrams/ - Visual guides
    Scripts
      Diagnostics
        diagnose_*.sh
        analyze_*.sh
        count_*.sh
      Fixes
        fix_*.sh
        configure_*.sh
        apply_*.sh
      Cleanup
        cleanup_*.sh
        aggressive_*.sh
      Monitoring
        monitor_*.sh
        *-status.sh
    Systemd Services
      *.service files
      Service management scripts
    Configuration
      GRUB parameters
      Sysctl settings
      Network configs
```

---

## 8. Issue Resolution Flow

```mermaid
stateDiagram-v2
    [*] --> Symptom: User reports issue
    Symptom --> Diagnose: Run diagnostic scripts
    Diagnose --> Analysis: Gather metrics
    Analysis --> RootCause: Identify problem

    RootCause --> FileBloat: 1.9M files detected
    RootCause --> DirtyPages: vm.dirty_ratio too low
    RootCause --> NetworkAsym: Asymmetric routing
    RootCause --> NVMEStarve: IRQ starvation

    FileBloat --> CleanupPython: Remove cache
    FileBloat --> CleanupGit: Degit repos
    CleanupPython --> Verify
    CleanupGit --> Verify

    DirtyPages --> FixKernel: Adjust sysctl
    FixKernel --> MakePersistent: Update /etc/sysctl.conf
    MakePersistent --> Verify

    NetworkAsym --> PolicyRoute: Configure routing
    PolicyRoute --> SystemdService: Create service
    SystemdService --> Verify

    NVMEStarve --> IncreaseQueues: Add write queues
    IncreaseQueues --> GRUBConfig: Update kernel params
    GRUBConfig --> Verify

    Verify --> RebootTest: Test persistence
    RebootTest --> Success: Issue resolved
    RebootTest --> Symptom: Issue persists

    Success --> Document: Update README
    Document --> [*]
```

---

## Usage

These diagrams can be rendered in:
- GitHub (native mermaid support)
- VS Code (with Mermaid extension)
- GitLab
- Mermaid Live Editor (https://mermaid.live/)

To export as images:
```bash
npm install -g @mermaid-js/mermaid-cli
mmdc -i git-workflow.md -o git-workflow.svg
```
