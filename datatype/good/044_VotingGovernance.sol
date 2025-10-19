
pragma solidity ^0.8.0;

contract VotingGovernance {
    struct Proposal {
        bytes32 id;
        string description;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        address proposer;
        mapping(address => bool) hasVoted;
        mapping(address => bool) voteChoice;
    }

    struct Voter {
        uint256 votingPower;
        bool isRegistered;
        uint256 registrationTime;
    }

    mapping(bytes32 => Proposal) public proposals;
    mapping(address => Voter) public voters;

    bytes32[] public proposalIds;
    address public admin;
    uint256 public constant VOTING_DURATION = 7 days;
    uint256 public constant MIN_VOTING_POWER = 1;
    uint256 public constant QUORUM_PERCENTAGE = 51;

    event ProposalCreated(bytes32 indexed proposalId, address indexed proposer, string description);
    event VoteCast(bytes32 indexed proposalId, address indexed voter, bool support, uint256 votingPower);
    event ProposalExecuted(bytes32 indexed proposalId, bool passed);
    event VoterRegistered(address indexed voter, uint256 votingPower);
    event VotingPowerUpdated(address indexed voter, uint256 newVotingPower);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
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

    modifier votingActive(bytes32 _proposalId) {
        require(block.timestamp >= proposals[_proposalId].startTime, "Voting not started");
        require(block.timestamp <= proposals[_proposalId].endTime, "Voting period ended");
        _;
    }

    modifier votingEnded(bytes32 _proposalId) {
        require(block.timestamp > proposals[_proposalId].endTime, "Voting still active");
        _;
    }

    constructor() {
        admin = msg.sender;
        voters[admin] = Voter({
            votingPower: 100,
            isRegistered: true,
            registrationTime: block.timestamp
        });
    }

    function registerVoter(address _voter, uint256 _votingPower) external onlyAdmin {
        require(_voter != address(0), "Invalid voter address");
        require(_votingPower >= MIN_VOTING_POWER, "Voting power too low");
        require(!voters[_voter].isRegistered, "Voter already registered");

        voters[_voter] = Voter({
            votingPower: _votingPower,
            isRegistered: true,
            registrationTime: block.timestamp
        });

        emit VoterRegistered(_voter, _votingPower);
    }

    function updateVotingPower(address _voter, uint256 _newVotingPower) external onlyAdmin {
        require(voters[_voter].isRegistered, "Voter not registered");
        require(_newVotingPower >= MIN_VOTING_POWER, "Voting power too low");

        voters[_voter].votingPower = _newVotingPower;
        emit VotingPowerUpdated(_voter, _newVotingPower);
    }

    function createProposal(string calldata _description) external onlyRegisteredVoter returns (bytes32) {
        require(bytes(_description).length > 0, "Description cannot be empty");
        require(bytes(_description).length <= 500, "Description too long");

        bytes32 proposalId = keccak256(abi.encodePacked(_description, msg.sender, block.timestamp));
        require(proposals[proposalId].proposer == address(0), "Proposal already exists");

        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + VOTING_DURATION;

        proposals[proposalId].id = proposalId;
        proposals[proposalId].description = _description;
        proposals[proposalId].votesFor = 0;
        proposals[proposalId].votesAgainst = 0;
        proposals[proposalId].startTime = startTime;
        proposals[proposalId].endTime = endTime;
        proposals[proposalId].executed = false;
        proposals[proposalId].proposer = msg.sender;

        proposalIds.push(proposalId);

        emit ProposalCreated(proposalId, msg.sender, _description);
        return proposalId;
    }

    function vote(bytes32 _proposalId, bool _support) external
        onlyRegisteredVoter
        proposalExists(_proposalId)
        votingActive(_proposalId)
    {
        require(!proposals[_proposalId].hasVoted[msg.sender], "Already voted on this proposal");

        uint256 votingPower = voters[msg.sender].votingPower;

        proposals[_proposalId].hasVoted[msg.sender] = true;
        proposals[_proposalId].voteChoice[msg.sender] = _support;

        if (_support) {
            proposals[_proposalId].votesFor += votingPower;
        } else {
            proposals[_proposalId].votesAgainst += votingPower;
        }

        emit VoteCast(_proposalId, msg.sender, _support, votingPower);
    }

    function executeProposal(bytes32 _proposalId) external
        proposalExists(_proposalId)
        votingEnded(_proposalId)
    {
        require(!proposals[_proposalId].executed, "Proposal already executed");

        uint256 totalVotes = proposals[_proposalId].votesFor + proposals[_proposalId].votesAgainst;
        uint256 totalVotingPower = getTotalVotingPower();

        require(totalVotes * 100 >= totalVotingPower * QUORUM_PERCENTAGE, "Quorum not reached");

        bool passed = proposals[_proposalId].votesFor > proposals[_proposalId].votesAgainst;
        proposals[_proposalId].executed = true;

        emit ProposalExecuted(_proposalId, passed);
    }

    function getProposal(bytes32 _proposalId) external view returns (
        bytes32 id,
        string memory description,
        uint256 votesFor,
        uint256 votesAgainst,
        uint256 startTime,
        uint256 endTime,
        bool executed,
        address proposer
    ) {
        Proposal storage proposal = proposals[_proposalId];
        return (
            proposal.id,
            proposal.description,
            proposal.votesFor,
            proposal.votesAgainst,
            proposal.startTime,
            proposal.endTime,
            proposal.executed,
            proposal.proposer
        );
    }

    function hasVoted(bytes32 _proposalId, address _voter) external view returns (bool) {
        return proposals[_proposalId].hasVoted[_voter];
    }

    function getVoteChoice(bytes32 _proposalId, address _voter) external view returns (bool) {
        require(proposals[_proposalId].hasVoted[_voter], "Voter has not voted");
        return proposals[_proposalId].voteChoice[_voter];
    }

    function getProposalCount() external view returns (uint256) {
        return proposalIds.length;
    }

    function getProposalIdByIndex(uint256 _index) external view returns (bytes32) {
        require(_index < proposalIds.length, "Index out of bounds");
        return proposalIds[_index];
    }

    function getTotalVotingPower() public view returns (uint256) {



        return 1000;
    }

    function isVotingActive(bytes32 _proposalId) external view returns (bool) {
        return block.timestamp >= proposals[_proposalId].startTime &&
               block.timestamp <= proposals[_proposalId].endTime;
    }

    function getVoterInfo(address _voter) external view returns (
        uint256 votingPower,
        bool isRegistered,
        uint256 registrationTime
    ) {
        Voter storage voter = voters[_voter];
        return (voter.votingPower, voter.isRegistered, voter.registrationTime);
    }
}
