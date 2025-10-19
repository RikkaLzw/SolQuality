
pragma solidity ^0.8.0;

contract VotingGovernance {
    struct Proposal {
        uint256 id;
        string description;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 deadline;
        bool executed;
        address proposer;
        mapping(address => bool) hasVoted;
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256) public votingPower;

    uint256 public proposalCount;
    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant MIN_VOTING_POWER = 100;

    address public admin;

    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string description);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 power);
    event ProposalExecuted(uint256 indexed proposalId);
    event VotingPowerGranted(address indexed account, uint256 power);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    modifier hasVotingRights(address voter) {
        require(votingPower[voter] >= MIN_VOTING_POWER, "Insufficient voting power");
        _;
    }

    modifier proposalExists(uint256 proposalId) {
        require(proposalId < proposalCount, "Proposal does not exist");
        _;
    }

    modifier votingActive(uint256 proposalId) {
        require(block.timestamp <= proposals[proposalId].deadline, "Voting period ended");
        require(!proposals[proposalId].executed, "Proposal already executed");
        _;
    }

    constructor() {
        admin = msg.sender;
        votingPower[msg.sender] = 1000;
    }

    function createProposal(string memory description) external hasVotingRights(msg.sender) returns (uint256) {
        require(bytes(description).length > 0, "Description cannot be empty");

        uint256 proposalId = proposalCount++;
        Proposal storage newProposal = proposals[proposalId];

        newProposal.id = proposalId;
        newProposal.description = description;
        newProposal.deadline = block.timestamp + VOTING_PERIOD;
        newProposal.proposer = msg.sender;

        emit ProposalCreated(proposalId, msg.sender, description);
        return proposalId;
    }

    function vote(uint256 proposalId, bool support)
        external
        proposalExists(proposalId)
        votingActive(proposalId)
        hasVotingRights(msg.sender)
    {
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.hasVoted[msg.sender], "Already voted on this proposal");

        proposal.hasVoted[msg.sender] = true;
        uint256 voterPower = votingPower[msg.sender];

        if (support) {
            proposal.votesFor += voterPower;
        } else {
            proposal.votesAgainst += voterPower;
        }

        emit VoteCast(proposalId, msg.sender, support, voterPower);
    }

    function executeProposal(uint256 proposalId)
        external
        proposalExists(proposalId)
        returns (bool)
    {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp > proposal.deadline, "Voting period not ended");
        require(!proposal.executed, "Proposal already executed");
        require(proposal.votesFor > proposal.votesAgainst, "Proposal rejected");

        proposal.executed = true;
        emit ProposalExecuted(proposalId);
        return true;
    }

    function grantVotingPower(address account, uint256 power) external onlyAdmin {
        require(account != address(0), "Invalid address");
        require(power > 0, "Power must be greater than 0");

        votingPower[account] = power;
        emit VotingPowerGranted(account, power);
    }

    function getProposalInfo(uint256 proposalId)
        external
        view
        proposalExists(proposalId)
        returns (
            string memory description,
            uint256 votesFor,
            uint256 votesAgainst,
            uint256 deadline,
            bool executed,
            address proposer
        )
    {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.description,
            proposal.votesFor,
            proposal.votesAgainst,
            proposal.deadline,
            proposal.executed,
            proposal.proposer
        );
    }

    function hasVoted(uint256 proposalId, address voter)
        external
        view
        proposalExists(proposalId)
        returns (bool)
    {
        return proposals[proposalId].hasVoted[voter];
    }

    function isVotingActive(uint256 proposalId)
        external
        view
        proposalExists(proposalId)
        returns (bool)
    {
        Proposal storage proposal = proposals[proposalId];
        return block.timestamp <= proposal.deadline && !proposal.executed;
    }

    function getVotingPower(address account) external view returns (uint256) {
        return votingPower[account];
    }
}
