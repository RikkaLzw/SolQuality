
pragma solidity ^0.8.19;

contract DAOGovernance {

    bytes32 public constant DOMAIN_SEPARATOR = keccak256("DAOGovernance");

    struct Proposal {
        bytes32 id;
        address proposer;
        string description;
        uint256 votesFor;
        uint256 votesAgainst;
        uint32 startTime;
        uint32 endTime;
        bool executed;
        bool exists;
    }

    struct Vote {
        bool hasVoted;
        bool support;
        uint256 weight;
    }

    mapping(bytes32 => Proposal) public proposals;
    mapping(bytes32 => mapping(address => Vote)) public votes;
    mapping(address => uint256) public votingPower;

    address public admin;
    uint32 public votingDuration;
    uint256 public proposalThreshold;
    uint256 public quorumThreshold;
    uint32 public proposalCount;

    event ProposalCreated(bytes32 indexed proposalId, address indexed proposer, string description);
    event VoteCast(bytes32 indexed proposalId, address indexed voter, bool support, uint256 weight);
    event ProposalExecuted(bytes32 indexed proposalId);
    event VotingPowerUpdated(address indexed account, uint256 newPower);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    modifier validProposal(bytes32 proposalId) {
        require(proposals[proposalId].exists, "Proposal does not exist");
        _;
    }

    constructor(
        uint32 _votingDuration,
        uint256 _proposalThreshold,
        uint256 _quorumThreshold
    ) {
        admin = msg.sender;
        votingDuration = _votingDuration;
        proposalThreshold = _proposalThreshold;
        quorumThreshold = _quorumThreshold;
    }

    function setVotingPower(address account, uint256 power) external onlyAdmin {
        votingPower[account] = power;
        emit VotingPowerUpdated(account, power);
    }

    function createProposal(string calldata description) external returns (bytes32) {
        require(votingPower[msg.sender] >= proposalThreshold, "Insufficient voting power");
        require(bytes(description).length > 0, "Empty description");

        proposalCount++;
        bytes32 proposalId = keccak256(abi.encodePacked(
            DOMAIN_SEPARATOR,
            msg.sender,
            proposalCount,
            block.timestamp
        ));

        uint32 startTime = uint32(block.timestamp);
        uint32 endTime = startTime + votingDuration;

        proposals[proposalId] = Proposal({
            id: proposalId,
            proposer: msg.sender,
            description: description,
            votesFor: 0,
            votesAgainst: 0,
            startTime: startTime,
            endTime: endTime,
            executed: false,
            exists: true
        });

        emit ProposalCreated(proposalId, msg.sender, description);
        return proposalId;
    }

    function vote(bytes32 proposalId, bool support) external validProposal(proposalId) {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp >= proposal.startTime, "Voting not started");
        require(block.timestamp <= proposal.endTime, "Voting ended");
        require(!votes[proposalId][msg.sender].hasVoted, "Already voted");
        require(votingPower[msg.sender] > 0, "No voting power");

        uint256 weight = votingPower[msg.sender];

        votes[proposalId][msg.sender] = Vote({
            hasVoted: true,
            support: support,
            weight: weight
        });

        if (support) {
            proposal.votesFor += weight;
        } else {
            proposal.votesAgainst += weight;
        }

        emit VoteCast(proposalId, msg.sender, support, weight);
    }

    function executeProposal(bytes32 proposalId) external validProposal(proposalId) {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp > proposal.endTime, "Voting still active");
        require(!proposal.executed, "Already executed");

        uint256 totalVotes = proposal.votesFor + proposal.votesAgainst;
        require(totalVotes >= quorumThreshold, "Quorum not reached");
        require(proposal.votesFor > proposal.votesAgainst, "Proposal rejected");

        proposal.executed = true;
        emit ProposalExecuted(proposalId);
    }

    function getProposal(bytes32 proposalId) external view returns (
        address proposer,
        string memory description,
        uint256 votesFor,
        uint256 votesAgainst,
        uint32 startTime,
        uint32 endTime,
        bool executed
    ) {
        require(proposals[proposalId].exists, "Proposal does not exist");
        Proposal memory proposal = proposals[proposalId];
        return (
            proposal.proposer,
            proposal.description,
            proposal.votesFor,
            proposal.votesAgainst,
            proposal.startTime,
            proposal.endTime,
            proposal.executed
        );
    }

    function getVote(bytes32 proposalId, address voter) external view returns (
        bool hasVoted,
        bool support,
        uint256 weight
    ) {
        Vote memory userVote = votes[proposalId][voter];
        return (userVote.hasVoted, userVote.support, userVote.weight);
    }

    function isProposalActive(bytes32 proposalId) external view validProposal(proposalId) returns (bool) {
        Proposal memory proposal = proposals[proposalId];
        return block.timestamp >= proposal.startTime && block.timestamp <= proposal.endTime;
    }

    function updateVotingDuration(uint32 newDuration) external onlyAdmin {
        require(newDuration > 0, "Invalid duration");
        votingDuration = newDuration;
    }

    function updateProposalThreshold(uint256 newThreshold) external onlyAdmin {
        proposalThreshold = newThreshold;
    }

    function updateQuorumThreshold(uint256 newThreshold) external onlyAdmin {
        require(newThreshold > 0, "Invalid threshold");
        quorumThreshold = newThreshold;
    }
}
