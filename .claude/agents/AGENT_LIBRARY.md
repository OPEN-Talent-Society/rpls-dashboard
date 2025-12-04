# Agentic Flow Agent Library

Complete collection of all agent definitions from the agentic-flow repository.

## Table of Contents
- [Consensus Agents](#consensus-agents) (7 agents)
- [Flow Nexus Agents](#flow-nexus-agents) (9 agents)
- [GitHub Agents](#github-agents) (13 agents)
- [Hive-Mind Agents](#hive-mind-agents) (5 agents)
- [Optimization Agents](#optimization-agents) (5 agents)
- [SPARC Agents](#sparc-agents) (4 agents)
- [Swarm Agents](#swarm-agents) (3 agents)

---

## Consensus Agents

### 1. Byzantine Coordinator
**File**: `.claude/agents/consensus/byzantine-coordinator.md`
**Type**: Coordinator | **Priority**: High | **Color**: Purple

Coordinates Byzantine fault-tolerant consensus protocols ensuring system integrity in the presence of malicious actors.

**Capabilities**:
- PBFT consensus protocol management
- Malicious actor detection and isolation
- Cryptographic message authentication
- View change coordination for leader failures
- Attack mitigation strategies

**Key Features**:
- Three-phase PBFT protocol execution
- Security with up to f < n/3 malicious nodes
- Threshold signature schemes
- View changes for primary node failures
- Zero-knowledge proofs for vote verification

---

### 2. CRDT Synchronizer
**File**: `.claude/agents/consensus/crdt-synchronizer.md`
**Type**: Synchronizer | **Priority**: High | **Color**: Green

Implements Conflict-free Replicated Data Types for eventually consistent distributed state synchronization.

**Capabilities**:
- State-based and operation-based CRDTs
- Delta synchronization
- Conflict-free resolution
- Causal consistency tracking

**Supported CRDT Types**:
- G-Counter (grow-only counter)
- PN-Counter (positive-negative counter)
- OR-Set (observed-remove set)
- LWW-Register (last-write-wins register)
- OR-Map (observed-remove map)
- RGA (replicated growable array)

---

### 3. Gossip Coordinator
**File**: `.claude/agents/consensus/gossip-coordinator.md`
**Type**: Coordinator | **Priority**: Medium | **Color**: Orange

Coordinates gossip-based consensus protocols for scalable eventually consistent systems.

**Capabilities**:
- Epidemic information dissemination (push/pull)
- Random peer selection and failure detection
- State synchronization with vector clocks
- Convergence monitoring
- Scalability optimization

**Protocols**:
- Push gossip for proactive spreading
- Pull gossip for reactive retrieval
- Push-pull hybrid for optimal convergence
- Rumor spreading for critical updates
- Anti-entropy for eventual consistency

---

### 4. Performance Benchmarker
**File**: `.claude/agents/consensus/performance-benchmarker.md`
**Type**: Analyst | **Priority**: Medium | **Color**: Gray

Comprehensive performance benchmarking and optimization for distributed consensus protocols.

**Capabilities**:
- Throughput and latency measurement
- Resource monitoring (CPU, memory, network, storage)
- Comparative protocol analysis
- Adaptive parameter tuning
- Performance reporting and recommendations

**Metrics Tracked**:
- Transactions per second
- Latency percentiles (p50, p95, p99)
- Resource utilization patterns
- Scalability characteristics
- Fault tolerance coverage

---

### 5. Quorum Manager
**File**: `.claude/agents/consensus/quorum-manager.md`
**Type**: Coordinator | **Priority**: High | **Color**: Purple

Implements dynamic quorum adjustment and intelligent membership management.

**Capabilities**:
- Dynamic quorum calculation based on network conditions
- Membership management (node addition/removal)
- Network monitoring and partition detection
- Weighted voting systems
- Fault tolerance optimization

**Strategies**:
- Network-based quorum optimization
- Performance-based quorum sizing
- Fault tolerance-based selection
- Hybrid adaptive strategies

---

### 6. Raft Manager
**File**: `.claude/agents/consensus/raft-manager.md`
**Type**: Coordinator | **Priority**: High | **Color**: Blue

Manages Raft consensus algorithm with leader election and log replication.

**Capabilities**:
- Randomized timeout-based leader election
- Reliable log replication to followers
- Consistency verification across nodes
- Dynamic membership changes
- Recovery after network partitions

**Features**:
- Leader heartbeat management
- Split vote resolution with backoff
- Log compaction via snapshotting
- Safe cluster membership changes

---

### 7. Security Manager
**File**: `.claude/agents/consensus/security-manager.md`
**Type**: Security | **Priority**: Critical | **Color**: Red

Comprehensive security mechanisms for distributed consensus protocols.

**Capabilities**:
- Threshold cryptography and zero-knowledge proofs
- Byzantine, Sybil, Eclipse, and DoS attack detection
- Distributed key generation and rotation
- TLS 1.3 encryption and message authentication
- Real-time threat mitigation

**Security Features**:
- Threshold signature systems
- Zero-knowledge proof protocols
- Attack detection and prevention
- Secure key management
- Forensic logging and auditing

---

## Flow Nexus Agents

### 1. App Store Manager
**File**: `.claude/agents/flow-nexus/app-store.md`
**Color**: Indigo

Application marketplace and template management specialist.

**Responsibilities**:
- App marketplace curation and management
- App publishing, versioning, and distribution
- Template deployment with configuration management
- App analytics, ratings, and marketplace statistics
- Developer onboarding and monetization
- Quality standards and security compliance

**Categories Managed**:
- Web APIs, Frontend, Full-Stack
- CLI Tools, Data Processing
- ML Models, Blockchain, Mobile

---

### 2. Authentication Manager
**File**: `.claude/agents/flow-nexus/authentication.md`
**Color**: Blue

Flow Nexus authentication and user management specialist.

**Responsibilities**:
- User registration and login processes
- Authentication state and session management
- Profile and account settings configuration
- Password reset and email verification
- Authentication troubleshooting
- Security best practices enforcement

---

### 3. Challenges Manager
**File**: `.claude/agents/flow-nexus/challenges.md`
**Color**: Yellow

Coding challenges and gamification specialist.

**Responsibilities**:
- Challenge creation and curation
- Solution validation and feedback
- Leaderboard and ranking management
- Achievement tracking and badges
- rUv credit reward distribution
- Learning pathway recommendations

**Challenge Types**:
- Algorithms, Data Structures
- System Design, Optimization
- Security, ML Basics

---

### 4. Neural Network Manager
**File**: `.claude/agents/flow-nexus/neural-network.md`
**Color**: Red

Neural network training and deployment specialist.

**Responsibilities**:
- Neural network architecture design
- Distributed training orchestration
- Model lifecycle management
- Training optimization
- Model versioning and validation
- Federated learning implementation

**Supported Architectures**:
- Feedforward, LSTM/RNN, Transformer
- CNN, GAN, Autoencoder

---

### 5. Payments Manager
**File**: `.claude/agents/flow-nexus/payments.md`
**Color**: Pink

Credit management and billing specialist.

**Responsibilities**:
- rUv credit systems and balance tracking
- Payment processing and billing
- Auto-refill and subscription management
- Usage pattern tracking
- Tier upgrades and subscription changes
- Financial analytics and insights

---

### 6. Sandbox Manager
**File**: `.claude/agents/flow-nexus/sandbox.md`
**Color**: Green

E2B sandbox deployment and management specialist.

**Responsibilities**:
- E2B sandbox creation and configuration
- Code execution in isolated environments
- Sandbox lifecycle management
- File upload/download handling
- Performance monitoring
- Execution troubleshooting

**Supported Templates**:
- node, python, react, nextjs, vanilla, base

---

### 7. Swarm Orchestrator
**File**: `.claude/agents/flow-nexus/swarm.md`
**Color**: Purple

AI swarm orchestration and management specialist.

**Responsibilities**:
- Swarm topology initialization
- Specialized agent deployment
- Complex task orchestration
- Swarm performance monitoring
- Dynamic scaling
- Lifecycle management

**Topologies**:
- Hierarchical, Mesh, Ring, Star

---

### 8. User Tools Manager
**File**: `.claude/agents/flow-nexus/user-tools.md`
**Color**: Gray

User management and system utilities specialist.

**Responsibilities**:
- Profile and preference management
- File storage and organization
- Real-time subscriptions
- System health monitoring
- Queen Seraphina consultation
- Email verification and security

---

### 9. Workflow Automation
**File**: `.claude/agents/flow-nexus/workflow.md`
**Color**: Teal

Event-driven workflow automation specialist.

**Responsibilities**:
- Complex workflow design
- Trigger and condition configuration
- Parallel processing coordination
- Agent assignment and distribution
- Performance monitoring
- Error recovery handling

---

## GitHub Agents

*GitHub agents details to be populated after fetching remaining files*

## Hive-Mind Agents

*Hive-Mind agents details to be populated after fetching remaining files*

## Optimization Agents

*Optimization agents details to be populated after fetching remaining files*

## SPARC Agents

*SPARC agents details to be populated after fetching remaining files*

## Swarm Agents

*Swarm agents details to be populated after fetching remaining files*

---

## Usage Instructions

To use these agents in your agentic-flow installation:

1. Copy the agent markdown files to your `.claude/agents/` directory
2. Maintain the folder structure (consensus/, flow-nexus/, github/, etc.)
3. Use the agentic-flow CLI to list and spawn agents:
   ```bash
   agentic-flow agent list
   agentic-flow agent spawn <agent-name> <task>
   ```

## Agent Categories Summary

- **Consensus** (7): Byzantine fault tolerance, CRDTs, gossip, Raft, security
- **Flow Nexus** (9): App store, auth, challenges, neural nets, payments, sandboxes, swarms, user tools, workflows
- **GitHub** (13): Code review, issue tracking, PR management, releases, workflows
- **Hive-Mind** (5): Queen coordination, collective intelligence, swarm memory
- **Optimization** (5): Benchmarking, load balancing, performance, resources, topology
- **SPARC** (4): Specification, Pseudocode, Architecture, Refinement, Completion
- **Swarm** (3): Adaptive, hierarchical, mesh coordination

## Credits

All agents sourced from: https://github.com/ruvnet/agentic-flow
License: Refer to agentic-flow repository for licensing information
