
pragma solidity ^0.8.0;

contract OptimizedVotingGovernance {
    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        mapping(address => bool) hasVoted;
        mapping(address => bool) voteChoice;
    }

    struct ProposalInfo {
        uint256 id;
        address proposer;
        string description;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 startTime;
        uint256 endTime;
        bool executed;
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256) public votingPower;
    mapping(address => bool) public isEligibleVoter;

    uint256 public proposalCount;
    uint256 public constant VOTING_DURATION = 7 days;
    uint256 public constant MIN_VOTING_POWER = 1000;
    uint256 public quorum = 5000;

    address public admin;
    bool public votingEnabled = true;

    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string description);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 votingPower);
    event ProposalExecuted(uint256 indexed proposalId, bool success);
    event VotingPowerUpdated(address indexed voter, uint256 newPower);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }

    modifier onlyEligibleVoter() {
        require(isEligibleVoter[msg.sender], "Not eligible to vote");
        require(votingPower[msg.sender] >= MIN_VOTING_POWER, "Insufficient voting power");
        _;
    }

    modifier votingIsEnabled() {
        require(votingEnabled, "Voting is currently disabled");
        _;
    }

    constructor() {
        admin = msg.sender;
        isEligibleVoter[msg.sender] = true;
        votingPower[msg.sender] = 10000;
    }

    function createProposal(string calldata _description) external onlyEligibleVoter votingIsEnabled {
        require(bytes(_description).length > 0, "Description cannot be empty");
        require(bytes(_description).length <= 500, "Description too long");

        uint256 proposalId = ++proposalCount;
        Proposal storage newProposal = proposals[proposalId];


        uint256 currentTime = block.timestamp;

        newProposal.id = proposalId;
        newProposal.proposer = msg.sender;
        newProposal.description = _description;
        newProposal.startTime = currentTime;
        newProposal.endTime = currentTime + VOTING_DURATION;
        newProposal.executed = false;

        emit ProposalCreated(proposalId, msg.sender, _description);
    }

    function vote(uint256 _proposalId, bool _support) external onlyEligibleVoter votingIsEnabled {
        Proposal storage proposal = proposals[_proposalId];
        require(proposal.id != 0, "Proposal does not exist");
        require(!proposal.hasVoted[msg.sender], "Already voted");


        uint256 currentTime = block.timestamp;
        uint256 voterPower = votingPower[msg.sender];

        require(currentTime >= proposal.startTime, "Voting not started");
        require(currentTime <= proposal.endTime, "Voting period ended");
        require(!proposal.executed, "Proposal already executed");

        proposal.hasVoted[msg.sender] = true;
        proposal.voteChoice[msg.sender] = _support;

        if (_support) {
            proposal.votesFor += voterPower;
        } else {
            proposal.votesAgainst += voterPower;
        }

        emit VoteCast(_proposalId, msg.sender, _support, voterPower);
    }

    function executeProposal(uint256 _proposalId) external {
        Proposal storage proposal = proposals[_proposalId];
        require(proposal.id != 0, "Proposal does not exist");
        require(!proposal.executed, "Proposal already executed");
        require(block.timestamp > proposal.endTime, "Voting period not ended");


        uint256 votesFor = proposal.votesFor;
        uint256 votesAgainst = proposal.votesAgainst;
        uint256 totalVotes = votesFor + votesAgainst;

        require(totalVotes >= quorum, "Quorum not reached");
        require(votesFor > votesAgainst, "Proposal rejected");

        proposal.executed = true;

        emit ProposalExecuted(_proposalId, true);
    }

    function getProposalInfo(uint256 _proposalId) external view returns (ProposalInfo memory) {
        Proposal storage proposal = proposals[_proposalId];
        require(proposal.id != 0, "Proposal does not exist");

        return ProposalInfo({
            id: proposal.id,
            proposer: proposal.proposer,
            description: proposal.description,
            votesFor: proposal.votesFor,
            votesAgainst: proposal.votesAgainst,
            startTime: proposal.startTime,
            endTime: proposal.endTime,
            executed: proposal.executed
        });
    }

    function hasVoted(uint256 _proposalId, address _voter) external view returns (bool) {
        return proposals[_proposalId].hasVoted[_voter];
    }

    function getVoteChoice(uint256 _proposalId, address _voter) external view returns (bool) {
        require(proposals[_proposalId].hasVoted[_voter], "Voter has not voted");
        return proposals[_proposalId].voteChoice[_voter];
    }

    function setVotingPower(address _voter, uint256 _power) external onlyAdmin {
        require(_voter != address(0), "Invalid voter address");
        votingPower[_voter] = _power;
        emit VotingPowerUpdated(_voter, _power);
    }

    function addEligibleVoter(address _voter) external onlyAdmin {
        require(_voter != address(0), "Invalid voter address");
        isEligibleVoter[_voter] = true;
    }

    function removeEligibleVoter(address _voter) external onlyAdmin {
        require(_voter != address(0), "Invalid voter address");
        require(_voter != admin, "Cannot remove admin");
        isEligibleVoter[_voter] = false;
    }

    function setQuorum(uint256 _newQuorum) external onlyAdmin {
        require(_newQuorum > 0, "Quorum must be greater than 0");
        quorum = _newQuorum;
    }

    function toggleVoting() external onlyAdmin {
        votingEnabled = !votingEnabled;
    }

    function transferAdmin(address _newAdmin) external onlyAdmin {
        require(_newAdmin != address(0), "Invalid admin address");
        admin = _newAdmin;
        isEligibleVoter[_newAdmin] = true;
    }

    function getActiveProposals() external view returns (uint256[] memory) {
        uint256 currentTime = block.timestamp;
        uint256 activeCount = 0;


        for (uint256 i = 1; i <= proposalCount; i++) {
            Proposal storage proposal = proposals[i];
            if (!proposal.executed &&
                currentTime >= proposal.startTime &&
                currentTime <= proposal.endTime) {
                activeCount++;
            }
        }


        uint256[] memory activeProposals = new uint256[](activeCount);
        uint256 index = 0;

        for (uint256 i = 1; i <= proposalCount; i++) {
            Proposal storage proposal = proposals[i];
            if (!proposal.executed &&
                currentTime >= proposal.startTime &&
                currentTime <= proposal.endTime) {
                activeProposals[index] = i;
                index++;
            }
        }

        return activeProposals;
    }
}
