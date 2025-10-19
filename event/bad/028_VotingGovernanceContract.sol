
pragma solidity ^0.8.0;

contract VotingGovernanceContract {
    struct Proposal {
        uint256 id;
        string description;
        uint256 voteCount;
        uint256 endTime;
        bool executed;
        address proposer;
        mapping(address => bool) hasVoted;
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256) public votingPower;
    uint256 public proposalCount;
    uint256 public constant VOTING_DURATION = 7 days;
    address public owner;

    event ProposalCreated(uint256 proposalId, string description);
    event VoteCast(address voter, uint256 proposalId);
    event ProposalExecuted(uint256 proposalId);

    error InvalidProposal();
    error NotAuthorized();
    error AlreadyVoted();

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    constructor() {
        owner = msg.sender;
        votingPower[msg.sender] = 100;
    }

    function setVotingPower(address voter, uint256 power) external onlyOwner {
        require(voter != address(0));
        require(power > 0);
        votingPower[voter] = power;
    }

    function createProposal(string memory description) external returns (uint256) {
        require(votingPower[msg.sender] > 0);
        require(bytes(description).length > 0);

        proposalCount++;
        uint256 proposalId = proposalCount;

        Proposal storage newProposal = proposals[proposalId];
        newProposal.id = proposalId;
        newProposal.description = description;
        newProposal.endTime = block.timestamp + VOTING_DURATION;
        newProposal.proposer = msg.sender;

        emit ProposalCreated(proposalId, description);
        return proposalId;
    }

    function vote(uint256 proposalId) external {
        require(votingPower[msg.sender] > 0);
        require(proposalId > 0 && proposalId <= proposalCount);

        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp <= proposal.endTime);
        require(!proposal.hasVoted[msg.sender]);
        require(!proposal.executed);

        proposal.hasVoted[msg.sender] = true;
        proposal.voteCount += votingPower[msg.sender];

        emit VoteCast(msg.sender, proposalId);
    }

    function executeProposal(uint256 proposalId) external {
        require(proposalId > 0 && proposalId <= proposalCount);

        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp > proposal.endTime);
        require(!proposal.executed);
        require(proposal.voteCount >= 100);

        proposal.executed = true;
        emit ProposalExecuted(proposalId);
    }

    function getProposal(uint256 proposalId) external view returns (
        uint256 id,
        string memory description,
        uint256 voteCount,
        uint256 endTime,
        bool executed,
        address proposer
    ) {
        require(proposalId > 0 && proposalId <= proposalCount);

        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.id,
            proposal.description,
            proposal.voteCount,
            proposal.endTime,
            proposal.executed,
            proposal.proposer
        );
    }

    function hasVoted(uint256 proposalId, address voter) external view returns (bool) {
        require(proposalId > 0 && proposalId <= proposalCount);
        return proposals[proposalId].hasVoted[voter];
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0));
        owner = newOwner;
    }
}
