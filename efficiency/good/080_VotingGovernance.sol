
pragma solidity ^0.8.0;

contract VotingGovernance {
    struct Proposal {
        uint256 id;
        string description;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        address proposer;
        mapping(address => bool) hasVoted;
        mapping(address => bool) voteChoice;
    }

    struct ProposalInfo {
        uint256 id;
        string description;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        address proposer;
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256) public votingPower;
    mapping(address => bool) public isEligibleVoter;

    uint256 public proposalCount;
    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant MIN_VOTING_POWER = 1000;
    uint256 public quorumThreshold = 5000;

    address public admin;
    bool public votingEnabled = true;

    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string description);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 power);
    event ProposalExecuted(uint256 indexed proposalId, bool success);
    event VotingPowerUpdated(address indexed voter, uint256 newPower);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    modifier onlyEligibleVoter() {
        require(isEligibleVoter[msg.sender], "Not eligible voter");
        require(votingPower[msg.sender] >= MIN_VOTING_POWER, "Insufficient voting power");
        _;
    }

    modifier votingIsEnabled() {
        require(votingEnabled, "Voting disabled");
        _;
    }

    constructor() {
        admin = msg.sender;
        isEligibleVoter[msg.sender] = true;
        votingPower[msg.sender] = 10000;
    }

    function createProposal(string calldata description) external onlyEligibleVoter votingIsEnabled returns (uint256) {
        require(bytes(description).length > 0, "Empty description");
        require(bytes(description).length <= 500, "Description too long");

        uint256 proposalId = ++proposalCount;
        Proposal storage newProposal = proposals[proposalId];

        newProposal.id = proposalId;
        newProposal.description = description;
        newProposal.startTime = block.timestamp;
        newProposal.endTime = block.timestamp + VOTING_PERIOD;
        newProposal.proposer = msg.sender;

        emit ProposalCreated(proposalId, msg.sender, description);
        return proposalId;
    }

    function vote(uint256 proposalId, bool support) external onlyEligibleVoter votingIsEnabled {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.id != 0, "Proposal not found");
        require(block.timestamp >= proposal.startTime, "Voting not started");
        require(block.timestamp <= proposal.endTime, "Voting ended");
        require(!proposal.hasVoted[msg.sender], "Already voted");

        uint256 voterPower = votingPower[msg.sender];
        proposal.hasVoted[msg.sender] = true;
        proposal.voteChoice[msg.sender] = support;

        if (support) {
            proposal.votesFor += voterPower;
        } else {
            proposal.votesAgainst += voterPower;
        }

        emit VoteCast(proposalId, msg.sender, support, voterPower);
    }

    function executeProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.id != 0, "Proposal not found");
        require(block.timestamp > proposal.endTime, "Voting still active");
        require(!proposal.executed, "Already executed");

        uint256 totalVotes = proposal.votesFor + proposal.votesAgainst;
        require(totalVotes >= quorumThreshold, "Quorum not reached");

        bool success = proposal.votesFor > proposal.votesAgainst;
        proposal.executed = true;

        emit ProposalExecuted(proposalId, success);
    }

    function getProposal(uint256 proposalId) external view returns (ProposalInfo memory) {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.id != 0, "Proposal not found");

        return ProposalInfo({
            id: proposal.id,
            description: proposal.description,
            votesFor: proposal.votesFor,
            votesAgainst: proposal.votesAgainst,
            startTime: proposal.startTime,
            endTime: proposal.endTime,
            executed: proposal.executed,
            proposer: proposal.proposer
        });
    }

    function hasVoted(uint256 proposalId, address voter) external view returns (bool) {
        return proposals[proposalId].hasVoted[voter];
    }

    function getVoteChoice(uint256 proposalId, address voter) external view returns (bool) {
        require(proposals[proposalId].hasVoted[voter], "Has not voted");
        return proposals[proposalId].voteChoice[voter];
    }

    function addVoter(address voter, uint256 power) external onlyAdmin {
        require(voter != address(0), "Invalid address");
        require(power >= MIN_VOTING_POWER, "Power too low");

        isEligibleVoter[voter] = true;
        votingPower[voter] = power;

        emit VotingPowerUpdated(voter, power);
    }

    function removeVoter(address voter) external onlyAdmin {
        require(voter != admin, "Cannot remove admin");

        isEligibleVoter[voter] = false;
        votingPower[voter] = 0;

        emit VotingPowerUpdated(voter, 0);
    }

    function updateVotingPower(address voter, uint256 newPower) external onlyAdmin {
        require(isEligibleVoter[voter], "Not eligible voter");
        require(newPower >= MIN_VOTING_POWER, "Power too low");

        votingPower[voter] = newPower;
        emit VotingPowerUpdated(voter, newPower);
    }

    function setQuorumThreshold(uint256 newThreshold) external onlyAdmin {
        require(newThreshold > 0, "Invalid threshold");
        quorumThreshold = newThreshold;
    }

    function toggleVoting() external onlyAdmin {
        votingEnabled = !votingEnabled;
    }

    function getProposalStatus(uint256 proposalId) external view returns (
        bool isActive,
        bool hasQuorum,
        bool isPassing,
        uint256 totalVotes
    ) {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.id != 0, "Proposal not found");

        totalVotes = proposal.votesFor + proposal.votesAgainst;
        isActive = block.timestamp >= proposal.startTime &&
                  block.timestamp <= proposal.endTime &&
                  !proposal.executed;
        hasQuorum = totalVotes >= quorumThreshold;
        isPassing = proposal.votesFor > proposal.votesAgainst;
    }

    function getActiveProposals() external view returns (uint256[] memory) {
        uint256[] memory activeIds = new uint256[](proposalCount);
        uint256 count = 0;

        for (uint256 i = 1; i <= proposalCount; i++) {
            Proposal storage proposal = proposals[i];
            if (block.timestamp >= proposal.startTime &&
                block.timestamp <= proposal.endTime &&
                !proposal.executed) {
                activeIds[count] = i;
                count++;
            }
        }

        uint256[] memory result = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = activeIds[i];
        }

        return result;
    }
}
