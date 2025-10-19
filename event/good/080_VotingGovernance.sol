
pragma solidity ^0.8.0;

contract VotingGovernance {
    struct Proposal {
        uint256 id;
        string title;
        string description;
        address proposer;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        bool cancelled;
        mapping(address => bool) hasVoted;
        mapping(address => VoteChoice) votes;
    }

    enum VoteChoice { For, Against, Abstain }
    enum ProposalState { Pending, Active, Succeeded, Defeated, Executed, Cancelled }

    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256) public votingPower;

    uint256 public proposalCount;
    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant MIN_VOTING_POWER = 1000;
    uint256 public constant QUORUM_PERCENTAGE = 10;
    uint256 public totalVotingPower;

    address public admin;
    bool public paused;

    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string title,
        uint256 startTime,
        uint256 endTime
    );

    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        VoteChoice indexed choice,
        uint256 votingPower
    );

    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCancelled(uint256 indexed proposalId);
    event VotingPowerUpdated(address indexed account, uint256 newVotingPower);
    event AdminChanged(address indexed oldAdmin, address indexed newAdmin);
    event ContractPaused();
    event ContractUnpaused();

    modifier onlyAdmin() {
        require(msg.sender == admin, "VotingGovernance: caller is not the admin");
        _;
    }

    modifier notPaused() {
        require(!paused, "VotingGovernance: contract is paused");
        _;
    }

    modifier validProposal(uint256 proposalId) {
        require(proposalId > 0 && proposalId <= proposalCount, "VotingGovernance: invalid proposal ID");
        _;
    }

    constructor() {
        admin = msg.sender;
        paused = false;
    }

    function createProposal(
        string memory title,
        string memory description
    ) external notPaused returns (uint256) {
        require(bytes(title).length > 0, "VotingGovernance: title cannot be empty");
        require(bytes(description).length > 0, "VotingGovernance: description cannot be empty");
        require(votingPower[msg.sender] >= MIN_VOTING_POWER, "VotingGovernance: insufficient voting power to create proposal");

        proposalCount++;
        uint256 proposalId = proposalCount;

        Proposal storage newProposal = proposals[proposalId];
        newProposal.id = proposalId;
        newProposal.title = title;
        newProposal.description = description;
        newProposal.proposer = msg.sender;
        newProposal.startTime = block.timestamp;
        newProposal.endTime = block.timestamp + VOTING_PERIOD;
        newProposal.executed = false;
        newProposal.cancelled = false;

        emit ProposalCreated(proposalId, msg.sender, title, newProposal.startTime, newProposal.endTime);

        return proposalId;
    }

    function vote(uint256 proposalId, VoteChoice choice) external notPaused validProposal(proposalId) {
        Proposal storage proposal = proposals[proposalId];

        require(block.timestamp >= proposal.startTime, "VotingGovernance: voting has not started yet");
        require(block.timestamp <= proposal.endTime, "VotingGovernance: voting period has ended");
        require(!proposal.executed, "VotingGovernance: proposal already executed");
        require(!proposal.cancelled, "VotingGovernance: proposal has been cancelled");
        require(!proposal.hasVoted[msg.sender], "VotingGovernance: already voted on this proposal");
        require(votingPower[msg.sender] > 0, "VotingGovernance: no voting power");

        uint256 voterPower = votingPower[msg.sender];
        proposal.hasVoted[msg.sender] = true;
        proposal.votes[msg.sender] = choice;

        if (choice == VoteChoice.For) {
            proposal.forVotes += voterPower;
        } else if (choice == VoteChoice.Against) {
            proposal.againstVotes += voterPower;
        } else {
            proposal.abstainVotes += voterPower;
        }

        emit VoteCast(proposalId, msg.sender, choice, voterPower);
    }

    function executeProposal(uint256 proposalId) external notPaused validProposal(proposalId) {
        Proposal storage proposal = proposals[proposalId];

        require(block.timestamp > proposal.endTime, "VotingGovernance: voting period not ended");
        require(!proposal.executed, "VotingGovernance: proposal already executed");
        require(!proposal.cancelled, "VotingGovernance: proposal has been cancelled");

        ProposalState state = getProposalState(proposalId);
        require(state == ProposalState.Succeeded, "VotingGovernance: proposal did not succeed");

        proposal.executed = true;

        emit ProposalExecuted(proposalId);
    }

    function cancelProposal(uint256 proposalId) external validProposal(proposalId) {
        Proposal storage proposal = proposals[proposalId];

        require(
            msg.sender == proposal.proposer || msg.sender == admin,
            "VotingGovernance: only proposer or admin can cancel"
        );
        require(!proposal.executed, "VotingGovernance: cannot cancel executed proposal");
        require(!proposal.cancelled, "VotingGovernance: proposal already cancelled");

        proposal.cancelled = true;

        emit ProposalCancelled(proposalId);
    }

    function setVotingPower(address account, uint256 power) external onlyAdmin {
        require(account != address(0), "VotingGovernance: invalid account address");

        uint256 oldPower = votingPower[account];
        votingPower[account] = power;

        if (power > oldPower) {
            totalVotingPower += (power - oldPower);
        } else {
            totalVotingPower -= (oldPower - power);
        }

        emit VotingPowerUpdated(account, power);
    }

    function changeAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "VotingGovernance: new admin cannot be zero address");
        require(newAdmin != admin, "VotingGovernance: new admin is the same as current admin");

        address oldAdmin = admin;
        admin = newAdmin;

        emit AdminChanged(oldAdmin, newAdmin);
    }

    function pause() external onlyAdmin {
        require(!paused, "VotingGovernance: already paused");
        paused = true;
        emit ContractPaused();
    }

    function unpause() external onlyAdmin {
        require(paused, "VotingGovernance: not paused");
        paused = false;
        emit ContractUnpaused();
    }

    function getProposalState(uint256 proposalId) public view validProposal(proposalId) returns (ProposalState) {
        Proposal storage proposal = proposals[proposalId];

        if (proposal.cancelled) {
            return ProposalState.Cancelled;
        }

        if (proposal.executed) {
            return ProposalState.Executed;
        }

        if (block.timestamp <= proposal.endTime) {
            return ProposalState.Active;
        }

        uint256 totalVotes = proposal.forVotes + proposal.againstVotes + proposal.abstainVotes;
        uint256 quorumRequired = (totalVotingPower * QUORUM_PERCENTAGE) / 100;

        if (totalVotes < quorumRequired) {
            return ProposalState.Defeated;
        }

        if (proposal.forVotes > proposal.againstVotes) {
            return ProposalState.Succeeded;
        } else {
            return ProposalState.Defeated;
        }
    }

    function getProposalVotes(uint256 proposalId) external view validProposal(proposalId) returns (
        uint256 forVotes,
        uint256 againstVotes,
        uint256 abstainVotes
    ) {
        Proposal storage proposal = proposals[proposalId];
        return (proposal.forVotes, proposal.againstVotes, proposal.abstainVotes);
    }

    function hasVoted(uint256 proposalId, address voter) external view validProposal(proposalId) returns (bool) {
        return proposals[proposalId].hasVoted[voter];
    }

    function getVote(uint256 proposalId, address voter) external view validProposal(proposalId) returns (VoteChoice) {
        require(proposals[proposalId].hasVoted[voter], "VotingGovernance: voter has not voted on this proposal");
        return proposals[proposalId].votes[voter];
    }
}
