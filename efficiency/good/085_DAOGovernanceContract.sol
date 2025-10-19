
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
        uint256 abstainVotes;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        bool canceled;
        mapping(address => bool) hasVoted;
        mapping(address => uint8) votes;
    }

    struct ProposalCore {
        uint256 id;
        address proposer;
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        bool canceled;
    }

    IERC20 public immutable governanceToken;

    uint256 public constant VOTING_PERIOD = 3 days;
    uint256 public constant EXECUTION_DELAY = 1 days;
    uint256 public constant PROPOSAL_THRESHOLD = 1000 * 10**18;
    uint256 public constant QUORUM_THRESHOLD = 4;

    uint256 public proposalCount;
    uint256 private _totalSupplyCache;
    uint256 private _cacheTimestamp;
    uint256 private constant CACHE_DURATION = 1 hours;

    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256) public lastProposalTime;
    mapping(uint256 => mapping(address => uint256)) public proposalVotingPower;


    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string description);
    event VoteCast(uint256 indexed proposalId, address indexed voter, uint8 support, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCanceled(uint256 indexed proposalId);

    modifier onlyTokenHolder() {
        require(governanceToken.balanceOf(msg.sender) >= PROPOSAL_THRESHOLD, "Insufficient tokens");
        _;
    }

    modifier validProposal(uint256 proposalId) {
        require(proposalId > 0 && proposalId <= proposalCount, "Invalid proposal");
        _;
    }

    constructor(address _governanceToken) {
        require(_governanceToken != address(0), "Invalid token address");
        governanceToken = IERC20(_governanceToken);
        _updateTotalSupplyCache();
    }

    function createProposal(string calldata description) external onlyTokenHolder nonReentrant returns (uint256) {
        require(bytes(description).length > 0, "Empty description");
        require(block.timestamp >= lastProposalTime[msg.sender] + 1 days, "Proposal cooldown");

        unchecked {
            ++proposalCount;
        }

        uint256 proposalId = proposalCount;
        Proposal storage newProposal = proposals[proposalId];

        newProposal.id = proposalId;
        newProposal.proposer = msg.sender;
        newProposal.description = description;
        newProposal.startTime = block.timestamp;
        newProposal.endTime = block.timestamp + VOTING_PERIOD;

        lastProposalTime[msg.sender] = block.timestamp;

        emit ProposalCreated(proposalId, msg.sender, description);
        return proposalId;
    }

    function vote(uint256 proposalId, uint8 support) external validProposal(proposalId) nonReentrant {
        require(support <= 2, "Invalid vote type");

        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp >= proposal.startTime, "Voting not started");
        require(block.timestamp <= proposal.endTime, "Voting ended");
        require(!proposal.hasVoted[msg.sender], "Already voted");
        require(!proposal.executed && !proposal.canceled, "Proposal finalized");

        uint256 weight = governanceToken.balanceOf(msg.sender);
        require(weight > 0, "No voting power");

        proposal.hasVoted[msg.sender] = true;
        proposal.votes[msg.sender] = support;
        proposalVotingPower[proposalId][msg.sender] = weight;

        if (support == 0) {
            proposal.againstVotes += weight;
        } else if (support == 1) {
            proposal.forVotes += weight;
        } else {
            proposal.abstainVotes += weight;
        }

        emit VoteCast(proposalId, msg.sender, support, weight);
    }

    function executeProposal(uint256 proposalId) external validProposal(proposalId) nonReentrant {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp > proposal.endTime + EXECUTION_DELAY, "Execution delay not met");
        require(!proposal.executed, "Already executed");
        require(!proposal.canceled, "Proposal canceled");

        uint256 totalVotes = proposal.forVotes + proposal.againstVotes + proposal.abstainVotes;
        uint256 quorumRequired = (_getTotalSupply() * QUORUM_THRESHOLD) / 100;

        require(totalVotes >= quorumRequired, "Quorum not reached");
        require(proposal.forVotes > proposal.againstVotes, "Proposal rejected");

        proposal.executed = true;

        emit ProposalExecuted(proposalId);
    }

    function cancelProposal(uint256 proposalId) external validProposal(proposalId) {
        Proposal storage proposal = proposals[proposalId];
        require(msg.sender == proposal.proposer || msg.sender == owner(), "Unauthorized");
        require(!proposal.executed, "Already executed");
        require(!proposal.canceled, "Already canceled");

        proposal.canceled = true;

        emit ProposalCanceled(proposalId);
    }

    function getProposal(uint256 proposalId) external view validProposal(proposalId)
        returns (ProposalCore memory) {
        Proposal storage proposal = proposals[proposalId];
        return ProposalCore({
            id: proposal.id,
            proposer: proposal.proposer,
            description: proposal.description,
            forVotes: proposal.forVotes,
            againstVotes: proposal.againstVotes,
            abstainVotes: proposal.abstainVotes,
            startTime: proposal.startTime,
            endTime: proposal.endTime,
            executed: proposal.executed,
            canceled: proposal.canceled
        });
    }

    function getVote(uint256 proposalId, address voter) external view validProposal(proposalId)
        returns (bool hasVoted, uint8 support, uint256 weight) {
        Proposal storage proposal = proposals[proposalId];
        hasVoted = proposal.hasVoted[voter];
        support = proposal.votes[voter];
        weight = proposalVotingPower[proposalId][voter];
    }

    function getProposalState(uint256 proposalId) external view validProposal(proposalId)
        returns (uint8) {
        Proposal storage proposal = proposals[proposalId];

        if (proposal.canceled) return 0;
        if (proposal.executed) return 1;
        if (block.timestamp <= proposal.endTime) return 2;

        uint256 totalVotes = proposal.forVotes + proposal.againstVotes + proposal.abstainVotes;
        uint256 quorumRequired = (_getTotalSupply() * QUORUM_THRESHOLD) / 100;

        if (totalVotes < quorumRequired) return 3;
        if (proposal.forVotes <= proposal.againstVotes) return 4;
        if (block.timestamp <= proposal.endTime + EXECUTION_DELAY) return 5;

        return 6;
    }

    function _getTotalSupply() private view returns (uint256) {
        if (block.timestamp <= _cacheTimestamp + CACHE_DURATION) {
            return _totalSupplyCache;
        }
        return governanceToken.totalSupply();
    }

    function _updateTotalSupplyCache() private {
        _totalSupplyCache = governanceToken.totalSupply();
        _cacheTimestamp = block.timestamp;
    }

    function updateTotalSupplyCache() external {
        _updateTotalSupplyCache();
    }

    function getQuorumRequired() external view returns (uint256) {
        return (_getTotalSupply() * QUORUM_THRESHOLD) / 100;
    }
}
