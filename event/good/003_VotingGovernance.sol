
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
    mapping(address => bool) public isEligibleVoter;

    uint256 public proposalCount;
    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant MIN_VOTING_POWER = 1000;
    uint256 public constant QUORUM_PERCENTAGE = 30;
    uint256 public totalVotingPower;

    address public admin;
    bool public paused;

    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string description,
        uint256 startTime,
        uint256 endTime
    );

    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        bool support,
        uint256 votingPower
    );

    event ProposalExecuted(uint256 indexed proposalId, bool passed);

    event VoterRegistered(address indexed voter, uint256 votingPower);

    event VoterRemoved(address indexed voter);

    event AdminChanged(address indexed oldAdmin, address indexed newAdmin);

    event ContractPaused();

    event ContractUnpaused();

    modifier onlyAdmin() {
        require(msg.sender == admin, "VotingGovernance: caller is not the admin");
        _;
    }

    modifier onlyEligibleVoter() {
        require(isEligibleVoter[msg.sender], "VotingGovernance: caller is not an eligible voter");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "VotingGovernance: contract is paused");
        _;
    }

    modifier proposalExists(uint256 proposalId) {
        require(proposalId > 0 && proposalId <= proposalCount, "VotingGovernance: proposal does not exist");
        _;
    }

    constructor() {
        admin = msg.sender;
        paused = false;
    }

    function registerVoter(address voter, uint256 power) external onlyAdmin {
        require(voter != address(0), "VotingGovernance: invalid voter address");
        require(power >= MIN_VOTING_POWER, "VotingGovernance: insufficient voting power");
        require(!isEligibleVoter[voter], "VotingGovernance: voter already registered");

        isEligibleVoter[voter] = true;
        votingPower[voter] = power;
        totalVotingPower += power;

        emit VoterRegistered(voter, power);
    }

    function removeVoter(address voter) external onlyAdmin {
        require(isEligibleVoter[voter], "VotingGovernance: voter is not registered");

        totalVotingPower -= votingPower[voter];
        isEligibleVoter[voter] = false;
        votingPower[voter] = 0;

        emit VoterRemoved(voter);
    }

    function createProposal(string memory description) external onlyEligibleVoter whenNotPaused {
        require(bytes(description).length > 0, "VotingGovernance: proposal description cannot be empty");
        require(bytes(description).length <= 1000, "VotingGovernance: proposal description too long");

        proposalCount++;
        uint256 proposalId = proposalCount;

        Proposal storage newProposal = proposals[proposalId];
        newProposal.id = proposalId;
        newProposal.description = description;
        newProposal.startTime = block.timestamp;
        newProposal.endTime = block.timestamp + VOTING_PERIOD;
        newProposal.proposer = msg.sender;
        newProposal.executed = false;
        newProposal.forVotes = 0;
        newProposal.againstVotes = 0;

        emit ProposalCreated(proposalId, msg.sender, description, newProposal.startTime, newProposal.endTime);
    }

    function vote(uint256 proposalId, bool support) external onlyEligibleVoter whenNotPaused proposalExists(proposalId) {
        Proposal storage proposal = proposals[proposalId];

        require(block.timestamp >= proposal.startTime, "VotingGovernance: voting has not started yet");
        require(block.timestamp <= proposal.endTime, "VotingGovernance: voting period has ended");
        require(!proposal.hasVoted[msg.sender], "VotingGovernance: voter has already voted");
        require(!proposal.executed, "VotingGovernance: proposal has already been executed");

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

    function executeProposal(uint256 proposalId) external whenNotPaused proposalExists(proposalId) {
        Proposal storage proposal = proposals[proposalId];

        require(block.timestamp > proposal.endTime, "VotingGovernance: voting period has not ended");
        require(!proposal.executed, "VotingGovernance: proposal has already been executed");

        uint256 totalVotes = proposal.forVotes + proposal.againstVotes;
        uint256 requiredQuorum = (totalVotingPower * QUORUM_PERCENTAGE) / 100;

        require(totalVotes >= requiredQuorum, "VotingGovernance: quorum not reached");

        proposal.executed = true;
        bool passed = proposal.forVotes > proposal.againstVotes;

        emit ProposalExecuted(proposalId, passed);
    }

    function getProposalDetails(uint256 proposalId) external view proposalExists(proposalId) returns (
        uint256 id,
        string memory description,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 startTime,
        uint256 endTime,
        bool executed,
        address proposer
    ) {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.id,
            proposal.description,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.startTime,
            proposal.endTime,
            proposal.executed,
            proposal.proposer
        );
    }

    function hasVoted(uint256 proposalId, address voter) external view proposalExists(proposalId) returns (bool) {
        return proposals[proposalId].hasVoted[voter];
    }

    function getVoteChoice(uint256 proposalId, address voter) external view proposalExists(proposalId) returns (bool) {
        require(proposals[proposalId].hasVoted[voter], "VotingGovernance: voter has not voted on this proposal");
        return proposals[proposalId].voteChoice[voter];
    }

    function isProposalPassed(uint256 proposalId) external view proposalExists(proposalId) returns (bool) {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.executed, "VotingGovernance: proposal has not been executed yet");
        return proposal.forVotes > proposal.againstVotes;
    }

    function getQuorumStatus(uint256 proposalId) external view proposalExists(proposalId) returns (bool, uint256, uint256) {
        Proposal storage proposal = proposals[proposalId];
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes;
        uint256 requiredQuorum = (totalVotingPower * QUORUM_PERCENTAGE) / 100;
        return (totalVotes >= requiredQuorum, totalVotes, requiredQuorum);
    }

    function changeAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "VotingGovernance: new admin cannot be zero address");
        require(newAdmin != admin, "VotingGovernance: new admin is the same as current admin");

        address oldAdmin = admin;
        admin = newAdmin;

        emit AdminChanged(oldAdmin, newAdmin);
    }

    function pauseContract() external onlyAdmin {
        require(!paused, "VotingGovernance: contract is already paused");
        paused = true;
        emit ContractPaused();
    }

    function unpauseContract() external onlyAdmin {
        require(paused, "VotingGovernance: contract is not paused");
        paused = false;
        emit ContractUnpaused();
    }

    function emergencyStop() external onlyAdmin {
        if (!paused) {
            paused = true;
            emit ContractPaused();
        }
    }
}
