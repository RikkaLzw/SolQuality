
pragma solidity ^0.8.0;

contract VotingGovernanceContract {

    uint256 public proposalCount;
    uint256 public constant VOTING_PERIOD = 7;
    uint256 public constant MIN_VOTES_REQUIRED = 100;


    mapping(uint256 => string) public proposalIds;
    mapping(address => string) public voterIds;


    mapping(uint256 => bytes) public proposalHashes;
    mapping(address => bytes) public voterSignatures;

    struct Proposal {
        string title;
        string description;
        address proposer;

        uint256 startTime;
        uint256 endTime;
        uint256 yesVotes;
        uint256 noVotes;

        uint256 isActive;
        uint256 isExecuted;
    }

    struct Voter {

        uint256 isRegistered;
        uint256 hasVoted;
        uint256 votingPower;
        uint256 lastVoteTime;
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(address => Voter) public voters;
    mapping(uint256 => mapping(address => uint256)) public votes;

    address public admin;

    uint256 public totalRegisteredVoters;

    event ProposalCreated(uint256 indexed proposalId, string proposalIdStr, address proposer);
    event VoteCast(uint256 indexed proposalId, address indexed voter, uint256 vote);
    event ProposalExecuted(uint256 indexed proposalId);
    event VoterRegistered(address indexed voter, string voterIdStr);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    modifier onlyRegisteredVoter() {
        require(voters[msg.sender].isRegistered == 1, "Voter not registered");
        _;
    }

    constructor() {
        admin = msg.sender;
        proposalCount = 0;
        totalRegisteredVoters = 0;
    }

    function registerVoter(address _voter, string memory _voterIdStr, bytes memory _signature) external onlyAdmin {
        require(voters[_voter].isRegistered == 0, "Voter already registered");

        voters[_voter] = Voter({
            isRegistered: 1,
            hasVoted: 0,
            votingPower: 1,
            lastVoteTime: 0
        });


        voterIds[_voter] = _voterIdStr;

        voterSignatures[_voter] = _signature;


        totalRegisteredVoters = uint256(totalRegisteredVoters + 1);

        emit VoterRegistered(_voter, _voterIdStr);
    }

    function createProposal(
        string memory _title,
        string memory _description,
        string memory _proposalIdStr,
        bytes memory _proposalHash
    ) external onlyRegisteredVoter returns (uint256) {

        uint256 newProposalId = uint256(proposalCount);

        proposals[newProposalId] = Proposal({
            title: _title,
            description: _description,
            proposer: msg.sender,
            startTime: block.timestamp,

            endTime: uint256(block.timestamp + (VOTING_PERIOD * 1 days)),
            yesVotes: 0,
            noVotes: 0,
            isActive: 1,
            isExecuted: 0
        });


        proposalIds[newProposalId] = _proposalIdStr;

        proposalHashes[newProposalId] = _proposalHash;

        proposalCount++;

        emit ProposalCreated(newProposalId, _proposalIdStr, msg.sender);
        return newProposalId;
    }

    function vote(uint256 _proposalId, uint256 _vote) external onlyRegisteredVoter {
        require(_proposalId < proposalCount, "Proposal does not exist");
        require(proposals[_proposalId].isActive == 1, "Proposal not active");
        require(block.timestamp <= proposals[_proposalId].endTime, "Voting period ended");
        require(votes[_proposalId][msg.sender] == 0, "Already voted");
        require(_vote == 1 || _vote == 2, "Invalid vote");

        votes[_proposalId][msg.sender] = _vote;
        voters[msg.sender].hasVoted = 1;
        voters[msg.sender].lastVoteTime = block.timestamp;


        uint256 votingPower = uint256(voters[msg.sender].votingPower);

        if (_vote == 1) {
            proposals[_proposalId].yesVotes += votingPower;
        } else {
            proposals[_proposalId].noVotes += votingPower;
        }

        emit VoteCast(_proposalId, msg.sender, _vote);
    }

    function executeProposal(uint256 _proposalId) external onlyAdmin {
        require(_proposalId < proposalCount, "Proposal does not exist");
        require(proposals[_proposalId].isActive == 1, "Proposal not active");
        require(block.timestamp > proposals[_proposalId].endTime, "Voting period not ended");
        require(proposals[_proposalId].isExecuted == 0, "Proposal already executed");


        uint256 totalVotes = uint256(proposals[_proposalId].yesVotes + proposals[_proposalId].noVotes);
        require(totalVotes >= MIN_VOTES_REQUIRED, "Not enough votes");

        if (proposals[_proposalId].yesVotes > proposals[_proposalId].noVotes) {
            proposals[_proposalId].isExecuted = 1;
        }

        proposals[_proposalId].isActive = 0;

        emit ProposalExecuted(_proposalId);
    }

    function getProposalInfo(uint256 _proposalId) external view returns (
        string memory title,
        string memory description,
        address proposer,
        uint256 startTime,
        uint256 endTime,
        uint256 yesVotes,
        uint256 noVotes,
        uint256 isActive,
        uint256 isExecuted
    ) {
        require(_proposalId < proposalCount, "Proposal does not exist");

        Proposal memory proposal = proposals[_proposalId];
        return (
            proposal.title,
            proposal.description,
            proposal.proposer,
            proposal.startTime,
            proposal.endTime,
            proposal.yesVotes,
            proposal.noVotes,
            proposal.isActive,
            proposal.isExecuted
        );
    }

    function getVoterInfo(address _voter) external view returns (
        uint256 isRegistered,
        uint256 hasVoted,
        uint256 votingPower,
        uint256 lastVoteTime,
        string memory voterIdStr
    ) {
        Voter memory voter = voters[_voter];
        return (
            voter.isRegistered,
            voter.hasVoted,
            voter.votingPower,
            voter.lastVoteTime,
            voterIds[_voter]
        );
    }

    function isProposalPassed(uint256 _proposalId) external view returns (uint256) {
        require(_proposalId < proposalCount, "Proposal does not exist");

        if (proposals[_proposalId].yesVotes > proposals[_proposalId].noVotes) {
            return 1;
        }
        return 0;
    }

    function updateVotingPower(address _voter, uint256 _newPower) external onlyAdmin {
        require(voters[_voter].isRegistered == 1, "Voter not registered");

        voters[_voter].votingPower = uint256(_newPower);
    }

    function getProposalHash(uint256 _proposalId) external view returns (bytes memory) {
        require(_proposalId < proposalCount, "Proposal does not exist");
        return proposalHashes[_proposalId];
    }

    function getVoterSignature(address _voter) external view returns (bytes memory) {
        require(voters[_voter].isRegistered == 1, "Voter not registered");
        return voterSignatures[_voter];
    }
}
