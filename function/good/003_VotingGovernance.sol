
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

    struct Voter {
        uint256 votingPower;
        bool isRegistered;
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(address => Voter) public voters;

    uint256 public proposalCount;
    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant MIN_VOTING_POWER = 1;
    uint256 public quorumPercentage = 51;

    address public admin;
    bool public votingEnabled;

    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string description);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 votingPower);
    event ProposalExecuted(uint256 indexed proposalId);
    event VoterRegistered(address indexed voter, uint256 votingPower);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    modifier onlyRegisteredVoter() {
        require(voters[msg.sender].isRegistered, "Voter not registered");
        _;
    }

    modifier votingIsEnabled() {
        require(votingEnabled, "Voting is currently disabled");
        _;
    }

    constructor() {
        admin = msg.sender;
        votingEnabled = true;
    }

    function registerVoter(address voter, uint256 votingPower) external onlyAdmin {
        require(voter != address(0), "Invalid voter address");
        require(votingPower >= MIN_VOTING_POWER, "Insufficient voting power");

        voters[voter] = Voter({
            votingPower: votingPower,
            isRegistered: true
        });

        emit VoterRegistered(voter, votingPower);
    }

    function createProposal(string memory description) external onlyRegisteredVoter votingIsEnabled returns (uint256) {
        require(bytes(description).length > 0, "Description cannot be empty");

        uint256 proposalId = proposalCount++;
        Proposal storage newProposal = proposals[proposalId];

        newProposal.id = proposalId;
        newProposal.description = description;
        newProposal.startTime = block.timestamp;
        newProposal.endTime = block.timestamp + VOTING_PERIOD;
        newProposal.proposer = msg.sender;

        emit ProposalCreated(proposalId, msg.sender, description);
        return proposalId;
    }

    function vote(uint256 proposalId, bool support) external onlyRegisteredVoter votingIsEnabled {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.startTime > 0, "Proposal does not exist");
        require(block.timestamp >= proposal.startTime, "Voting has not started");
        require(block.timestamp <= proposal.endTime, "Voting has ended");
        require(!proposal.hasVoted[msg.sender], "Already voted");

        uint256 voterPower = voters[msg.sender].votingPower;
        proposal.hasVoted[msg.sender] = true;
        proposal.voteChoice[msg.sender] = support;

        if (support) {
            proposal.forVotes += voterPower;
        } else {
            proposal.againstVotes += voterPower;
        }

        emit VoteCast(proposalId, msg.sender, support, voterPower);
    }

    function executeProposal(uint256 proposalId) external returns (bool) {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.startTime > 0, "Proposal does not exist");
        require(block.timestamp > proposal.endTime, "Voting still active");
        require(!proposal.executed, "Proposal already executed");

        bool passed = _checkProposalPassed(proposalId);
        if (passed) {
            proposal.executed = true;
            emit ProposalExecuted(proposalId);
        }

        return passed;
    }

    function getProposalInfo(uint256 proposalId) external view returns (
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

    function hasVoted(uint256 proposalId, address voter) external view returns (bool) {
        return proposals[proposalId].hasVoted[voter];
    }

    function getVoteChoice(uint256 proposalId, address voter) external view returns (bool) {
        require(proposals[proposalId].hasVoted[voter], "Voter has not voted");
        return proposals[proposalId].voteChoice[voter];
    }

    function setQuorumPercentage(uint256 newPercentage) external onlyAdmin {
        require(newPercentage > 0 && newPercentage <= 100, "Invalid percentage");
        quorumPercentage = newPercentage;
    }

    function toggleVoting() external onlyAdmin {
        votingEnabled = !votingEnabled;
    }

    function _checkProposalPassed(uint256 proposalId) internal view returns (bool) {
        Proposal storage proposal = proposals[proposalId];
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes;

        if (totalVotes == 0) return false;

        uint256 forPercentage = (proposal.forVotes * 100) / totalVotes;
        return forPercentage >= quorumPercentage;
    }

    function _getTotalVotingPower() internal view returns (uint256) {


        return 1000;
    }
}
