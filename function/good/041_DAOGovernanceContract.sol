
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DAOGovernanceContract is ReentrancyGuard, Ownable {

    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        bool canceled;
        mapping(address => bool) hasVoted;
        mapping(address => bool) voteChoice;
    }

    IERC20 public governanceToken;
    uint256 public proposalCount;
    uint256 public votingPeriod = 7 days;
    uint256 public proposalThreshold = 1000 * 10**18;
    uint256 public quorumPercentage = 10;

    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256) public votingPower;

    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string description);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCanceled(uint256 indexed proposalId);

    modifier validProposal(uint256 proposalId) {
        require(proposalId <= proposalCount && proposalId > 0, "Invalid proposal ID");
        _;
    }

    modifier onlyTokenHolder() {
        require(governanceToken.balanceOf(msg.sender) > 0, "Must hold governance tokens");
        _;
    }

    constructor(address _governanceToken) {
        governanceToken = IERC20(_governanceToken);
    }

    function createProposal(string calldata description) external onlyTokenHolder returns (uint256) {
        require(bytes(description).length > 0, "Description cannot be empty");
        require(governanceToken.balanceOf(msg.sender) >= proposalThreshold, "Insufficient tokens to propose");

        proposalCount++;
        uint256 proposalId = proposalCount;

        Proposal storage newProposal = proposals[proposalId];
        newProposal.id = proposalId;
        newProposal.proposer = msg.sender;
        newProposal.description = description;
        newProposal.startTime = block.timestamp;
        newProposal.endTime = block.timestamp + votingPeriod;

        emit ProposalCreated(proposalId, msg.sender, description);
        return proposalId;
    }

    function vote(uint256 proposalId, bool support) external validProposal(proposalId) onlyTokenHolder nonReentrant {
        Proposal storage proposal = proposals[proposalId];

        require(block.timestamp >= proposal.startTime, "Voting not started");
        require(block.timestamp <= proposal.endTime, "Voting period ended");
        require(!proposal.hasVoted[msg.sender], "Already voted");
        require(!proposal.executed, "Proposal already executed");
        require(!proposal.canceled, "Proposal canceled");

        uint256 weight = governanceToken.balanceOf(msg.sender);
        require(weight > 0, "No voting power");

        proposal.hasVoted[msg.sender] = true;
        proposal.voteChoice[msg.sender] = support;

        if (support) {
            proposal.forVotes += weight;
        } else {
            proposal.againstVotes += weight;
        }

        emit VoteCast(proposalId, msg.sender, support, weight);
    }

    function executeProposal(uint256 proposalId) external validProposal(proposalId) nonReentrant {
        Proposal storage proposal = proposals[proposalId];

        require(block.timestamp > proposal.endTime, "Voting period not ended");
        require(!proposal.executed, "Already executed");
        require(!proposal.canceled, "Proposal canceled");
        require(_hasQuorum(proposalId), "Quorum not reached");
        require(proposal.forVotes > proposal.againstVotes, "Proposal rejected");

        proposal.executed = true;
        emit ProposalExecuted(proposalId);
    }

    function cancelProposal(uint256 proposalId) external validProposal(proposalId) {
        Proposal storage proposal = proposals[proposalId];

        require(msg.sender == proposal.proposer || msg.sender == owner(), "Not authorized");
        require(!proposal.executed, "Already executed");
        require(!proposal.canceled, "Already canceled");

        proposal.canceled = true;
        emit ProposalCanceled(proposalId);
    }

    function getProposalInfo(uint256 proposalId) external view validProposal(proposalId) returns (
        address proposer,
        string memory description,
        uint256 forVotes,
        uint256 againstVotes
    ) {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.proposer,
            proposal.description,
            proposal.forVotes,
            proposal.againstVotes
        );
    }

    function getProposalStatus(uint256 proposalId) external view validProposal(proposalId) returns (
        bool executed,
        bool canceled,
        bool active,
        bool passed
    ) {
        Proposal storage proposal = proposals[proposalId];
        bool isActive = block.timestamp >= proposal.startTime &&
                       block.timestamp <= proposal.endTime &&
                       !proposal.executed &&
                       !proposal.canceled;
        bool hasPassed = proposal.forVotes > proposal.againstVotes && _hasQuorum(proposalId);

        return (proposal.executed, proposal.canceled, isActive, hasPassed);
    }

    function hasVoted(uint256 proposalId, address voter) external view validProposal(proposalId) returns (bool) {
        return proposals[proposalId].hasVoted[voter];
    }

    function getVoteChoice(uint256 proposalId, address voter) external view validProposal(proposalId) returns (bool) {
        require(proposals[proposalId].hasVoted[voter], "Has not voted");
        return proposals[proposalId].voteChoice[voter];
    }

    function setVotingPeriod(uint256 _votingPeriod) external onlyOwner {
        require(_votingPeriod >= 1 days && _votingPeriod <= 30 days, "Invalid voting period");
        votingPeriod = _votingPeriod;
    }

    function setProposalThreshold(uint256 _threshold) external onlyOwner {
        require(_threshold > 0, "Threshold must be positive");
        proposalThreshold = _threshold;
    }

    function setQuorumPercentage(uint256 _percentage) external onlyOwner {
        require(_percentage > 0 && _percentage <= 100, "Invalid percentage");
        quorumPercentage = _percentage;
    }

    function _hasQuorum(uint256 proposalId) internal view returns (bool) {
        Proposal storage proposal = proposals[proposalId];
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes;
        uint256 totalSupply = governanceToken.totalSupply();
        return totalVotes * 100 >= totalSupply * quorumPercentage;
    }

    function getTotalSupply() external view returns (uint256) {
        return governanceToken.totalSupply();
    }

    function getQuorumRequired(uint256 proposalId) external view validProposal(proposalId) returns (uint256) {
        uint256 totalSupply = governanceToken.totalSupply();
        return (totalSupply * quorumPercentage) / 100;
    }
}
