
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
    uint256 public constant MIN_VOTING_POWER = 1000;
    uint256 public constant QUORUM_THRESHOLD = 10000;

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

    event VotingPowerUpdated(
        address indexed account,
        uint256 oldPower,
        uint256 newPower
    );

    event GovernorStatusChanged(
        address indexed account,
        bool isGovernor
    );

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
        votingPower[msg.sender] = MIN_VOTING_POWER;

        emit GovernorStatusChanged(msg.sender, true);
        emit VotingPowerUpdated(msg.sender, 0, MIN_VOTING_POWER);
    }

    function createProposal(string calldata description) external onlyGovernor whenNotPaused {
        require(bytes(description).length > 0, "VotingGovernance: description cannot be empty");
        require(votingPower[msg.sender] >= MIN_VOTING_POWER, "VotingGovernance: insufficient voting power to create proposal");

        proposalCount++;
        uint256 proposalId = proposalCount;

        Proposal storage proposal = proposals[proposalId];
        proposal.id = proposalId;
        proposal.proposer = msg.sender;
        proposal.description = description;
        proposal.startTime = block.timestamp;
        proposal.endTime = block.timestamp + VOTING_PERIOD;
        proposal.executed = false;

        emit ProposalCreated(
            proposalId,
            msg.sender,
            description,
            proposal.startTime,
            proposal.endTime
        );
    }

    function vote(uint256 proposalId, bool support) external whenNotPaused validProposal(proposalId) {
        require(votingPower[msg.sender] > 0, "VotingGovernance: no voting power");

        Proposal storage proposal = proposals[proposalId];

        require(block.timestamp >= proposal.startTime, "VotingGovernance: voting has not started");
        require(block.timestamp <= proposal.endTime, "VotingGovernance: voting period has ended");
        require(!proposal.hasVoted[msg.sender], "VotingGovernance: already voted on this proposal");

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

    function executeProposal(uint256 proposalId) external whenNotPaused validProposal(proposalId) {
        Proposal storage proposal = proposals[proposalId];

        require(block.timestamp > proposal.endTime, "VotingGovernance: voting period has not ended");
        require(!proposal.executed, "VotingGovernance: proposal already executed");

        uint256 totalVotes = proposal.forVotes + proposal.againstVotes;
        require(totalVotes >= QUORUM_THRESHOLD, "VotingGovernance: quorum not reached");

        bool success = proposal.forVotes > proposal.againstVotes;
        proposal.executed = true;

        emit ProposalExecuted(proposalId, success);
    }

    function setVotingPower(address account, uint256 power) external onlyAdmin {
        require(account != address(0), "VotingGovernance: invalid account address");

        uint256 oldPower = votingPower[account];
        votingPower[account] = power;

        emit VotingPowerUpdated(account, oldPower, power);
    }

    function setGovernorStatus(address account, bool status) external onlyAdmin {
        require(account != address(0), "VotingGovernance: invalid account address");
        require(account != admin, "VotingGovernance: cannot change admin governor status");

        isGovernor[account] = status;

        emit GovernorStatusChanged(account, status);
    }

    function pauseContract() external onlyAdmin {
        paused = !paused;
        emit ContractPaused(paused);
    }

    function transferAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "VotingGovernance: new admin cannot be zero address");
        require(newAdmin != admin, "VotingGovernance: new admin cannot be current admin");

        address oldAdmin = admin;
        admin = newAdmin;


        isGovernor[newAdmin] = true;

        emit GovernorStatusChanged(newAdmin, true);
    }

    function getProposalDetails(uint256 proposalId) external view validProposal(proposalId) returns (
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
        require(proposals[proposalId].hasVoted[voter], "VotingGovernance: voter has not voted on this proposal");
        return proposals[proposalId].voteChoice[voter];
    }

    function isProposalActive(uint256 proposalId) external view validProposal(proposalId) returns (bool) {
        Proposal storage proposal = proposals[proposalId];
        return block.timestamp >= proposal.startTime && block.timestamp <= proposal.endTime;
    }

    function getProposalResult(uint256 proposalId) external view validProposal(proposalId) returns (bool passed, bool executed) {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp > proposal.endTime, "VotingGovernance: voting period has not ended");

        uint256 totalVotes = proposal.forVotes + proposal.againstVotes;
        passed = totalVotes >= QUORUM_THRESHOLD && proposal.forVotes > proposal.againstVotes;
        executed = proposal.executed;
    }
}
