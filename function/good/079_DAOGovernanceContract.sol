
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract DAOGovernanceContract {
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

    IERC20 public governanceToken;
    address public admin;
    uint256 public proposalCount;
    uint256 public votingPeriod;
    uint256 public proposalThreshold;
    uint256 public quorumThreshold;

    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256) public votingPower;

    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string description);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }

    modifier validProposal(uint256 proposalId) {
        require(proposalId > 0 && proposalId <= proposalCount, "Invalid proposal ID");
        _;
    }

    constructor(
        address _governanceToken,
        uint256 _votingPeriod,
        uint256 _proposalThreshold,
        uint256 _quorumThreshold
    ) {
        governanceToken = IERC20(_governanceToken);
        admin = msg.sender;
        votingPeriod = _votingPeriod;
        proposalThreshold = _proposalThreshold;
        quorumThreshold = _quorumThreshold;
    }

    function createProposal(string memory description) external returns (uint256) {
        require(bytes(description).length > 0, "Description cannot be empty");
        require(_getVotingPower(msg.sender) >= proposalThreshold, "Insufficient tokens to create proposal");

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

    function vote(uint256 proposalId, bool support) external validProposal(proposalId) {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp >= proposal.startTime, "Voting has not started");
        require(block.timestamp <= proposal.endTime, "Voting has ended");
        require(!proposal.hasVoted[msg.sender], "Already voted");

        uint256 weight = _getVotingPower(msg.sender);
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

    function executeProposal(uint256 proposalId) external validProposal(proposalId) {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp > proposal.endTime, "Voting period not ended");
        require(!proposal.executed, "Proposal already executed");
        require(_isProposalPassed(proposalId), "Proposal did not pass");

        proposal.executed = true;
        emit ProposalExecuted(proposalId);
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

    function hasVoted(uint256 proposalId, address voter) external view validProposal(proposalId) returns (bool) {
        return proposals[proposalId].hasVoted[voter];
    }

    function getVoteChoice(uint256 proposalId, address voter) external view validProposal(proposalId) returns (bool) {
        require(proposals[proposalId].hasVoted[voter], "Voter has not voted");
        return proposals[proposalId].voteChoice[voter];
    }

    function isProposalActive(uint256 proposalId) external view validProposal(proposalId) returns (bool) {
        Proposal storage proposal = proposals[proposalId];
        return block.timestamp >= proposal.startTime && block.timestamp <= proposal.endTime;
    }

    function updateVotingPeriod(uint256 newVotingPeriod) external onlyAdmin {
        require(newVotingPeriod > 0, "Voting period must be greater than 0");
        votingPeriod = newVotingPeriod;
    }

    function updateProposalThreshold(uint256 newThreshold) external onlyAdmin {
        proposalThreshold = newThreshold;
    }

    function updateQuorumThreshold(uint256 newThreshold) external onlyAdmin {
        quorumThreshold = newThreshold;
    }

    function _getVotingPower(address account) internal view returns (uint256) {
        return governanceToken.balanceOf(account);
    }

    function _isProposalPassed(uint256 proposalId) internal view returns (bool) {
        Proposal storage proposal = proposals[proposalId];
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes;

        return totalVotes >= quorumThreshold && proposal.forVotes > proposal.againstVotes;
    }

    function _hasQuorum(uint256 proposalId) internal view returns (bool) {
        Proposal storage proposal = proposals[proposalId];
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes;
        return totalVotes >= quorumThreshold;
    }
}
