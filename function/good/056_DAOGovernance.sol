
pragma solidity ^0.8.0;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract DAOGovernance {
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
        mapping(address => uint256) votes;
    }

    IERC20 public governanceToken;
    uint256 public proposalCount;
    uint256 public votingPeriod;
    uint256 public minTokensToPropose;
    uint256 public quorumPercentage;

    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256) public memberVotingPower;

    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string description);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 votes);
    event ProposalExecuted(uint256 indexed proposalId);

    modifier onlyTokenHolder() {
        require(governanceToken.balanceOf(msg.sender) > 0, "Must hold governance tokens");
        _;
    }

    modifier validProposal(uint256 proposalId) {
        require(proposalId > 0 && proposalId <= proposalCount, "Invalid proposal ID");
        _;
    }

    constructor(
        address _governanceToken,
        uint256 _votingPeriod,
        uint256 _minTokensToPropose,
        uint256 _quorumPercentage
    ) {
        require(_governanceToken != address(0), "Invalid token address");
        require(_votingPeriod > 0, "Invalid voting period");
        require(_quorumPercentage > 0 && _quorumPercentage <= 100, "Invalid quorum percentage");

        governanceToken = IERC20(_governanceToken);
        votingPeriod = _votingPeriod;
        minTokensToPropose = _minTokensToPropose;
        quorumPercentage = _quorumPercentage;
    }

    function createProposal(string memory description) external onlyTokenHolder returns (uint256) {
        require(bytes(description).length > 0, "Description cannot be empty");
        require(governanceToken.balanceOf(msg.sender) >= minTokensToPropose, "Insufficient tokens to propose");

        proposalCount++;
        uint256 proposalId = proposalCount;

        Proposal storage newProposal = proposals[proposalId];
        newProposal.id = proposalId;
        newProposal.proposer = msg.sender;
        newProposal.description = description;
        newProposal.startTime = block.timestamp;
        newProposal.endTime = block.timestamp + votingPeriod;
        newProposal.executed = false;

        emit ProposalCreated(proposalId, msg.sender, description);
        return proposalId;
    }

    function vote(uint256 proposalId, bool support) external validProposal(proposalId) onlyTokenHolder {
        Proposal storage proposal = proposals[proposalId];

        require(block.timestamp >= proposal.startTime, "Voting not started");
        require(block.timestamp <= proposal.endTime, "Voting period ended");
        require(!proposal.hasVoted[msg.sender], "Already voted");

        uint256 voterBalance = governanceToken.balanceOf(msg.sender);
        require(voterBalance > 0, "No voting power");

        proposal.hasVoted[msg.sender] = true;
        proposal.votes[msg.sender] = voterBalance;

        if (support) {
            proposal.forVotes += voterBalance;
        } else {
            proposal.againstVotes += voterBalance;
        }

        emit VoteCast(proposalId, msg.sender, support, voterBalance);
    }

    function executeProposal(uint256 proposalId) external validProposal(proposalId) returns (bool) {
        Proposal storage proposal = proposals[proposalId];

        require(block.timestamp > proposal.endTime, "Voting period not ended");
        require(!proposal.executed, "Proposal already executed");

        bool quorumReached = _checkQuorum(proposalId);
        bool proposalPassed = _checkProposalPassed(proposalId);

        require(quorumReached, "Quorum not reached");
        require(proposalPassed, "Proposal did not pass");

        proposal.executed = true;
        emit ProposalExecuted(proposalId);

        return true;
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
        bool isActive,
        bool isExecuted,
        bool quorumReached,
        bool passed
    ) {
        Proposal storage proposal = proposals[proposalId];

        isActive = block.timestamp >= proposal.startTime && block.timestamp <= proposal.endTime;
        isExecuted = proposal.executed;
        quorumReached = _checkQuorum(proposalId);
        passed = _checkProposalPassed(proposalId);

        return (isActive, isExecuted, quorumReached, passed);
    }

    function hasVoted(uint256 proposalId, address voter) external view validProposal(proposalId) returns (bool) {
        return proposals[proposalId].hasVoted[voter];
    }

    function getVotingPower(address account) external view returns (uint256) {
        return governanceToken.balanceOf(account);
    }

    function _checkQuorum(uint256 proposalId) internal view returns (bool) {
        Proposal storage proposal = proposals[proposalId];
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes;
        uint256 totalSupply = governanceToken.totalSupply();
        uint256 requiredQuorum = (totalSupply * quorumPercentage) / 100;

        return totalVotes >= requiredQuorum;
    }

    function _checkProposalPassed(uint256 proposalId) internal view returns (bool) {
        Proposal storage proposal = proposals[proposalId];
        return proposal.forVotes > proposal.againstVotes;
    }
}
