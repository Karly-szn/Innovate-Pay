# InnovatePay Smart Contract

A Stacks blockchain smart contract for milestone-based research funding with integrated reputation tracking.

## Overview

InnovatePay revolutionizes research funding by providing a transparent, milestone-driven funding mechanism that protects both funders and researchers. The contract features an on-chain reputation system that builds trust over time and ensures accountability in the research community.

## Key Features

### 🎯 Milestone-Based Funding
- Funds are released incrementally as milestones are completed
- Up to 10 milestones per project
- Detailed tracking of progress and deliverables
- Escrow protection for both parties

### 📊 Reputation System
- **Researcher Reputation**: Based on project and milestone completion rates
- **Funder Reputation**: Tracks funding history and reliability
- Transparent scoring system (0-100 scale)
- Historical performance tracking

### 🔒 Security & Trust
- On-chain escrow holds funds until milestone completion
- Access control ensures only authorized parties can modify projects
- Comprehensive error handling and validation
- Immutable audit trail

## Contract Architecture

### Data Structures

#### Projects
```clarity
{
  researcher: principal,
  funder: principal,
  title: (string-ascii 100),
  description: (string-ascii 500),
  total-funding: uint,
  released-funding: uint,
  milestone-count: uint,
  is-active: bool,
  created-at: uint
}
```

#### Milestones
```clarity
{
  title: (string-ascii 100),
  description: (string-ascii 300),
  funding-amount: uint,
  is-completed: bool,
  completed-at: (optional uint),
  reviewer: (optional principal)
}
```

#### Reputation Metrics
```clarity
; Researcher Reputation
{
  total-projects: uint,
  completed-projects: uint,
  total-milestones: uint,
  completed-milestones: uint,
  reputation-score: uint,
  last-updated: uint
}

; Funder Reputation
{
  total-funded-projects: uint,
  total-funded-amount: uint,
  reputation-score: uint,
  last-updated: uint
}
```

## Functions

### Public Functions

#### `create-project`
Creates a new research project and transfers funds to contract escrow.

**Parameters:**
- `researcher` (principal): Address of the researcher
- `title` (string-ascii 100): Project title
- `description` (string-ascii 500): Project description
- `milestone-count` (uint): Number of milestones (1-10)
- `total-funding` (uint): Total project funding in microSTX

**Returns:** Project ID or error

**Example:**
```clarity
(contract-call? .innovate-pay create-project 
  'ST1RESEARCHER123
  "AI Research Project"
  "Developing novel machine learning algorithms"
  u3
  u1000000)
```

#### `add-milestone`
Adds a milestone to an existing project (funder only).

**Parameters:**
- `project-id` (uint): Project identifier
- `milestone-id` (uint): Milestone identifier (0-indexed)
- `title` (string-ascii 100): Milestone title
- `description` (string-ascii 300): Milestone description
- `funding-amount` (uint): Amount to release for this milestone

**Returns:** Success boolean or error

#### `complete-milestone`
Marks a milestone as completed and releases funds to researcher (funder only).

**Parameters:**
- `project-id` (uint): Project identifier
- `milestone-id` (uint): Milestone identifier

**Returns:** Success boolean or error

#### `complete-project`
Marks the entire project as completed (funder only).

**Parameters:**
- `project-id` (uint): Project identifier

**Returns:** Success boolean or error

### Read-Only Functions

#### `get-project`
Retrieves project information.

#### `get-milestone`
Retrieves milestone details.

#### `get-researcher-reputation`
Returns researcher reputation metrics.

#### `get-funder-reputation`
Returns funder reputation metrics.

#### `get-project-count`
Returns total number of projects created.

#### `get-contract-balance`
Returns contract's STX balance.

## Reputation Scoring

### Researcher Score Calculation
```
project_completion_rate = (completed_projects / total_projects) * 100
milestone_completion_rate = (completed_milestones / total_milestones) * 100
reputation_score = min(project_completion_rate + milestone_completion_rate, 100)
```

### Funder Score Calculation
```
reputation_score = min(50 + (total_funded_projects / 2), 100)
```

## Error Codes

| Code | Error | Description |
|------|-------|-------------|
| 100  | ERR_NOT_AUTHORIZED | User not authorized for this action |
| 101  | ERR_PROJECT_NOT_FOUND | Project does not exist |
| 102  | ERR_MILESTONE_NOT_FOUND | Milestone does not exist |
| 103  | ERR_ALREADY_COMPLETED | Milestone already completed |
| 104  | ERR_INSUFFICIENT_FUNDS | Insufficient funding amount |
| 105  | ERR_INVALID_MILESTONE | Invalid milestone configuration |
| 106  | ERR_PROJECT_ALREADY_EXISTS | Project already exists |

## Usage Flow

1. **Project Creation**
   - Funder calls `create-project` with researcher details and funding
   - Funds are transferred to contract escrow
   - Project is created with unique ID

2. **Milestone Setup**
   - Funder calls `add-milestone` for each milestone
   - Milestones define deliverables and funding amounts

3. **Progress Tracking**
   - Researcher works on milestones
   - Funder reviews progress and calls `complete-milestone`
   - Funds are released to researcher automatically

4. **Project Completion**
   - Funder calls `complete-project` when all work is done
   - Reputation scores are updated for both parties

## Deployment

### Prerequisites
- [Clarinet CLI](https://github.com/hirosystems/clarinet)
- Stacks wallet with STX for deployment

### Steps

1. **Clone and Setup**
   ```bash
   git clone <repository>
   cd innovate-pay
   clarinet check
   ```

2. **Run Tests**
   ```bash
   npm install
   npm test
   ```

3. **Deploy to Testnet**
   ```bash
   clarinet deploy --testnet
   ```

4. **Deploy to Mainnet**
   ```bash
   clarinet deploy --mainnet
   ```

## Testing

The contract includes comprehensive tests covering:
- Project creation and management
- Milestone completion workflows
- Reputation system calculations
- Error handling scenarios
- Access control validation

Run tests with:
```bash
npm test
```

## Security Considerations

### Audited Components
- ✅ Access control mechanisms
- ✅ Fund transfer logic
- ✅ Input validation
- ✅ State management

### Known Limitations
- **Dispute Resolution**: No built-in arbitration mechanism
- **Time Constraints**: No automatic deadline enforcement
- **Partial Payments**: Milestones are all-or-nothing
- **Fund Recovery**: No cancellation/refund mechanism

### Recommendations
- Establish clear milestone criteria off-chain
- Consider multi-signature approval for large projects
- Implement external dispute resolution process
- Regular security audits for production use

## Use Cases

### Academic Research
- University research grants
- Graduate student funding
- Collaborative research projects
- Publication-based milestones

### Open Source Development
- Feature development bounties
- Code maintenance funding
- Documentation projects
- Community-driven initiatives

### Innovation Challenges
- Prototype development
- Proof-of-concept funding
- Technical feasibility studies
- R&D partnerships

## Integration Examples

### Web3 Frontend
```javascript
import { StacksTestnet } from '@stacks/network';
import { callReadOnlyFunction, makeContractCall } from '@stacks/transactions';

// Get project details
const projectData = await callReadOnlyFunction({
  contractAddress: 'ST1CONTRACTADDRESS',
  contractName: 'innovate-pay',
  functionName: 'get-project',
  functionArgs: [uintCV(1)],
  network: new StacksTestnet(),
});
```

### CLI Integration
```bash
# Create project via Stacks CLI
stx call_contract_func ST1CONTRACTADDRESS innovate-pay create-project \
  --network testnet \
  --fee 1000
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## License

MIT License - see LICENSE file for details.
