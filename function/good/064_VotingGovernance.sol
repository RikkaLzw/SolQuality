
pragma solidity ^0.8.0;

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
    uint256 public constant VOTING_DURATION = 7 days;
    uint256 public constant MIN_VOTING_POWER = 100;
    uint256 public constant EXECUTION_THRESHOLD = 51;

    address public owner;

    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string description);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 power);
    event ProposalExecuted(uint256 indexed proposalId);
    event VotingPowerGranted(address indexed account, uint256 power);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    modifier validProposal(uint256 proposalId) {
        require(proposalId < proposalCount, "Invalid proposal");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function grantVotingPower(address account, uint256 power) external onlyOwner {
        require(account != address(0), "Invalid address");
        require(power > 0, "Power must be positive");

        votingPower[account] = power;
        emit VotingPowerGranted(account, power);
    }

    function createProposal(string memory description) external returns (uint256) {
        require(bytes(description).length > 0, "Empty description");
        require(votingPower[msg.sender] >= MIN_VOTING_POWER, "Insufficient voting power");

        uint256 proposalId = proposalCount++;
        Proposal storage proposal = proposals[proposalId];

        proposal.id = proposalId;
        proposal.description = description;
        proposal.startTime = block.timestamp;
        proposal.endTime = block.timestamp + VOTING_DURATION;
        proposal.proposer = msg.sender;

        emit ProposalCreated(proposalId, msg.sender, description);
        return proposalId;
    }

    function vote(uint256 proposalId, bool support) external validProposal(proposalId) {
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

        require(block.timestamp > proposal.endTime, "Voting still active");
        require(!proposal.executed, "Already executed");
        require(_isProposalPassed(proposalId), "Proposal not passed");

        proposal.executed = true;
        emit ProposalExecuted(proposalId);
    }

    function getProposalInfo(uint256 proposalId) external view validProposal(proposalId)
        returns (string memory, uint256, uint256, uint256, uint256, bool, address) {
        Proposal storage proposal = proposals[proposalId];

        return (
            proposal.description,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.startTime,
            proposal.endTime,
            proposal.executed,
            proposal.proposer
        );
    }

    function hasVoted(uint256 proposalId, address voter) external view validProposal(proposalId)
        returns (bool) {
        return proposals[proposalId].hasVoted[voter];
    }

    function getVoteChoice(uint256 proposalId, address voter) external view validProposal(proposalId)
        returns (bool) {
        require(proposals[proposalId].hasVoted[voter], "Has not voted");
        return proposals[proposalId].voteChoice[voter];
    }

    function isProposalActive(uint256 proposalId) external view validProposal(proposalId)
        returns (bool) {
        Proposal storage proposal = proposals[proposalId];
        return block.timestamp >= proposal.startTime && block.timestamp <= proposal.endTime;
    }

    function _isProposalPassed(uint256 proposalId) internal view returns (bool) {
        Proposal storage proposal = proposals[proposalId];
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes;

        if (totalVotes == 0) return false;

        return (proposal.forVotes * 100) / totalVotes >= EXECUTION_THRESHOLD;
    }
}
