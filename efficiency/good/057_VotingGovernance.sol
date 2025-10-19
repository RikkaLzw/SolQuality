
pragma solidity ^0.8.0;

contract VotingGovernance {
    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        mapping(address => bool) hasVoted;
        mapping(address => bool) voteChoice;
    }

    struct VoterInfo {
        uint256 votingPower;
        uint256 delegatedPower;
        address delegate;
        bool isRegistered;
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(address => VoterInfo) public voters;
    mapping(address => address[]) public delegators;

    uint256 public proposalCount;
    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant MIN_VOTING_POWER = 1000;
    uint256 public constant EXECUTION_THRESHOLD = 51;

    address public admin;
    bool public paused;

    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string description);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 votingPower);
    event ProposalExecuted(uint256 indexed proposalId);
    event VoterRegistered(address indexed voter, uint256 votingPower);
    event PowerDelegated(address indexed delegator, address indexed delegate, uint256 power);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }

    modifier notPaused() {
        require(!paused, "Contract paused");
        _;
    }

    modifier validProposal(uint256 proposalId) {
        require(proposalId > 0 && proposalId <= proposalCount, "Invalid proposal");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function registerVoter(address voter, uint256 votingPower) external onlyAdmin {
        require(!voters[voter].isRegistered, "Already registered");
        require(votingPower >= MIN_VOTING_POWER, "Insufficient voting power");

        voters[voter] = VoterInfo({
            votingPower: votingPower,
            delegatedPower: 0,
            delegate: address(0),
            isRegistered: true
        });

        emit VoterRegistered(voter, votingPower);
    }

    function delegateVotingPower(address delegate) external notPaused {
        VoterInfo storage delegator = voters[msg.sender];
        require(delegator.isRegistered, "Not registered");
        require(voters[delegate].isRegistered, "Delegate not registered");
        require(delegate != msg.sender, "Cannot delegate to self");
        require(delegator.delegate == address(0), "Already delegated");


        uint256 delegatorPower = delegator.votingPower;


        delegator.delegate = delegate;


        voters[delegate].delegatedPower += delegatorPower;


        delegators[delegate].push(msg.sender);

        emit PowerDelegated(msg.sender, delegate, delegatorPower);
    }

    function createProposal(string calldata description) external notPaused returns (uint256) {
        VoterInfo memory voterInfo = voters[msg.sender];
        require(voterInfo.isRegistered, "Not registered");
        require(bytes(description).length > 0, "Empty description");

        uint256 totalPower = voterInfo.votingPower + voterInfo.delegatedPower;
        require(totalPower >= MIN_VOTING_POWER, "Insufficient power");

        proposalCount++;
        uint256 proposalId = proposalCount;

        Proposal storage newProposal = proposals[proposalId];
        newProposal.id = proposalId;
        newProposal.proposer = msg.sender;
        newProposal.description = description;
        newProposal.startTime = block.timestamp;
        newProposal.endTime = block.timestamp + VOTING_PERIOD;
        newProposal.executed = false;

        emit ProposalCreated(proposalId, msg.sender, description);
        return proposalId;
    }

    function vote(uint256 proposalId, bool support) external validProposal(proposalId) notPaused {
        Proposal storage proposal = proposals[proposalId];
        VoterInfo memory voterInfo = voters[msg.sender];

        require(voterInfo.isRegistered, "Not registered");
        require(block.timestamp >= proposal.startTime, "Voting not started");
        require(block.timestamp <= proposal.endTime, "Voting ended");
        require(!proposal.hasVoted[msg.sender], "Already voted");
        require(voterInfo.delegate == address(0), "Power delegated");


        uint256 totalVotingPower = voterInfo.votingPower + voterInfo.delegatedPower;


        proposal.hasVoted[msg.sender] = true;
        proposal.voteChoice[msg.sender] = support;


        if (support) {
            proposal.forVotes += totalVotingPower;
        } else {
            proposal.againstVotes += totalVotingPower;
        }

        emit VoteCast(proposalId, msg.sender, support, totalVotingPower);
    }

    function executeProposal(uint256 proposalId) external validProposal(proposalId) notPaused {
        Proposal storage proposal = proposals[proposalId];

        require(block.timestamp > proposal.endTime, "Voting still active");
        require(!proposal.executed, "Already executed");


        uint256 forVotes = proposal.forVotes;
        uint256 againstVotes = proposal.againstVotes;
        uint256 totalVotes = forVotes + againstVotes;

        require(totalVotes > 0, "No votes cast");


        uint256 approvalPercentage = (forVotes * 100) / totalVotes;
        require(approvalPercentage >= EXECUTION_THRESHOLD, "Proposal rejected");

        proposal.executed = true;

        emit ProposalExecuted(proposalId);
    }

    function getProposalInfo(uint256 proposalId) external view validProposal(proposalId)
        returns (
            address proposer,
            string memory description,
            uint256 forVotes,
            uint256 againstVotes,
            uint256 startTime,
            uint256 endTime,
            bool executed
        )
    {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.proposer,
            proposal.description,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.startTime,
            proposal.endTime,
            proposal.executed
        );
    }

    function getVoterTotalPower(address voter) external view returns (uint256) {
        VoterInfo memory voterInfo = voters[voter];
        return voterInfo.votingPower + voterInfo.delegatedPower;
    }

    function hasVoted(uint256 proposalId, address voter) external view validProposal(proposalId) returns (bool) {
        return proposals[proposalId].hasVoted[voter];
    }

    function getVoteChoice(uint256 proposalId, address voter) external view validProposal(proposalId) returns (bool) {
        require(proposals[proposalId].hasVoted[voter], "Has not voted");
        return proposals[proposalId].voteChoice[voter];
    }

    function getDelegatorCount(address delegate) external view returns (uint256) {
        return delegators[delegate].length;
    }

    function pauseContract() external onlyAdmin {
        paused = true;
    }

    function unpauseContract() external onlyAdmin {
        paused = false;
    }

    function transferAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "Invalid address");
        admin = newAdmin;
    }
}
