
pragma solidity ^0.8.19;


contract VotingGovernanceContract {

    enum ProposalStatus {
        Pending,
        Active,
        Succeeded,
        Failed,
        Executed
    }


    struct Proposal {
        uint256 proposalId;
        address proposer;
        string title;
        string description;
        uint256 startTime;
        uint256 endTime;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        ProposalStatus status;
        mapping(address => bool) hasVoted;
        mapping(address => uint8) voteChoice;
    }


    struct Voter {
        bool isRegistered;
        uint256 votingPower;
        uint256 registrationTime;
    }


    address public contractOwner;
    uint256 public totalProposals;
    uint256 public minimumVotingPeriod;
    uint256 public maximumVotingPeriod;
    uint256 public proposalThreshold;
    uint256 public quorumPercentage;
    uint256 public totalVotingPower;


    mapping(uint256 => Proposal) public proposals;
    mapping(address => Voter) public voters;
    mapping(address => bool) public authorizedProposers;


    event VoterRegistered(address indexed voter, uint256 votingPower);
    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string title);
    event VoteCasted(uint256 indexed proposalId, address indexed voter, uint8 choice, uint256 votingPower);
    event ProposalStatusChanged(uint256 indexed proposalId, ProposalStatus newStatus);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposerAuthorized(address indexed proposer);
    event ProposerRevoked(address indexed proposer);


    modifier onlyOwner() {
        require(msg.sender == contractOwner, "Only contract owner can call this function");
        _;
    }

    modifier onlyRegisteredVoter() {
        require(voters[msg.sender].isRegistered, "Caller must be a registered voter");
        _;
    }

    modifier onlyAuthorizedProposer() {
        require(
            authorizedProposers[msg.sender] || msg.sender == contractOwner,
            "Caller must be an authorized proposer"
        );
        _;
    }

    modifier validProposal(uint256 _proposalId) {
        require(_proposalId > 0 && _proposalId <= totalProposals, "Invalid proposal ID");
        _;
    }


    constructor(
        uint256 _minimumVotingPeriod,
        uint256 _maximumVotingPeriod,
        uint256 _proposalThreshold,
        uint256 _quorumPercentage
    ) {
        require(_minimumVotingPeriod > 0, "Minimum voting period must be greater than 0");
        require(_maximumVotingPeriod > _minimumVotingPeriod, "Maximum voting period must be greater than minimum");
        require(_quorumPercentage > 0 && _quorumPercentage <= 100, "Quorum percentage must be between 1 and 100");

        contractOwner = msg.sender;
        minimumVotingPeriod = _minimumVotingPeriod;
        maximumVotingPeriod = _maximumVotingPeriod;
        proposalThreshold = _proposalThreshold;
        quorumPercentage = _quorumPercentage;


        voters[msg.sender] = Voter({
            isRegistered: true,
            votingPower: 1000,
            registrationTime: block.timestamp
        });
        totalVotingPower = 1000;


        authorizedProposers[msg.sender] = true;
    }


    function registerVoter(address _voter, uint256 _votingPower) external onlyOwner {
        require(_voter != address(0), "Invalid voter address");
        require(_votingPower > 0, "Voting power must be greater than 0");
        require(!voters[_voter].isRegistered, "Voter already registered");

        voters[_voter] = Voter({
            isRegistered: true,
            votingPower: _votingPower,
            registrationTime: block.timestamp
        });

        totalVotingPower += _votingPower;
        emit VoterRegistered(_voter, _votingPower);
    }


    function authorizeProposer(address _proposer) external onlyOwner {
        require(_proposer != address(0), "Invalid proposer address");
        require(!authorizedProposers[_proposer], "Proposer already authorized");

        authorizedProposers[_proposer] = true;
        emit ProposerAuthorized(_proposer);
    }


    function revokeProposer(address _proposer) external onlyOwner {
        require(_proposer != contractOwner, "Cannot revoke owner's authorization");
        require(authorizedProposers[_proposer], "Proposer not authorized");

        authorizedProposers[_proposer] = false;
        emit ProposerRevoked(_proposer);
    }


    function createProposal(
        string memory _title,
        string memory _description,
        uint256 _votingPeriod
    ) external onlyAuthorizedProposer returns (uint256) {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_description).length > 0, "Description cannot be empty");
        require(
            _votingPeriod >= minimumVotingPeriod && _votingPeriod <= maximumVotingPeriod,
            "Invalid voting period"
        );
        require(
            voters[msg.sender].votingPower >= proposalThreshold,
            "Insufficient voting power to create proposal"
        );

        totalProposals++;
        uint256 proposalId = totalProposals;

        Proposal storage newProposal = proposals[proposalId];
        newProposal.proposalId = proposalId;
        newProposal.proposer = msg.sender;
        newProposal.title = _title;
        newProposal.description = _description;
        newProposal.startTime = block.timestamp;
        newProposal.endTime = block.timestamp + _votingPeriod;
        newProposal.status = ProposalStatus.Active;

        emit ProposalCreated(proposalId, msg.sender, _title);
        emit ProposalStatusChanged(proposalId, ProposalStatus.Active);

        return proposalId;
    }


    function vote(uint256 _proposalId, uint8 _choice) external onlyRegisteredVoter validProposal(_proposalId) {
        require(_choice <= 2, "Invalid vote choice");

        Proposal storage proposal = proposals[_proposalId];
        require(proposal.status == ProposalStatus.Active, "Proposal is not active");
        require(block.timestamp <= proposal.endTime, "Voting period has ended");
        require(!proposal.hasVoted[msg.sender], "Already voted on this proposal");

        uint256 voterPower = voters[msg.sender].votingPower;
        proposal.hasVoted[msg.sender] = true;
        proposal.voteChoice[msg.sender] = _choice;

        if (_choice == 0) {
            proposal.againstVotes += voterPower;
        } else if (_choice == 1) {
            proposal.forVotes += voterPower;
        } else {
            proposal.abstainVotes += voterPower;
        }

        emit VoteCasted(_proposalId, msg.sender, _choice, voterPower);
    }


    function finalizeProposal(uint256 _proposalId) external validProposal(_proposalId) {
        Proposal storage proposal = proposals[_proposalId];
        require(proposal.status == ProposalStatus.Active, "Proposal is not active");
        require(block.timestamp > proposal.endTime, "Voting period has not ended");

        uint256 totalVotes = proposal.forVotes + proposal.againstVotes + proposal.abstainVotes;
        uint256 requiredQuorum = (totalVotingPower * quorumPercentage) / 100;

        if (totalVotes >= requiredQuorum && proposal.forVotes > proposal.againstVotes) {
            proposal.status = ProposalStatus.Succeeded;
        } else {
            proposal.status = ProposalStatus.Failed;
        }

        emit ProposalStatusChanged(_proposalId, proposal.status);
    }


    function executeProposal(uint256 _proposalId) external validProposal(_proposalId) {
        Proposal storage proposal = proposals[_proposalId];
        require(proposal.status == ProposalStatus.Succeeded, "Proposal has not succeeded");
        require(
            msg.sender == proposal.proposer || msg.sender == contractOwner,
            "Only proposer or owner can execute"
        );

        proposal.status = ProposalStatus.Executed;
        emit ProposalStatusChanged(_proposalId, ProposalStatus.Executed);
        emit ProposalExecuted(_proposalId);
    }


    function getProposalDetails(uint256 _proposalId) external view validProposal(_proposalId) returns (
        uint256 proposalId,
        address proposer,
        string memory title,
        string memory description,
        uint256 startTime,
        uint256 endTime,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 abstainVotes,
        ProposalStatus status
    ) {
        Proposal storage proposal = proposals[_proposalId];
        return (
            proposal.proposalId,
            proposal.proposer,
            proposal.title,
            proposal.description,
            proposal.startTime,
            proposal.endTime,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.abstainVotes,
            proposal.status
        );
    }


    function hasVotedOnProposal(uint256 _proposalId, address _voter) external view validProposal(_proposalId) returns (bool) {
        return proposals[_proposalId].hasVoted[_voter];
    }


    function getVoteChoice(uint256 _proposalId, address _voter) external view validProposal(_proposalId) returns (uint8) {
        require(proposals[_proposalId].hasVoted[_voter], "Voter has not voted on this proposal");
        return proposals[_proposalId].voteChoice[_voter];
    }


    function getVoterInfo(address _voter) external view returns (
        bool isRegistered,
        uint256 votingPower,
        uint256 registrationTime
    ) {
        Voter memory voter = voters[_voter];
        return (voter.isRegistered, voter.votingPower, voter.registrationTime);
    }


    function updateGovernanceParameters(
        uint256 _minimumVotingPeriod,
        uint256 _maximumVotingPeriod,
        uint256 _proposalThreshold,
        uint256 _quorumPercentage
    ) external onlyOwner {
        require(_minimumVotingPeriod > 0, "Minimum voting period must be greater than 0");
        require(_maximumVotingPeriod > _minimumVotingPeriod, "Maximum voting period must be greater than minimum");
        require(_quorumPercentage > 0 && _quorumPercentage <= 100, "Quorum percentage must be between 1 and 100");

        minimumVotingPeriod = _minimumVotingPeriod;
        maximumVotingPeriod = _maximumVotingPeriod;
        proposalThreshold = _proposalThreshold;
        quorumPercentage = _quorumPercentage;
    }


    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "Invalid new owner address");
        require(_newOwner != contractOwner, "New owner cannot be the same as current owner");

        contractOwner = _newOwner;
        authorizedProposers[_newOwner] = true;
    }
}
