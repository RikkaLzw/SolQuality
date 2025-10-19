
pragma solidity ^0.8.0;

contract VotingGovernance {
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
        mapping(address => bool) hasVoted;
        mapping(address => VoteType) votes;
    }

    enum VoteType { Against, For, Abstain }
    enum ProposalState { Pending, Active, Succeeded, Defeated, Executed }

    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256) public votingPower;

    uint256 public proposalCount;
    uint256 public constant VOTING_PERIOD = 3 days;
    uint256 public constant MIN_VOTING_POWER = 1000;
    uint256 public constant QUORUM_PERCENTAGE = 10;

    address public owner;
    uint256 public totalVotingPower;

    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string description);
    event VoteCast(uint256 indexed proposalId, address indexed voter, VoteType voteType, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId);
    event VotingPowerUpdated(address indexed account, uint256 newPower);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier validProposal(uint256 proposalId) {
        require(proposalId < proposalCount, "Invalid proposal ID");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function setVotingPower(address account, uint256 power) external onlyOwner {
        uint256 oldPower = votingPower[account];
        votingPower[account] = power;


        if (power > oldPower) {
            totalVotingPower += (power - oldPower);
        } else {
            totalVotingPower -= (oldPower - power);
        }

        emit VotingPowerUpdated(account, power);
    }

    function createProposal(string calldata description) external returns (uint256) {
        require(votingPower[msg.sender] >= MIN_VOTING_POWER, "Insufficient voting power to create proposal");
        require(bytes(description).length > 0, "Description cannot be empty");

        uint256 proposalId = proposalCount++;
        Proposal storage newProposal = proposals[proposalId];

        newProposal.id = proposalId;
        newProposal.proposer = msg.sender;
        newProposal.description = description;
        newProposal.startTime = block.timestamp;
        newProposal.endTime = block.timestamp + VOTING_PERIOD;

        emit ProposalCreated(proposalId, msg.sender, description);
        return proposalId;
    }

    function vote(uint256 proposalId, VoteType voteType) external validProposal(proposalId) {
        Proposal storage proposal = proposals[proposalId];
        uint256 voterPower = votingPower[msg.sender];

        require(voterPower > 0, "No voting power");
        require(!proposal.hasVoted[msg.sender], "Already voted");
        require(block.timestamp >= proposal.startTime, "Voting not started");
        require(block.timestamp <= proposal.endTime, "Voting period ended");
        require(!proposal.executed, "Proposal already executed");


        proposal.hasVoted[msg.sender] = true;
        proposal.votes[msg.sender] = voteType;


        if (voteType == VoteType.For) {
            proposal.forVotes += voterPower;
        } else if (voteType == VoteType.Against) {
            proposal.againstVotes += voterPower;
        } else {
            proposal.abstainVotes += voterPower;
        }

        emit VoteCast(proposalId, msg.sender, voteType, voterPower);
    }

    function executeProposal(uint256 proposalId) external validProposal(proposalId) {
        require(getProposalState(proposalId) == ProposalState.Succeeded, "Proposal not ready for execution");

        Proposal storage proposal = proposals[proposalId];
        proposal.executed = true;

        emit ProposalExecuted(proposalId);
    }

    function getProposalState(uint256 proposalId) public view validProposal(proposalId) returns (ProposalState) {
        Proposal storage proposal = proposals[proposalId];

        if (proposal.executed) {
            return ProposalState.Executed;
        }

        if (block.timestamp <= proposal.endTime) {
            return block.timestamp >= proposal.startTime ? ProposalState.Active : ProposalState.Pending;
        }


        uint256 totalVotes = proposal.forVotes + proposal.againstVotes + proposal.abstainVotes;
        uint256 quorumRequired = (totalVotingPower * QUORUM_PERCENTAGE) / 100;

        if (totalVotes < quorumRequired) {
            return ProposalState.Defeated;
        }

        return proposal.forVotes > proposal.againstVotes ? ProposalState.Succeeded : ProposalState.Defeated;
    }

    function getProposalVotes(uint256 proposalId) external view validProposal(proposalId)
        returns (uint256 forVotes, uint256 againstVotes, uint256 abstainVotes) {
        Proposal storage proposal = proposals[proposalId];
        return (proposal.forVotes, proposal.againstVotes, proposal.abstainVotes);
    }

    function getProposalInfo(uint256 proposalId) external view validProposal(proposalId)
        returns (
            address proposer,
            string memory description,
            uint256 startTime,
            uint256 endTime,
            bool executed,
            ProposalState state
        ) {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.proposer,
            proposal.description,
            proposal.startTime,
            proposal.endTime,
            proposal.executed,
            getProposalState(proposalId)
        );
    }

    function hasVoted(uint256 proposalId, address voter) external view validProposal(proposalId) returns (bool) {
        return proposals[proposalId].hasVoted[voter];
    }

    function getVote(uint256 proposalId, address voter) external view validProposal(proposalId) returns (VoteType) {
        require(proposals[proposalId].hasVoted[voter], "Voter has not voted");
        return proposals[proposalId].votes[voter];
    }

    function getQuorumRequired() external view returns (uint256) {
        return (totalVotingPower * QUORUM_PERCENTAGE) / 100;
    }
}
