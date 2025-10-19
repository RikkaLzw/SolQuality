
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
        mapping(address => bool) hasVoted;
        mapping(address => VoteChoice) votes;
    }

    enum VoteChoice { For, Against, Abstain }
    enum ProposalState { Pending, Active, Succeeded, Defeated, Executed }

    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256) public votingPower;

    uint256 public proposalCount;
    uint256 public votingDelay = 1 days;
    uint256 public votingPeriod = 7 days;
    uint256 public proposalThreshold = 1000;
    uint256 public quorum = 10000;

    address public admin;
    bool public paused;

    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string title,
        string description,
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

    event VotingPowerUpdated(
        address indexed account,
        uint256 oldPower,
        uint256 newPower
    );

    event GovernanceParametersUpdated(
        uint256 votingDelay,
        uint256 votingPeriod,
        uint256 proposalThreshold,
        uint256 quorum
    );

    event ContractPaused();
    event ContractUnpaused();

    modifier onlyAdmin() {
        require(msg.sender == admin, "VotingGovernance: caller is not admin");
        _;
    }

    modifier whenNotPaused() {
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
    ) external whenNotPaused returns (uint256) {
        require(bytes(title).length > 0, "VotingGovernance: title cannot be empty");
        require(bytes(description).length > 0, "VotingGovernance: description cannot be empty");
        require(votingPower[msg.sender] >= proposalThreshold, "VotingGovernance: insufficient voting power to create proposal");

        proposalCount++;
        uint256 proposalId = proposalCount;

        Proposal storage newProposal = proposals[proposalId];
        newProposal.id = proposalId;
        newProposal.title = title;
        newProposal.description = description;
        newProposal.proposer = msg.sender;
        newProposal.startTime = block.timestamp + votingDelay;
        newProposal.endTime = newProposal.startTime + votingPeriod;
        newProposal.executed = false;

        emit ProposalCreated(
            proposalId,
            msg.sender,
            title,
            description,
            newProposal.startTime,
            newProposal.endTime
        );

        return proposalId;
    }

    function vote(uint256 proposalId, VoteChoice choice) external whenNotPaused validProposal(proposalId) {
        Proposal storage proposal = proposals[proposalId];

        require(block.timestamp >= proposal.startTime, "VotingGovernance: voting has not started");
        require(block.timestamp <= proposal.endTime, "VotingGovernance: voting has ended");
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

    function executeProposal(uint256 proposalId) external whenNotPaused validProposal(proposalId) {
        Proposal storage proposal = proposals[proposalId];

        require(block.timestamp > proposal.endTime, "VotingGovernance: voting period not ended");
        require(!proposal.executed, "VotingGovernance: proposal already executed");

        ProposalState state = getProposalState(proposalId);
        require(state == ProposalState.Succeeded, "VotingGovernance: proposal did not succeed");

        proposal.executed = true;

        emit ProposalExecuted(proposalId);
    }

    function getProposalState(uint256 proposalId) public view validProposal(proposalId) returns (ProposalState) {
        Proposal storage proposal = proposals[proposalId];

        if (proposal.executed) {
            return ProposalState.Executed;
        }

        if (block.timestamp < proposal.startTime) {
            return ProposalState.Pending;
        }

        if (block.timestamp <= proposal.endTime) {
            return ProposalState.Active;
        }

        uint256 totalVotes = proposal.forVotes + proposal.againstVotes + proposal.abstainVotes;

        if (totalVotes < quorum) {
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
        require(proposals[proposalId].hasVoted[voter], "VotingGovernance: voter has not voted");
        return proposals[proposalId].votes[voter];
    }

    function setVotingPower(address account, uint256 power) external onlyAdmin {
        require(account != address(0), "VotingGovernance: invalid account address");

        uint256 oldPower = votingPower[account];
        votingPower[account] = power;

        emit VotingPowerUpdated(account, oldPower, power);
    }

    function updateGovernanceParameters(
        uint256 _votingDelay,
        uint256 _votingPeriod,
        uint256 _proposalThreshold,
        uint256 _quorum
    ) external onlyAdmin {
        require(_votingDelay > 0, "VotingGovernance: voting delay must be greater than 0");
        require(_votingPeriod > 0, "VotingGovernance: voting period must be greater than 0");
        require(_proposalThreshold > 0, "VotingGovernance: proposal threshold must be greater than 0");
        require(_quorum > 0, "VotingGovernance: quorum must be greater than 0");

        votingDelay = _votingDelay;
        votingPeriod = _votingPeriod;
        proposalThreshold = _proposalThreshold;
        quorum = _quorum;

        emit GovernanceParametersUpdated(_votingDelay, _votingPeriod, _proposalThreshold, _quorum);
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

    function transferAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "VotingGovernance: new admin cannot be zero address");
        require(newAdmin != admin, "VotingGovernance: new admin is the same as current admin");
        admin = newAdmin;
    }
}
