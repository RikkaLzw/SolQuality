
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


contract GovernanceVotingContract is Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;


    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant EXECUTION_DELAY = 2 days;
    uint256 public constant QUORUM_PERCENTAGE = 10;
    uint256 public constant PROPOSAL_THRESHOLD = 100;


    enum ProposalState {
        Pending,
        Active,
        Succeeded,
        Defeated,
        Executed,
        Cancelled
    }

    enum VoteType {
        Against,
        For,
        Abstain
    }


    struct Proposal {
        uint256 id;
        address proposer;
        string title;
        string description;
        uint256 startTime;
        uint256 endTime;
        uint256 executionTime;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        bool executed;
        bool cancelled;
        mapping(address => Receipt) receipts;
    }

    struct Receipt {
        bool hasVoted;
        VoteType vote;
        uint256 votes;
    }


    Counters.Counter private _proposalIds;
    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256) public votingPower;
    uint256 public totalVotingPower;


    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string title,
        string description,
        uint256 startTime,
        uint256 endTime
    );

    event VoteCast(
        address indexed voter,
        uint256 indexed proposalId,
        VoteType vote,
        uint256 votes
    );

    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCancelled(uint256 indexed proposalId);
    event VotingPowerUpdated(address indexed account, uint256 newPower);


    modifier onlyValidProposal(uint256 proposalId) {
        require(proposalId <= _proposalIds.current() && proposalId > 0, "Invalid proposal ID");
        _;
    }

    modifier onlyActiveProposal(uint256 proposalId) {
        require(_getProposalState(proposalId) == ProposalState.Active, "Proposal not active");
        _;
    }

    modifier onlySucceededProposal(uint256 proposalId) {
        require(_getProposalState(proposalId) == ProposalState.Succeeded, "Proposal not succeeded");
        _;
    }

    modifier hasVotingPower(address account) {
        require(votingPower[account] > 0, "No voting power");
        _;
    }

    modifier meetsProposalThreshold(address proposer) {
        require(votingPower[proposer] >= PROPOSAL_THRESHOLD, "Insufficient voting power to propose");
        _;
    }

    constructor() {}


    function createProposal(
        string memory title,
        string memory description
    ) external meetsProposalThreshold(msg.sender) returns (uint256) {
        require(bytes(title).length > 0, "Title cannot be empty");
        require(bytes(description).length > 0, "Description cannot be empty");

        _proposalIds.increment();
        uint256 proposalId = _proposalIds.current();

        Proposal storage proposal = proposals[proposalId];
        proposal.id = proposalId;
        proposal.proposer = msg.sender;
        proposal.title = title;
        proposal.description = description;
        proposal.startTime = block.timestamp;
        proposal.endTime = block.timestamp + VOTING_PERIOD;
        proposal.executionTime = proposal.endTime + EXECUTION_DELAY;

        emit ProposalCreated(
            proposalId,
            msg.sender,
            title,
            description,
            proposal.startTime,
            proposal.endTime
        );

        return proposalId;
    }


    function castVote(
        uint256 proposalId,
        VoteType vote
    ) external onlyValidProposal(proposalId) onlyActiveProposal(proposalId) hasVotingPower(msg.sender) {
        Proposal storage proposal = proposals[proposalId];
        Receipt storage receipt = proposal.receipts[msg.sender];

        require(!receipt.hasVoted, "Already voted");

        uint256 votes = votingPower[msg.sender];
        receipt.hasVoted = true;
        receipt.vote = vote;
        receipt.votes = votes;

        _updateVoteCounts(proposal, vote, votes);

        emit VoteCast(msg.sender, proposalId, vote, votes);
    }


    function executeProposal(
        uint256 proposalId
    ) external onlyValidProposal(proposalId) onlySucceededProposal(proposalId) nonReentrant {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp >= proposal.executionTime, "Execution delay not met");
        require(!proposal.executed, "Already executed");

        proposal.executed = true;

        emit ProposalExecuted(proposalId);
    }


    function cancelProposal(uint256 proposalId) external onlyValidProposal(proposalId) {
        Proposal storage proposal = proposals[proposalId];
        require(
            msg.sender == owner() || msg.sender == proposal.proposer,
            "Only owner or proposer can cancel"
        );
        require(!proposal.executed, "Cannot cancel executed proposal");

        proposal.cancelled = true;

        emit ProposalCancelled(proposalId);
    }


    function setVotingPower(address account, uint256 power) external onlyOwner {
        uint256 oldPower = votingPower[account];
        votingPower[account] = power;

        if (power > oldPower) {
            totalVotingPower += (power - oldPower);
        } else {
            totalVotingPower -= (oldPower - power);
        }

        emit VotingPowerUpdated(account, power);
    }


    function getProposalState(uint256 proposalId) external view onlyValidProposal(proposalId) returns (ProposalState) {
        return _getProposalState(proposalId);
    }


    function getProposal(uint256 proposalId) external view onlyValidProposal(proposalId) returns (
        uint256 id,
        address proposer,
        string memory title,
        string memory description,
        uint256 startTime,
        uint256 endTime,
        uint256 executionTime,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 abstainVotes,
        bool executed,
        bool cancelled
    ) {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.id,
            proposal.proposer,
            proposal.title,
            proposal.description,
            proposal.startTime,
            proposal.endTime,
            proposal.executionTime,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.abstainVotes,
            proposal.executed,
            proposal.cancelled
        );
    }


    function getReceipt(uint256 proposalId, address account) external view onlyValidProposal(proposalId) returns (
        bool hasVoted,
        VoteType vote,
        uint256 votes
    ) {
        Receipt storage receipt = proposals[proposalId].receipts[account];
        return (receipt.hasVoted, receipt.vote, receipt.votes);
    }


    function getProposalCount() external view returns (uint256) {
        return _proposalIds.current();
    }


    function isQuorumReached(uint256 proposalId) external view onlyValidProposal(proposalId) returns (bool) {
        return _isQuorumReached(proposalId);
    }


    function _getProposalState(uint256 proposalId) internal view returns (ProposalState) {
        Proposal storage proposal = proposals[proposalId];

        if (proposal.cancelled) {
            return ProposalState.Cancelled;
        }

        if (proposal.executed) {
            return ProposalState.Executed;
        }

        if (block.timestamp < proposal.startTime) {
            return ProposalState.Pending;
        }

        if (block.timestamp <= proposal.endTime) {
            return ProposalState.Active;
        }

        if (_isProposalSucceeded(proposalId)) {
            return ProposalState.Succeeded;
        } else {
            return ProposalState.Defeated;
        }
    }

    function _isProposalSucceeded(uint256 proposalId) internal view returns (bool) {
        Proposal storage proposal = proposals[proposalId];
        return proposal.forVotes > proposal.againstVotes && _isQuorumReached(proposalId);
    }

    function _isQuorumReached(uint256 proposalId) internal view returns (bool) {
        Proposal storage proposal = proposals[proposalId];
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes + proposal.abstainVotes;
        uint256 requiredQuorum = (totalVotingPower * QUORUM_PERCENTAGE) / 100;
        return totalVotes >= requiredQuorum;
    }

    function _updateVoteCounts(Proposal storage proposal, VoteType vote, uint256 votes) internal {
        if (vote == VoteType.For) {
            proposal.forVotes += votes;
        } else if (vote == VoteType.Against) {
            proposal.againstVotes += votes;
        } else {
            proposal.abstainVotes += votes;
        }
    }
}
