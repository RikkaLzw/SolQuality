
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


contract GovernanceVotingContract is Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;


    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant EXECUTION_DELAY = 2 days;
    uint256 public constant MIN_PROPOSAL_THRESHOLD = 1000 * 10**18;
    uint256 public constant QUORUM_PERCENTAGE = 10;


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
        bytes callData;
        address target;
    }

    struct Receipt {
        bool hasVoted;
        VoteType vote;
        uint256 votes;
    }


    Counters.Counter private _proposalIds;
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => Receipt)) public receipts;
    mapping(address => uint256) public votingPower;

    uint256 public totalVotingPower;
    bool public votingPaused;


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
    event VotingPowerUpdated(address indexed account, uint256 oldPower, uint256 newPower);


    modifier onlyActiveProposal(uint256 proposalId) {
        require(_isActiveProposal(proposalId), "Proposal not active");
        _;
    }

    modifier onlyValidProposal(uint256 proposalId) {
        require(_proposalExists(proposalId), "Proposal does not exist");
        _;
    }

    modifier whenNotPaused() {
        require(!votingPaused, "Voting is paused");
        _;
    }

    modifier onlyEligibleVoter(address voter) {
        require(votingPower[voter] > 0, "No voting power");
        _;
    }

    constructor() {}


    function createProposal(
        string memory title,
        string memory description,
        address target,
        bytes memory callData
    ) external whenNotPaused returns (uint256) {
        require(
            votingPower[msg.sender] >= MIN_PROPOSAL_THRESHOLD,
            "Insufficient voting power to create proposal"
        );
        require(bytes(title).length > 0, "Title cannot be empty");
        require(bytes(description).length > 0, "Description cannot be empty");

        _proposalIds.increment();
        uint256 proposalId = _proposalIds.current();

        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + VOTING_PERIOD;
        uint256 executionTime = endTime + EXECUTION_DELAY;

        proposals[proposalId] = Proposal({
            id: proposalId,
            proposer: msg.sender,
            title: title,
            description: description,
            startTime: startTime,
            endTime: endTime,
            executionTime: executionTime,
            forVotes: 0,
            againstVotes: 0,
            abstainVotes: 0,
            executed: false,
            cancelled: false,
            callData: callData,
            target: target
        });

        emit ProposalCreated(proposalId, msg.sender, title, description, startTime, endTime);
        return proposalId;
    }


    function castVote(
        uint256 proposalId,
        VoteType vote
    ) external onlyValidProposal(proposalId) onlyActiveProposal(proposalId) whenNotPaused {
        return _castVote(msg.sender, proposalId, vote);
    }


    function executeProposal(
        uint256 proposalId
    ) external onlyValidProposal(proposalId) nonReentrant {
        Proposal storage proposal = proposals[proposalId];

        require(_getProposalState(proposalId) == ProposalState.Succeeded, "Proposal not ready for execution");
        require(block.timestamp >= proposal.executionTime, "Execution delay not met");
        require(!proposal.executed, "Proposal already executed");

        proposal.executed = true;

        if (proposal.target != address(0) && proposal.callData.length > 0) {
            (bool success,) = proposal.target.call(proposal.callData);
            require(success, "Proposal execution failed");
        }

        emit ProposalExecuted(proposalId);
    }


    function cancelProposal(
        uint256 proposalId
    ) external onlyValidProposal(proposalId) {
        Proposal storage proposal = proposals[proposalId];

        require(
            msg.sender == owner() || msg.sender == proposal.proposer,
            "Only owner or proposer can cancel"
        );
        require(!proposal.executed, "Cannot cancel executed proposal");
        require(!proposal.cancelled, "Proposal already cancelled");

        proposal.cancelled = true;
        emit ProposalCancelled(proposalId);
    }


    function setVotingPower(
        address account,
        uint256 power
    ) external onlyOwner {
        uint256 oldPower = votingPower[account];
        votingPower[account] = power;

        totalVotingPower = totalVotingPower - oldPower + power;

        emit VotingPowerUpdated(account, oldPower, power);
    }


    function batchSetVotingPower(
        address[] calldata accounts,
        uint256[] calldata powers
    ) external onlyOwner {
        require(accounts.length == powers.length, "Arrays length mismatch");

        for (uint256 i = 0; i < accounts.length; i++) {
            uint256 oldPower = votingPower[accounts[i]];
            votingPower[accounts[i]] = powers[i];
            totalVotingPower = totalVotingPower - oldPower + powers[i];
            emit VotingPowerUpdated(accounts[i], oldPower, powers[i]);
        }
    }


    function setVotingPaused(bool paused) external onlyOwner {
        votingPaused = paused;
    }


    function getProposalState(uint256 proposalId) external view returns (ProposalState) {
        return _getProposalState(proposalId);
    }


    function getProposal(uint256 proposalId) external view returns (
        address proposer,
        string memory title,
        string memory description,
        uint256 startTime,
        uint256 endTime,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 abstainVotes,
        bool executed,
        ProposalState state
    ) {
        require(_proposalExists(proposalId), "Proposal does not exist");

        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.proposer,
            proposal.title,
            proposal.description,
            proposal.startTime,
            proposal.endTime,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.abstainVotes,
            proposal.executed,
            _getProposalState(proposalId)
        );
    }


    function getReceipt(
        uint256 proposalId,
        address voter
    ) external view returns (bool hasVoted, VoteType vote, uint256 votes) {
        Receipt storage receipt = receipts[proposalId][voter];
        return (receipt.hasVoted, receipt.vote, receipt.votes);
    }


    function getProposalCount() external view returns (uint256) {
        return _proposalIds.current();
    }


    function _castVote(
        address voter,
        uint256 proposalId,
        VoteType vote
    ) internal onlyEligibleVoter(voter) {
        Receipt storage receipt = receipts[proposalId][voter];
        require(!receipt.hasVoted, "Already voted");

        uint256 votes = votingPower[voter];
        receipt.hasVoted = true;
        receipt.vote = vote;
        receipt.votes = votes;

        Proposal storage proposal = proposals[proposalId];

        if (vote == VoteType.For) {
            proposal.forVotes += votes;
        } else if (vote == VoteType.Against) {
            proposal.againstVotes += votes;
        } else {
            proposal.abstainVotes += votes;
        }

        emit VoteCast(voter, proposalId, vote, votes);
    }


    function _getProposalState(uint256 proposalId) internal view returns (ProposalState) {
        require(_proposalExists(proposalId), "Proposal does not exist");

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

        uint256 quorum = (totalVotingPower * QUORUM_PERCENTAGE) / 100;
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes + proposal.abstainVotes;

        if (totalVotes < quorum || proposal.forVotes <= proposal.againstVotes) {
            return ProposalState.Defeated;
        }

        return ProposalState.Succeeded;
    }


    function _proposalExists(uint256 proposalId) internal view returns (bool) {
        return proposalId > 0 && proposalId <= _proposalIds.current();
    }


    function _isActiveProposal(uint256 proposalId) internal view returns (bool) {
        return _getProposalState(proposalId) == ProposalState.Active;
    }
}
