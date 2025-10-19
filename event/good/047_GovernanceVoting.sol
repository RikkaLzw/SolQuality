
pragma solidity ^0.8.0;

contract GovernanceVoting {
    struct Proposal {
        uint256 id;
        string title;
        string description;
        address proposer;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        mapping(address => bool) hasVoted;
        mapping(address => bool) voteChoice;
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256) public votingPower;

    uint256 public proposalCount;
    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant MIN_VOTING_POWER = 1000;
    uint256 public constant EXECUTION_DELAY = 2 days;

    address public admin;
    bool public votingEnabled;

    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string title,
        uint256 startTime,
        uint256 endTime
    );

    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        bool support,
        uint256 votingPower
    );

    event ProposalExecuted(
        uint256 indexed proposalId,
        bool success
    );

    event VotingPowerUpdated(
        address indexed account,
        uint256 oldPower,
        uint256 newPower
    );

    event VotingStatusChanged(
        bool enabled
    );

    modifier onlyAdmin() {
        require(msg.sender == admin, "GovernanceVoting: caller is not admin");
        _;
    }

    modifier votingActive() {
        require(votingEnabled, "GovernanceVoting: voting is currently disabled");
        _;
    }

    modifier validProposal(uint256 proposalId) {
        require(proposalId > 0 && proposalId <= proposalCount, "GovernanceVoting: invalid proposal ID");
        _;
    }

    constructor() {
        admin = msg.sender;
        votingEnabled = true;
        proposalCount = 0;
    }

    function setVotingPower(address account, uint256 power) external onlyAdmin {
        require(account != address(0), "GovernanceVoting: cannot set voting power for zero address");

        uint256 oldPower = votingPower[account];
        votingPower[account] = power;

        emit VotingPowerUpdated(account, oldPower, power);
    }

    function setVotingStatus(bool enabled) external onlyAdmin {
        votingEnabled = enabled;
        emit VotingStatusChanged(enabled);
    }

    function createProposal(
        string memory title,
        string memory description
    ) external votingActive returns (uint256) {
        require(bytes(title).length > 0, "GovernanceVoting: proposal title cannot be empty");
        require(bytes(description).length > 0, "GovernanceVoting: proposal description cannot be empty");
        require(votingPower[msg.sender] >= MIN_VOTING_POWER, "GovernanceVoting: insufficient voting power to create proposal");

        proposalCount++;
        uint256 proposalId = proposalCount;

        Proposal storage newProposal = proposals[proposalId];
        newProposal.id = proposalId;
        newProposal.title = title;
        newProposal.description = description;
        newProposal.proposer = msg.sender;
        newProposal.startTime = block.timestamp;
        newProposal.endTime = block.timestamp + VOTING_PERIOD;
        newProposal.executed = false;
        newProposal.forVotes = 0;
        newProposal.againstVotes = 0;

        emit ProposalCreated(
            proposalId,
            msg.sender,
            title,
            newProposal.startTime,
            newProposal.endTime
        );

        return proposalId;
    }

    function vote(uint256 proposalId, bool support) external votingActive validProposal(proposalId) {
        Proposal storage proposal = proposals[proposalId];

        require(block.timestamp >= proposal.startTime, "GovernanceVoting: voting has not started yet");
        require(block.timestamp <= proposal.endTime, "GovernanceVoting: voting period has ended");
        require(!proposal.hasVoted[msg.sender], "GovernanceVoting: voter has already voted on this proposal");
        require(votingPower[msg.sender] > 0, "GovernanceVoting: voter has no voting power");

        proposal.hasVoted[msg.sender] = true;
        proposal.voteChoice[msg.sender] = support;

        uint256 voterPower = votingPower[msg.sender];

        if (support) {
            proposal.forVotes += voterPower;
        } else {
            proposal.againstVotes += voterPower;
        }

        emit VoteCast(proposalId, msg.sender, support, voterPower);
    }

    function executeProposal(uint256 proposalId) external validProposal(proposalId) {
        Proposal storage proposal = proposals[proposalId];

        require(block.timestamp > proposal.endTime, "GovernanceVoting: voting period has not ended");
        require(!proposal.executed, "GovernanceVoting: proposal has already been executed");
        require(block.timestamp >= proposal.endTime + EXECUTION_DELAY, "GovernanceVoting: execution delay has not passed");

        bool success = proposal.forVotes > proposal.againstVotes;
        proposal.executed = true;

        emit ProposalExecuted(proposalId, success);
    }

    function getProposalInfo(uint256 proposalId) external view validProposal(proposalId) returns (
        string memory title,
        string memory description,
        address proposer,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 startTime,
        uint256 endTime,
        bool executed
    ) {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.title,
            proposal.description,
            proposal.proposer,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.startTime,
            proposal.endTime,
            proposal.executed
        );
    }

    function hasVoted(uint256 proposalId, address voter) external view validProposal(proposalId) returns (bool) {
        return proposals[proposalId].hasVoted[voter];
    }

    function getVoteChoice(uint256 proposalId, address voter) external view validProposal(proposalId) returns (bool) {
        require(proposals[proposalId].hasVoted[voter], "GovernanceVoting: voter has not voted on this proposal");
        return proposals[proposalId].voteChoice[voter];
    }

    function getProposalStatus(uint256 proposalId) external view validProposal(proposalId) returns (string memory) {
        Proposal storage proposal = proposals[proposalId];

        if (block.timestamp < proposal.startTime) {
            return "Not Started";
        } else if (block.timestamp <= proposal.endTime) {
            return "Active";
        } else if (!proposal.executed && block.timestamp < proposal.endTime + EXECUTION_DELAY) {
            return "Pending Execution";
        } else if (!proposal.executed) {
            return "Ready for Execution";
        } else if (proposal.forVotes > proposal.againstVotes) {
            return "Executed - Passed";
        } else {
            return "Executed - Failed";
        }
    }

    function transferAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "GovernanceVoting: new admin cannot be zero address");
        require(newAdmin != admin, "GovernanceVoting: new admin cannot be the same as current admin");

        admin = newAdmin;
    }
}
