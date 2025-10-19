
pragma solidity ^0.8.19;

contract VotingGovernance {
    struct Proposal {
        uint256 id;
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        address proposer;
        mapping(address => bool) hasVoted;
        mapping(address => bool) voteChoice;
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256) public votingPower;

    uint256 public proposalCount;
    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant MIN_VOTING_POWER = 100;
    uint256 public quorumThreshold = 1000;

    address public admin;
    bool public paused;

    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string description);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 power);
    event ProposalExecuted(uint256 indexed proposalId);
    event VotingPowerUpdated(address indexed account, uint256 newPower);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    modifier notPaused() {
        require(!paused, "Contract paused");
        _;
    }

    modifier validProposal(uint256 proposalId) {
        require(proposalId < proposalCount, "Invalid proposal");
        _;
    }

    constructor() {
        admin = msg.sender;
        votingPower[msg.sender] = 1000;
    }

    function createProposal(string calldata description) external notPaused returns (uint256) {
        require(votingPower[msg.sender] >= MIN_VOTING_POWER, "Insufficient voting power");
        require(bytes(description).length > 0, "Empty description");

        uint256 proposalId = proposalCount++;
        Proposal storage proposal = proposals[proposalId];

        proposal.id = proposalId;
        proposal.description = description;
        proposal.startTime = block.timestamp;
        proposal.endTime = block.timestamp + VOTING_PERIOD;
        proposal.proposer = msg.sender;

        emit ProposalCreated(proposalId, msg.sender, description);
        return proposalId;
    }

    function vote(uint256 proposalId, bool support) external validProposal(proposalId) notPaused {
        Proposal storage proposal = proposals[proposalId];

        require(block.timestamp >= proposal.startTime, "Voting not started");
        require(block.timestamp <= proposal.endTime, "Voting ended");
        require(!proposal.hasVoted[msg.sender], "Already voted");
        require(votingPower[msg.sender] > 0, "No voting power");

        proposal.hasVoted[msg.sender] = true;
        proposal.voteChoice[msg.sender] = support;

        if (support) {
            proposal.forVotes += votingPower[msg.sender];
        } else {
            proposal.againstVotes += votingPower[msg.sender];
        }

        emit VoteCast(proposalId, msg.sender, support, votingPower[msg.sender]);
    }

    function executeProposal(uint256 proposalId) external validProposal(proposalId) {
        Proposal storage proposal = proposals[proposalId];

        require(block.timestamp > proposal.endTime, "Voting not ended");
        require(!proposal.executed, "Already executed");
        require(_isProposalPassed(proposalId), "Proposal not passed");

        proposal.executed = true;
        emit ProposalExecuted(proposalId);
    }

    function setVotingPower(address account, uint256 power) external onlyAdmin {
        require(account != address(0), "Invalid address");
        votingPower[account] = power;
        emit VotingPowerUpdated(account, power);
    }

    function setQuorumThreshold(uint256 threshold) external onlyAdmin {
        require(threshold > 0, "Invalid threshold");
        quorumThreshold = threshold;
    }

    function pauseContract() external onlyAdmin {
        paused = true;
    }

    function unpauseContract() external onlyAdmin {
        paused = false;
    }

    function getProposalInfo(uint256 proposalId) external view validProposal(proposalId) returns (
        string memory description,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 endTime,
        bool executed
    ) {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.description,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.endTime,
            proposal.executed
        );
    }

    function hasVoted(uint256 proposalId, address voter) external view validProposal(proposalId) returns (bool) {
        return proposals[proposalId].hasVoted[voter];
    }

    function getVoteChoice(uint256 proposalId, address voter) external view validProposal(proposalId) returns (bool) {
        require(proposals[proposalId].hasVoted[voter], "Has not voted");
        return proposals[proposalId].voteChoice[voter];
    }

    function isProposalActive(uint256 proposalId) external view validProposal(proposalId) returns (bool) {
        Proposal storage proposal = proposals[proposalId];
        return block.timestamp >= proposal.startTime && block.timestamp <= proposal.endTime;
    }

    function _isProposalPassed(uint256 proposalId) internal view returns (bool) {
        Proposal storage proposal = proposals[proposalId];
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes;

        return totalVotes >= quorumThreshold && proposal.forVotes > proposal.againstVotes;
    }
}
