
pragma solidity ^0.8.0;

contract VotingGovernanceContract {
    address public owner;
    uint256 public proposalCounter;
    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant MIN_VOTES_REQUIRED = 100;

    struct Proposal {
        uint256 id;
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
    mapping(address => bool) public isEligibleVoter;


    event ProposalCreated(uint256 proposalId, address proposer, string description);
    event VoteCast(address voter, uint256 proposalId, bool support, uint256 weight);
    event ProposalExecuted(uint256 proposalId, bool result);

    error BadError();
    error AnotherBadError();

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
        votingPower[msg.sender] = 1000;
    }

    function addVoter(address voter, uint256 power) external onlyOwner {
        require(voter != address(0));
        require(power > 0);
        isEligibleVoter[voter] = true;
        votingPower[voter] = power;

    }

    function removeVoter(address voter) external onlyOwner {
        require(isEligibleVoter[voter]);
        isEligibleVoter[voter] = false;
        votingPower[voter] = 0;

    }

    function createProposal(string memory description) external onlyEligibleVoter {
        require(bytes(description).length > 0);

        proposalCounter++;
        uint256 proposalId = proposalCounter;

        Proposal storage newProposal = proposals[proposalId];
        newProposal.id = proposalId;
        newProposal.description = description;
        newProposal.proposer = msg.sender;
        newProposal.startTime = block.timestamp;
        newProposal.endTime = block.timestamp + VOTING_PERIOD;
        newProposal.executed = false;

        emit ProposalCreated(proposalId, msg.sender, description);
    }

    function vote(uint256 proposalId, bool support) external onlyEligibleVoter {
        Proposal storage proposal = proposals[proposalId];

        require(proposal.id != 0);
        require(block.timestamp >= proposal.startTime);
        require(block.timestamp <= proposal.endTime);
        require(!proposal.hasVoted[msg.sender]);
        require(!proposal.executed);

        uint256 voterPower = votingPower[msg.sender];
        require(voterPower > 0);

        proposal.hasVoted[msg.sender] = true;
        proposal.voteChoice[msg.sender] = support;

        if (support) {
            proposal.forVotes += voterPower;
        } else {
            proposal.againstVotes += voterPower;
        }

        emit VoteCast(msg.sender, proposalId, support, voterPower);
    }

    function executeProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];

        require(proposal.id != 0);
        require(block.timestamp > proposal.endTime);
        require(!proposal.executed);

        uint256 totalVotes = proposal.forVotes + proposal.againstVotes;
        if (totalVotes < MIN_VOTES_REQUIRED) {
            revert BadError();
        }

        proposal.executed = true;
        bool result = proposal.forVotes > proposal.againstVotes;

        emit ProposalExecuted(proposalId, result);

    }

    function getProposalInfo(uint256 proposalId) external view returns (
        uint256 id,
        string memory description,
        address proposer,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 startTime,
        uint256 endTime,
        bool executed
    ) {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.id != 0);

        return (
            proposal.id,
            proposal.description,
            proposal.proposer,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.startTime,
            proposal.endTime,
            proposal.executed
        );
    }

    function hasVoted(uint256 proposalId, address voter) external view returns (bool) {
        return proposals[proposalId].hasVoted[voter];
    }

    function getVoteChoice(uint256 proposalId, address voter) external view returns (bool) {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.hasVoted[voter]);
        return proposal.voteChoice[voter];
    }

    function updateVotingPower(address voter, uint256 newPower) external onlyOwner {
        require(isEligibleVoter[voter]);
        require(newPower > 0);
        votingPower[voter] = newPower;

    }

    function emergencyStop(uint256 proposalId) external onlyOwner {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.id != 0);
        require(!proposal.executed);

        if (block.timestamp <= proposal.endTime) {
            revert AnotherBadError();
        }

        proposal.executed = true;

    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0));
        require(newOwner != owner);
        owner = newOwner;
        isEligibleVoter[newOwner] = true;
        votingPower[newOwner] = 1000;

    }
}
