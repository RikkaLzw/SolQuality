
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

    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256) public votingPower;
    uint256 public proposalCount;
    uint256 public totalVotingPower;
    address public admin;
    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant MIN_VOTING_POWER = 100;

    error InvalidProposal();
    error NotAuthorized();
    error VotingEnded();
    error AlreadyVoted();

    event ProposalCreated(uint256 proposalId, string description, address proposer, uint256 deadline);
    event VoteCast(address voter, uint256 proposalId, uint256 votingPower);
    event ProposalExecuted(uint256 proposalId);
    event VotingPowerGranted(address voter, uint256 amount);

    modifier onlyAdmin() {
        require(msg.sender == admin);
        _;
    }

    modifier validProposal(uint256 _proposalId) {
        require(_proposalId > 0 && _proposalId <= proposalCount);
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function grantVotingPower(address _voter, uint256 _amount) external onlyAdmin {
        require(_voter != address(0));
        require(_amount > 0);

        votingPower[_voter] += _amount;
        totalVotingPower += _amount;

        emit VotingPowerGranted(_voter, _amount);
    }

    function createProposal(string memory _description) external {
        require(votingPower[msg.sender] >= MIN_VOTING_POWER);
        require(bytes(_description).length > 0);

        proposalCount++;
        uint256 deadline = block.timestamp + VOTING_PERIOD;

        Proposal storage newProposal = proposals[proposalCount];
        newProposal.id = proposalCount;
        newProposal.description = _description;
        newProposal.deadline = deadline;
        newProposal.proposer = msg.sender;

        emit ProposalCreated(proposalCount, _description, msg.sender, deadline);
    }

    function vote(uint256 _proposalId) external validProposal(_proposalId) {
        Proposal storage proposal = proposals[_proposalId];

        require(block.timestamp <= proposal.deadline);
        require(votingPower[msg.sender] > 0);
        require(!proposal.hasVoted[msg.sender]);
        require(!proposal.executed);

        proposal.hasVoted[msg.sender] = true;
        proposal.voteCount += votingPower[msg.sender];

        emit VoteCast(msg.sender, _proposalId, votingPower[msg.sender]);
    }

    function executeProposal(uint256 _proposalId) external validProposal(_proposalId) {
        Proposal storage proposal = proposals[_proposalId];

        require(block.timestamp > proposal.deadline);
        require(!proposal.executed);
        require(proposal.voteCount > totalVotingPower / 2);

        proposal.executed = true;

        emit ProposalExecuted(_proposalId);
    }

    function getProposal(uint256 _proposalId) external view validProposal(_proposalId)
        returns (uint256 id, string memory description, uint256 voteCount, uint256 deadline, bool executed, address proposer) {
        Proposal storage proposal = proposals[_proposalId];
        return (proposal.id, proposal.description, proposal.voteCount, proposal.deadline, proposal.executed, proposal.proposer);
    }

    function hasVoted(uint256 _proposalId, address _voter) external view validProposal(_proposalId) returns (bool) {
        return proposals[_proposalId].hasVoted[_voter];
    }

    function revokeVotingPower(address _voter, uint256 _amount) external onlyAdmin {
        require(votingPower[_voter] >= _amount);

        votingPower[_voter] -= _amount;
        totalVotingPower -= _amount;
    }

    function changeAdmin(address _newAdmin) external onlyAdmin {
        require(_newAdmin != address(0));
        admin = _newAdmin;
    }
}
