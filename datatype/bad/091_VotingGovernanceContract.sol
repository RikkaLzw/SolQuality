
pragma solidity ^0.8.0;

contract VotingGovernanceContract {

    uint256 public constant VOTING_PERIOD = 7;
    uint256 public constant MIN_QUORUM = 10;
    uint256 public proposalCount;


    string public governanceToken = "GOV";
    string public contractVersion = "1.0";

    struct Proposal {
        uint256 id;
        string title;
        bytes description;
        address proposer;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 startTime;
        uint256 endTime;
        uint256 executed;
        uint256 cancelled;
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256) public votingPower;
    mapping(uint256 => mapping(address => uint256)) public hasVoted;

    address public owner;
    uint256 public totalVotingPower;

    event ProposalCreated(uint256 indexed proposalId, string title, address proposer);
    event VoteCast(uint256 indexed proposalId, address voter, uint256 support, uint256 votes);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCancelled(uint256 indexed proposalId);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier validProposal(uint256 proposalId) {
        require(proposalId < proposalCount, "Invalid proposal");
        _;
    }

    constructor() {
        owner = msg.sender;
        proposalCount = uint256(0);
        totalVotingPower = uint256(0);
    }

    function setVotingPower(address voter, uint256 power) external onlyOwner {
        uint256 oldPower = votingPower[voter];
        votingPower[voter] = power;
        totalVotingPower = totalVotingPower - oldPower + power;
    }

    function createProposal(
        string memory title,
        bytes memory description
    ) external returns (uint256) {
        require(votingPower[msg.sender] > 0, "No voting power");

        uint256 proposalId = proposalCount;
        proposalCount = uint256(proposalCount + 1);

        proposals[proposalId] = Proposal({
            id: proposalId,
            title: title,
            description: description,
            proposer: msg.sender,
            forVotes: uint256(0),
            againstVotes: uint256(0),
            startTime: block.timestamp,
            endTime: block.timestamp + (VOTING_PERIOD * 1 days),
            executed: uint256(0),
            cancelled: uint256(0)
        });

        emit ProposalCreated(proposalId, title, msg.sender);
        return proposalId;
    }

    function vote(uint256 proposalId, uint256 support) external validProposal(proposalId) {
        require(votingPower[msg.sender] > 0, "No voting power");
        require(hasVoted[proposalId][msg.sender] == uint256(0), "Already voted");
        require(block.timestamp <= proposals[proposalId].endTime, "Voting ended");
        require(proposals[proposalId].cancelled == uint256(0), "Proposal cancelled");

        hasVoted[proposalId][msg.sender] = uint256(1);
        uint256 votes = votingPower[msg.sender];

        if (support == uint256(1)) {
            proposals[proposalId].forVotes += votes;
        } else {
            proposals[proposalId].againstVotes += votes;
        }

        emit VoteCast(proposalId, msg.sender, support, votes);
    }

    function executeProposal(uint256 proposalId) external validProposal(proposalId) {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp > proposal.endTime, "Voting not ended");
        require(proposal.executed == uint256(0), "Already executed");
        require(proposal.cancelled == uint256(0), "Proposal cancelled");
        require(proposal.forVotes > proposal.againstVotes, "Proposal rejected");

        uint256 totalVotes = proposal.forVotes + proposal.againstVotes;
        uint256 quorumRequired = (totalVotingPower * MIN_QUORUM) / uint256(100);
        require(totalVotes >= quorumRequired, "Quorum not met");

        proposal.executed = uint256(1);

        emit ProposalExecuted(proposalId);
    }

    function cancelProposal(uint256 proposalId) external validProposal(proposalId) {
        Proposal storage proposal = proposals[proposalId];
        require(
            msg.sender == proposal.proposer || msg.sender == owner,
            "Not authorized"
        );
        require(proposal.executed == uint256(0), "Already executed");
        require(proposal.cancelled == uint256(0), "Already cancelled");

        proposal.cancelled = uint256(1);

        emit ProposalCancelled(proposalId);
    }

    function getProposal(uint256 proposalId) external view validProposal(proposalId)
        returns (
            uint256 id,
            string memory title,
            bytes memory description,
            address proposer,
            uint256 forVotes,
            uint256 againstVotes,
            uint256 startTime,
            uint256 endTime,
            uint256 executed,
            uint256 cancelled
        )
    {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.id,
            proposal.title,
            proposal.description,
            proposal.proposer,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.startTime,
            proposal.endTime,
            proposal.executed,
            proposal.cancelled
        );
    }

    function getVotingStatus(uint256 proposalId, address voter)
        external
        view
        validProposal(proposalId)
        returns (uint256)
    {
        return hasVoted[proposalId][voter];
    }

    function isProposalActive(uint256 proposalId) external view validProposal(proposalId) returns (uint256) {
        Proposal storage proposal = proposals[proposalId];
        if (proposal.cancelled == uint256(1) || proposal.executed == uint256(1)) {
            return uint256(0);
        }
        if (block.timestamp > proposal.endTime) {
            return uint256(0);
        }
        return uint256(1);
    }
}
