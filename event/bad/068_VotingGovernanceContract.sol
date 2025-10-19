
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

    address public owner;
    uint256 public proposalCount;
    uint256 public votingDuration = 7 days;
    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256) public votingPower;

    error InvalidProposal();
    error NotAuthorized();
    error VotingEnded();

    event ProposalCreated(uint256 proposalId, string description);
    event VoteCast(address voter, uint256 proposalId);
    event ProposalExecuted(uint256 proposalId);

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier validProposal(uint256 _proposalId) {
        require(_proposalId > 0 && _proposalId <= proposalCount);
        _;
    }

    constructor() {
        owner = msg.sender;
        votingPower[msg.sender] = 100;
    }

    function createProposal(string memory _description) external {
        require(bytes(_description).length > 0);
        require(votingPower[msg.sender] > 0);

        proposalCount++;
        Proposal storage newProposal = proposals[proposalCount];
        newProposal.id = proposalCount;
        newProposal.description = _description;
        newProposal.endTime = block.timestamp + votingDuration;
        newProposal.proposer = msg.sender;

        emit ProposalCreated(proposalCount, _description);
    }

    function vote(uint256 _proposalId) external validProposal(_proposalId) {
        Proposal storage proposal = proposals[_proposalId];

        require(block.timestamp < proposal.endTime);
        require(!proposal.hasVoted[msg.sender]);
        require(votingPower[msg.sender] > 0);

        proposal.hasVoted[msg.sender] = true;
        proposal.voteCount += votingPower[msg.sender];

        emit VoteCast(msg.sender, _proposalId);
    }

    function executeProposal(uint256 _proposalId) external validProposal(_proposalId) {
        Proposal storage proposal = proposals[_proposalId];

        require(block.timestamp >= proposal.endTime);
        require(!proposal.executed);
        require(proposal.voteCount > 50);

        proposal.executed = true;

        emit ProposalExecuted(_proposalId);
    }

    function grantVotingPower(address _voter, uint256 _power) external onlyOwner {
        require(_voter != address(0));
        require(_power > 0);

        votingPower[_voter] = _power;
    }

    function revokeVotingPower(address _voter) external onlyOwner {
        require(_voter != address(0));

        votingPower[_voter] = 0;
    }

    function setVotingDuration(uint256 _duration) external onlyOwner {
        require(_duration > 0);

        votingDuration = _duration;
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0));

        owner = _newOwner;
    }

    function getProposal(uint256 _proposalId) external view validProposal(_proposalId)
        returns (uint256, string memory, uint256, uint256, bool, address) {
        Proposal storage proposal = proposals[_proposalId];
        return (
            proposal.id,
            proposal.description,
            proposal.voteCount,
            proposal.endTime,
            proposal.executed,
            proposal.proposer
        );
    }

    function hasVoted(uint256 _proposalId, address _voter) external view validProposal(_proposalId)
        returns (bool) {
        return proposals[_proposalId].hasVoted[_voter];
    }

    function getVotingPower(address _voter) external view returns (uint256) {
        return votingPower[_voter];
    }

    function isProposalActive(uint256 _proposalId) external view validProposal(_proposalId)
        returns (bool) {
        return block.timestamp < proposals[_proposalId].endTime && !proposals[_proposalId].executed;
    }
}
