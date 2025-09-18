# Research Funding Smart Contract

A comprehensive Clarity smart contract for managing research proposals, funding distribution, milestone tracking, and payments on the Stacks blockchain.

## Overview

This smart contract enables decentralized research funding through a structured proposal system with milestone-based payments. It includes community voting, reviewer authorization, and automated fund distribution based on milestone completion.

## Features

- **Proposal Management**: Submit, review, and track research proposals
- **Milestone-Based Funding**: Break down projects into up to 10 milestones with percentage-based funding
- **Community Voting**: Democratic approval process for funded proposals
- **Reviewer System**: Authorized reviewers for proposal and milestone evaluation
- **Reputation System**: Track researcher performance and build credibility
- **Automated Payments**: Automatic fund release upon milestone approval
- **Emergency Controls**: Cancel proposals and reject milestones when necessary

## Contract Architecture

### Core Components

1. **Proposals**: Research project submissions with funding requirements
2. **Milestones**: Project deliverables with specific funding allocations
3. **Researchers**: User profiles tracking performance and reputation
4. **Reviewers**: Authorized evaluators for proposals and milestones
5. **Voting System**: Community-driven proposal approval mechanism
6. **Funding Pool**: Central treasury for project funding

### Proposal Lifecycle

1. **Submitted** (0): Initial proposal submission
2. **Under Review** (1): Being evaluated by authorized reviewers
3. **Approved** (2): Passed reviewer evaluation, open for community voting
4. **Active** (3): Community approved, funding allocated, work in progress
5. **Completed** (4): All milestones completed successfully
6. **Rejected** (5): Failed review or community vote
7. **Cancelled** (6): Terminated by researcher or contract owner

### Milestone Status

- **Pending** (0): Awaiting researcher submission
- **Submitted** (1): Evidence provided, awaiting review
- **Approved** (2): Accepted by reviewer, funds released
- **Rejected** (3): Not accepted, requires resubmission

## Contract Functions

### Administrative Functions

#### `add-funding(amount: uint)`
- **Access**: Contract owner only
- **Purpose**: Add funds to the funding pool
- **Parameters**: Amount in microSTX to add

#### `authorize-reviewer(reviewer: principal)`
- **Access**: Contract owner only
- **Purpose**: Grant reviewer privileges to a user
- **Parameters**: Principal address of the new reviewer

#### `revoke-reviewer(reviewer: principal)`
- **Access**: Contract owner only
- **Purpose**: Remove reviewer privileges from a user
- **Parameters**: Principal address of the reviewer

#### `update-min-voting-period(blocks: uint)`
- **Access**: Contract owner only
- **Purpose**: Set minimum voting duration
- **Parameters**: Number of blocks (minimum 10)

#### `update-quorum-percentage(percentage: uint)`
- **Access**: Contract owner only
- **Purpose**: Set required quorum for voting
- **Parameters**: Percentage (1-100)

### Core Functions

#### `submit-proposal`
Submit a new research proposal with milestones.

**Parameters**:
- `title`: Project title (max 256 characters)
- `description`: Project description (max 1024 characters)
- `funding-amount`: Total funding requested in microSTX
- `duration-blocks`: Project duration in blocks
- `milestone-titles`: List of milestone titles (max 10)
- `milestone-descriptions`: List of milestone descriptions (max 10)
- `milestone-percentages`: Funding percentage for each milestone (must sum to 100)
- `milestone-deadlines`: Deadline blocks for each milestone

**Requirements**:
- All milestone arrays must have equal length
- Percentages must sum to 100
- Maximum 10 milestones
- Valid input data

#### `review-proposal(proposal-id: uint, approve: bool)`
- **Access**: Authorized reviewers only
- **Purpose**: Review and approve/reject submitted proposals
- **Effect**: Approved proposals enter community voting phase

#### `vote-on-proposal(proposal-id: uint, vote: bool)`
- **Access**: Any user (one vote per proposal)
- **Purpose**: Community voting on approved proposals
- **Requirements**: Voting period must be active, user hasn't voted

#### `finalize-voting(proposal-id: uint)`
- **Access**: Any user
- **Purpose**: Complete voting process and activate passing proposals
- **Requirements**: Voting period ended, sufficient funds available

#### `submit-milestone(milestone-id: uint, evidence-hash: buff)`
- **Access**: Proposal researcher only
- **Purpose**: Submit completion evidence for a milestone
- **Parameters**: Milestone ID and hash of evidence

#### `approve-milestone(milestone-id: uint)`
- **Access**: Authorized reviewers only
- **Purpose**: Approve milestone and release funds
- **Effect**: Transfers allocated funds to researcher

#### `reject-milestone(milestone-id: uint)`
- **Access**: Authorized reviewers only
- **Purpose**: Reject milestone submission
- **Effect**: Milestone returns to pending status

#### `cancel-proposal(proposal-id: uint)`
- **Access**: Proposal researcher or contract owner
- **Purpose**: Cancel proposal before completion
- **Requirements**: Proposal must be in submitted or approved status

### Read-Only Functions

#### `get-proposal(proposal-id: uint)`
Returns complete proposal information including status, funding details, and milestone progress.

#### `get-milestone(milestone-id: uint)`
Returns milestone details including status, funding percentage, and deadline.

#### `get-researcher(researcher: principal)`
Returns researcher profile with statistics and reputation score.

#### `is-authorized-reviewer(reviewer: principal)`
Checks if a user has reviewer privileges.

#### `get-vote-count(proposal-id: uint)`
Returns voting statistics for a proposal.

#### `get-user-vote(proposal-id: uint, voter: principal)`
Returns a user's vote on a specific proposal.

#### `get-funding-pool-balance()`
Returns current available funding in the pool.

#### `get-proposal-counter()`
Returns the total number of proposals submitted.

#### `get-proposal-milestone(proposal-id: uint, milestone-index: uint)`
Returns milestone details by proposal ID and milestone index.

## Error Codes

- `u100`: Owner-only function
- `u101`: Resource not found
- `u102`: Unauthorized access
- `u103`: Invalid amount
- `u104`: Insufficient funds
- `u105`: Proposal already exists
- `u106`: Invalid status for operation
- `u107`: Milestone not ready for operation
- `u108`: User already voted
- `u109`: Voting period closed
- `u110`: Invalid milestone data
- `u111`: Proposal not active
- `u112`: Milestone already completed
- `u113`: Invalid input parameters