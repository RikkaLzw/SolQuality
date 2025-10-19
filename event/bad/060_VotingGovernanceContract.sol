
pragma solidity ^0.8.0;

contract VotingGovernanceContract {
    struct Proposal {
        uint256 id;
        string description;
        uint256 voteCount;
        uint256 deadline;
        bool executed;
        address proposer;
        mapping(address => bool) hasVoted;
    }

    address public owner;
    uint256 public proposalCount;
    uint256 public votingPeriod = 7 days;
    uint256 public minimumVotes = 10;

    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256) public votingPower;
    mapping(address => bool) public isEligibleVoter;

    error InvalidProposal();
    error NotAuthorized();
    error VotingEnded();
    error AlreadyVoted();

    event ProposalCreated(uint256 proposalId, string description, address proposer);
    event VoteCast(address voter, uint256 proposalId);
    event ProposalExecuted(uint256 proposalId);

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier onlyEligibleVoter() {
        require(isEligibleVoter[msg.sender]);
        _;
    }

    constructor() {
        owner = msg.sender;
        isEligibleVoter[msg.sender] = true;
        votingPower[msg.sender] = 100;
    }

    function addVoter(address voter, uint256 power) external onlyOwner {
        require(voter != address(0));
        isEligibleVoter[voter] = true;
        votingPower[voter] = power;
    }

    function removeVoter(address voter) external onlyOwner {
        require(voter != address(0));
        isEligibleVoter[voter] = false;
        votingPower[voter] = 0;
    }

    function createProposal(string memory description) external onlyEligibleVoter {
        require(bytes(description).length > 0);

        proposalCount++;
        Proposal storage newProposal = proposals[proposalCount];
        newProposal.id = proposalCount;
        newProposal.description = description;
        newProposal.deadline = block.timestamp + votingPeriod;
        newProposal.proposer = msg.sender;

        emit ProposalCreated(proposalCount, description, msg.sender);
    }

    function vote(uint256 proposalId) external onlyEligibleVoter {
        Proposal storage proposal = proposals[proposalId];

        require(proposalId > 0 && proposalId <= proposalCount);
        require(block.timestamp <= proposal.deadline);
        require(!proposal.hasVoted[msg.sender]);
        require(!proposal.executed);

        proposal.hasVoted[msg.sender] = true;
        proposal.voteCount += votingPower[msg.sender];

        emit VoteCast(msg.sender, proposalId);
    }

    function executeProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];

        require(proposalId > 0 && proposalId <= proposalCount);
        require(block.timestamp > proposal.deadline);
        require(!proposal.executed);
        require(proposal.voteCount >= minimumVotes);

        proposal.executed = true;

        emit ProposalExecuted(proposalId);
    }

    function getProposal(uint256 proposalId) external view returns (
        uint256 id,
        string memory description,
        uint256 voteCount,
        uint256 deadline,
        bool executed,
        address proposer
    ) {
        require(proposalId > 0 && proposalId <= proposalCount);

        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.id,
            proposal.description,
            proposal.voteCount,
            proposal.deadline,
            proposal.executed,
            proposal.proposer
        );
    }

    function hasVoted(uint256 proposalId, address voter) external view returns (bool) {
        require(proposalId > 0 && proposalId <= proposalCount);
        return proposals[proposalId].hasVoted[voter];
    }

    function setVotingPeriod(uint256 newPeriod) external onlyOwner {
        require(newPeriod > 0);
        votingPeriod = newPeriod;
    }

    function setMinimumVotes(uint256 newMinimum) external onlyOwner {
        require(newMinimum > 0);
        minimumVotes = newMinimum;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0));
        owner = newOwner;
    }
}
