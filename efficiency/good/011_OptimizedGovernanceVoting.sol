
pragma solidity ^0.8.19;

contract OptimizedGovernanceVoting {
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
        mapping(address => Vote) votes;
    }

    struct Vote {
        bool hasVoted;
        uint8 support;
        uint256 weight;
    }

    struct ProposalInfo {
        uint256 id;
        address proposer;
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        uint256 startTime;
        uint256 endTime;
        bool executed;
    }

    mapping(uint256 => Proposal) private proposals;
    mapping(address => uint256) private votingPower;
    mapping(address => bool) private authorized;

    uint256 private proposalCounter;
    uint256 private constant VOTING_PERIOD = 7 days;
    uint256 private constant MIN_VOTING_POWER = 1000;
    uint256 private constant QUORUM_THRESHOLD = 10000;
    uint256 private totalVotingPower;

    address private admin;

    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string description);
    event VoteCast(uint256 indexed proposalId, address indexed voter, uint8 support, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId);
    event VotingPowerUpdated(address indexed account, uint256 newPower);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    modifier onlyAuthorized() {
        require(authorized[msg.sender] || msg.sender == admin, "Not authorized");
        _;
    }

    constructor() {
        admin = msg.sender;
        authorized[msg.sender] = true;
    }

    function setVotingPower(address account, uint256 power) external onlyAdmin {
        uint256 oldPower = votingPower[account];
        votingPower[account] = power;


        if (power > oldPower) {
            totalVotingPower += (power - oldPower);
        } else {
            totalVotingPower -= (oldPower - power);
        }

        emit VotingPowerUpdated(account, power);
    }

    function authorize(address account) external onlyAdmin {
        authorized[account] = true;
    }

    function deauthorize(address account) external onlyAdmin {
        require(account != admin, "Cannot deauthorize admin");
        authorized[account] = false;
    }

    function createProposal(string calldata description) external onlyAuthorized returns (uint256) {
        require(bytes(description).length > 0, "Empty description");
        require(votingPower[msg.sender] >= MIN_VOTING_POWER, "Insufficient voting power");

        uint256 proposalId = ++proposalCounter;
        Proposal storage proposal = proposals[proposalId];

        proposal.id = proposalId;
        proposal.proposer = msg.sender;
        proposal.description = description;
        proposal.startTime = block.timestamp;
        proposal.endTime = block.timestamp + VOTING_PERIOD;

        emit ProposalCreated(proposalId, msg.sender, description);
        return proposalId;
    }

    function vote(uint256 proposalId, uint8 support) external {
        require(support <= 2, "Invalid support value");

        Proposal storage proposal = proposals[proposalId];
        require(proposal.id != 0, "Proposal does not exist");
        require(block.timestamp >= proposal.startTime, "Voting not started");
        require(block.timestamp <= proposal.endTime, "Voting ended");
        require(!proposal.votes[msg.sender].hasVoted, "Already voted");

        uint256 weight = votingPower[msg.sender];
        require(weight > 0, "No voting power");


        Vote storage userVote = proposal.votes[msg.sender];
        userVote.hasVoted = true;
        userVote.support = support;
        userVote.weight = weight;


        if (support == 0) {
            proposal.againstVotes += weight;
        } else if (support == 1) {
            proposal.forVotes += weight;
        } else {
            proposal.abstainVotes += weight;
        }

        emit VoteCast(proposalId, msg.sender, support, weight);
    }

    function executeProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.id != 0, "Proposal does not exist");
        require(block.timestamp > proposal.endTime, "Voting still active");
        require(!proposal.executed, "Already executed");


        uint256 forVotes = proposal.forVotes;
        uint256 againstVotes = proposal.againstVotes;
        uint256 abstainVotes = proposal.abstainVotes;
        uint256 totalVotes = forVotes + againstVotes + abstainVotes;

        require(totalVotes >= (totalVotingPower * QUORUM_THRESHOLD) / 100000, "Quorum not reached");
        require(forVotes > againstVotes, "Proposal rejected");

        proposal.executed = true;
        emit ProposalExecuted(proposalId);
    }

    function getProposal(uint256 proposalId) external view returns (ProposalInfo memory) {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.id != 0, "Proposal does not exist");

        return ProposalInfo({
            id: proposal.id,
            proposer: proposal.proposer,
            description: proposal.description,
            forVotes: proposal.forVotes,
            againstVotes: proposal.againstVotes,
            abstainVotes: proposal.abstainVotes,
            startTime: proposal.startTime,
            endTime: proposal.endTime,
            executed: proposal.executed
        });
    }

    function getVote(uint256 proposalId, address voter) external view returns (bool hasVoted, uint8 support, uint256 weight) {
        Vote storage vote = proposals[proposalId].votes[voter];
        return (vote.hasVoted, vote.support, vote.weight);
    }

    function getVotingPower(address account) external view returns (uint256) {
        return votingPower[account];
    }

    function getTotalVotingPower() external view returns (uint256) {
        return totalVotingPower;
    }

    function getProposalCount() external view returns (uint256) {
        return proposalCounter;
    }

    function isAuthorized(address account) external view returns (bool) {
        return authorized[account];
    }

    function proposalState(uint256 proposalId) external view returns (string memory) {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.id != 0, "Proposal does not exist");

        if (proposal.executed) {
            return "Executed";
        }

        if (block.timestamp <= proposal.endTime) {
            return "Active";
        }

        uint256 totalVotes = proposal.forVotes + proposal.againstVotes + proposal.abstainVotes;

        if (totalVotes < (totalVotingPower * QUORUM_THRESHOLD) / 100000) {
            return "Failed (No Quorum)";
        }

        if (proposal.forVotes > proposal.againstVotes) {
            return "Succeeded";
        } else {
            return "Defeated";
        }
    }
}
