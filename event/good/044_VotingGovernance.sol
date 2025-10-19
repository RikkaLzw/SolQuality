
pragma solidity ^0.8.0;

contract VotingGovernance {
    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        mapping(address => bool) hasVoted;
        mapping(address => bool) voteChoice;
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256) public votingPower;
    mapping(address => bool) public isGovernor;

    uint256 public proposalCount;
    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant MIN_VOTING_POWER = 100;
    uint256 public constant QUORUM_PERCENTAGE = 30;
    uint256 public totalVotingPower;

    address public admin;
    bool public paused;

    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string description,
        uint256 startTime,
        uint256 endTime
    );

    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        bool support,
        uint256 votingPower
    );

    event ProposalExecuted(uint256 indexed proposalId, bool success);

    event VotingPowerGranted(address indexed account, uint256 amount);

    event VotingPowerRevoked(address indexed account, uint256 amount);

    event GovernorStatusChanged(address indexed account, bool isGovernor);

    event ContractPaused(bool paused);

    modifier onlyAdmin() {
        require(msg.sender == admin, "VotingGovernance: caller is not admin");
        _;
    }

    modifier onlyGovernor() {
        require(isGovernor[msg.sender], "VotingGovernance: caller is not a governor");
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
        isGovernor[msg.sender] = true;
        votingPower[msg.sender] = 1000;
        totalVotingPower = 1000;
    }

    function grantVotingPower(address account, uint256 amount) external onlyAdmin {
        require(account != address(0), "VotingGovernance: cannot grant power to zero address");
        require(amount > 0, "VotingGovernance: amount must be greater than zero");

        votingPower[account] += amount;
        totalVotingPower += amount;

        emit VotingPowerGranted(account, amount);
    }

    function revokeVotingPower(address account, uint256 amount) external onlyAdmin {
        require(account != address(0), "VotingGovernance: cannot revoke power from zero address");
        require(votingPower[account] >= amount, "VotingGovernance: insufficient voting power to revoke");

        votingPower[account] -= amount;
        totalVotingPower -= amount;

        emit VotingPowerRevoked(account, amount);
    }

    function setGovernorStatus(address account, bool status) external onlyAdmin {
        require(account != address(0), "VotingGovernance: cannot set status for zero address");
        require(isGovernor[account] != status, "VotingGovernance: status already set");

        isGovernor[account] = status;
        emit GovernorStatusChanged(account, status);
    }

    function createProposal(string memory description) external onlyGovernor whenNotPaused {
        require(bytes(description).length > 0, "VotingGovernance: description cannot be empty");
        require(votingPower[msg.sender] >= MIN_VOTING_POWER, "VotingGovernance: insufficient voting power to create proposal");

        proposalCount++;
        uint256 proposalId = proposalCount;

        Proposal storage newProposal = proposals[proposalId];
        newProposal.id = proposalId;
        newProposal.proposer = msg.sender;
        newProposal.description = description;
        newProposal.startTime = block.timestamp;
        newProposal.endTime = block.timestamp + VOTING_PERIOD;
        newProposal.executed = false;

        emit ProposalCreated(proposalId, msg.sender, description, newProposal.startTime, newProposal.endTime);
    }

    function vote(uint256 proposalId, bool support) external validProposal(proposalId) whenNotPaused {
        require(votingPower[msg.sender] > 0, "VotingGovernance: no voting power");

        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp >= proposal.startTime, "VotingGovernance: voting has not started");
        require(block.timestamp <= proposal.endTime, "VotingGovernance: voting period has ended");
        require(!proposal.hasVoted[msg.sender], "VotingGovernance: already voted");
        require(!proposal.executed, "VotingGovernance: proposal already executed");

        proposal.hasVoted[msg.sender] = true;
        proposal.voteChoice[msg.sender] = support;

        uint256 voterPower = votingPower[msg.sender];

        if (support) {
            proposal.forVotes += voterPower;
        } else {
            proposal.againstVotes += voterPower;
        }

        emit VoteCast(proposalId, msg.sender, support, voterPower);
    }

    function executeProposal(uint256 proposalId) external validProposal(proposalId) whenNotPaused {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp > proposal.endTime, "VotingGovernance: voting period not ended");
        require(!proposal.executed, "VotingGovernance: proposal already executed");

        uint256 totalVotes = proposal.forVotes + proposal.againstVotes;
        uint256 requiredQuorum = (totalVotingPower * QUORUM_PERCENTAGE) / 100;

        require(totalVotes >= requiredQuorum, "VotingGovernance: quorum not reached");
        require(proposal.forVotes > proposal.againstVotes, "VotingGovernance: proposal rejected");

        proposal.executed = true;

        emit ProposalExecuted(proposalId, true);
    }

    function getProposalDetails(uint256 proposalId) external view validProposal(proposalId) returns (
        uint256 id,
        address proposer,
        string memory description,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 startTime,
        uint256 endTime,
        bool executed
    ) {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.id,
            proposal.proposer,
            proposal.description,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.startTime,
            proposal.endTime,
            proposal.executed
        );
    }

    function hasVoted(uint256 proposalId, address voter) external view validProposal(proposalId) returns (bool) {
        return proposals[proposalId].hasVoted[voter];
    }

    function getVoteChoice(uint256 proposalId, address voter) external view validProposal(proposalId) returns (bool) {
        require(proposals[proposalId].hasVoted[voter], "VotingGovernance: voter has not voted");
        return proposals[proposalId].voteChoice[voter];
    }

    function pauseContract() external onlyAdmin {
        require(!paused, "VotingGovernance: already paused");
        paused = true;
        emit ContractPaused(true);
    }

    function unpauseContract() external onlyAdmin {
        require(paused, "VotingGovernance: not paused");
        paused = false;
        emit ContractPaused(false);
    }

    function transferAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "VotingGovernance: new admin cannot be zero address");
        require(newAdmin != admin, "VotingGovernance: new admin is the same as current admin");

        admin = newAdmin;
        isGovernor[newAdmin] = true;
    }

    function getQuorumRequired() external view returns (uint256) {
        return (totalVotingPower * QUORUM_PERCENTAGE) / 100;
    }

    function isProposalActive(uint256 proposalId) external view validProposal(proposalId) returns (bool) {
        Proposal storage proposal = proposals[proposalId];
        return block.timestamp >= proposal.startTime &&
               block.timestamp <= proposal.endTime &&
               !proposal.executed;
    }
}
