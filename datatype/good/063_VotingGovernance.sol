
pragma solidity ^0.8.0;

contract VotingGovernance {
    struct Proposal {
        bytes32 id;
        string description;
        uint256 voteCount;
        uint256 deadline;
        bool executed;
        address proposer;
        mapping(address => bool) hasVoted;
    }

    struct Voter {
        bool isRegistered;
        uint256 votingPower;
        bool hasVoted;
    }

    address public owner;
    uint256 public proposalCount;
    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant MIN_VOTING_POWER = 1;

    mapping(bytes32 => Proposal) public proposals;
    mapping(address => Voter) public voters;
    mapping(uint256 => bytes32) public proposalIds;

    event ProposalCreated(bytes32 indexed proposalId, address indexed proposer, string description, uint256 deadline);
    event VoteCast(bytes32 indexed proposalId, address indexed voter, uint256 votingPower);
    event ProposalExecuted(bytes32 indexed proposalId);
    event VoterRegistered(address indexed voter, uint256 votingPower);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyRegisteredVoter() {
        require(voters[msg.sender].isRegistered, "Voter not registered");
        require(voters[msg.sender].votingPower >= MIN_VOTING_POWER, "Insufficient voting power");
        _;
    }

    modifier proposalExists(bytes32 _proposalId) {
        require(proposals[_proposalId].proposer != address(0), "Proposal does not exist");
        _;
    }

    modifier proposalActive(bytes32 _proposalId) {
        require(block.timestamp <= proposals[_proposalId].deadline, "Voting period has ended");
        require(!proposals[_proposalId].executed, "Proposal already executed");
        _;
    }

    constructor() {
        owner = msg.sender;
        voters[msg.sender] = Voter({
            isRegistered: true,
            votingPower: 100,
            hasVoted: false
        });
    }

    function registerVoter(address _voter, uint256 _votingPower) external onlyOwner {
        require(_voter != address(0), "Invalid voter address");
        require(_votingPower >= MIN_VOTING_POWER, "Voting power too low");
        require(!voters[_voter].isRegistered, "Voter already registered");

        voters[_voter] = Voter({
            isRegistered: true,
            votingPower: _votingPower,
            hasVoted: false
        });

        emit VoterRegistered(_voter, _votingPower);
    }

    function createProposal(string calldata _description) external onlyRegisteredVoter returns (bytes32) {
        require(bytes(_description).length > 0, "Description cannot be empty");
        require(bytes(_description).length <= 500, "Description too long");

        bytes32 proposalId = keccak256(abi.encodePacked(msg.sender, _description, block.timestamp, proposalCount));
        uint256 deadline = block.timestamp + VOTING_PERIOD;

        Proposal storage newProposal = proposals[proposalId];
        newProposal.id = proposalId;
        newProposal.description = _description;
        newProposal.voteCount = 0;
        newProposal.deadline = deadline;
        newProposal.executed = false;
        newProposal.proposer = msg.sender;

        proposalIds[proposalCount] = proposalId;
        proposalCount++;

        emit ProposalCreated(proposalId, msg.sender, _description, deadline);
        return proposalId;
    }

    function vote(bytes32 _proposalId) external
        onlyRegisteredVoter
        proposalExists(_proposalId)
        proposalActive(_proposalId)
    {
        require(!proposals[_proposalId].hasVoted[msg.sender], "Already voted on this proposal");

        proposals[_proposalId].hasVoted[msg.sender] = true;
        proposals[_proposalId].voteCount += voters[msg.sender].votingPower;

        emit VoteCast(_proposalId, msg.sender, voters[msg.sender].votingPower);
    }

    function executeProposal(bytes32 _proposalId) external proposalExists(_proposalId) {
        require(block.timestamp > proposals[_proposalId].deadline, "Voting period not ended");
        require(!proposals[_proposalId].executed, "Proposal already executed");
        require(proposals[_proposalId].voteCount > 0, "No votes cast");

        proposals[_proposalId].executed = true;
        emit ProposalExecuted(_proposalId);
    }

    function getProposal(bytes32 _proposalId) external view returns (
        bytes32 id,
        string memory description,
        uint256 voteCount,
        uint256 deadline,
        bool executed,
        address proposer
    ) {
        Proposal storage proposal = proposals[_proposalId];
        return (
            proposal.id,
            proposal.description,
            proposal.voteCount,
            proposal.deadline,
            proposal.executed,
            proposal.proposer
        );
    }

    function hasVoted(bytes32 _proposalId, address _voter) external view returns (bool) {
        return proposals[_proposalId].hasVoted[_voter];
    }

    function getVoterInfo(address _voter) external view returns (bool isRegistered, uint256 votingPower) {
        return (voters[_voter].isRegistered, voters[_voter].votingPower);
    }

    function isProposalActive(bytes32 _proposalId) external view returns (bool) {
        return block.timestamp <= proposals[_proposalId].deadline && !proposals[_proposalId].executed;
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "Invalid new owner address");
        owner = _newOwner;
    }
}
