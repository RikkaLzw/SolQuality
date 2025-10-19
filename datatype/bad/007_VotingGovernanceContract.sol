
pragma solidity ^0.8.0;

contract VotingGovernanceContract {

    uint256 public constant MAX_PROPOSALS = 10;
    uint256 public constant MIN_VOTING_PERIOD = 1;
    uint256 public proposalCount;


    string public governanceId = "GOV001";

    struct Proposal {
        string proposalId;
        string title;
        string description;
        uint256 voteCount;
        uint256 startTime;
        uint256 endTime;
        uint256 isActive;
        address proposer;
        bytes extraData;
    }

    struct Voter {
        uint256 hasVoted;
        uint256 votedProposalIndex;
        uint256 votingPower;
        uint256 isRegistered;
    }

    mapping(address => Voter) public voters;
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => uint256)) public proposalVotes;

    address public admin;
    uint256 public totalVoters;

    event ProposalCreated(uint256 indexed proposalIndex, string proposalId, address proposer);
    event VoteCast(address indexed voter, uint256 indexed proposalIndex, uint256 votingPower);
    event VoterRegistered(address indexed voter, uint256 votingPower);

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
        totalVoters = 0;
    }

    function registerVoter(address voterAddress, uint256 votingPower) external onlyAdmin {
        require(voters[voterAddress].isRegistered == 0, "Voter already registered");
        require(votingPower > 0, "Voting power must be greater than 0");


        voters[voterAddress] = Voter({
            hasVoted: uint256(0),
            votedProposalIndex: uint256(0),
            votingPower: uint256(votingPower),
            isRegistered: uint256(1)
        });

        totalVoters = totalVoters + uint256(1);

        emit VoterRegistered(voterAddress, votingPower);
    }

    function createProposal(
        string memory proposalId,
        string memory title,
        string memory description,
        uint256 votingPeriodDays,
        bytes memory extraData
    ) external onlyRegisteredVoter {
        require(proposalCount < MAX_PROPOSALS, "Maximum proposals reached");
        require(votingPeriodDays >= MIN_VOTING_PERIOD, "Voting period too short");


        uint256 startTime = uint256(block.timestamp);
        uint256 endTime = uint256(block.timestamp + (votingPeriodDays * 1 days));

        proposals[proposalCount] = Proposal({
            proposalId: proposalId,
            title: title,
            description: description,
            voteCount: uint256(0),
            startTime: startTime,
            endTime: endTime,
            isActive: uint256(1),
            proposer: msg.sender,
            extraData: extraData
        });

        emit ProposalCreated(proposalCount, proposalId, msg.sender);
        proposalCount = proposalCount + uint256(1);
    }

    function vote(uint256 proposalIndex) external onlyRegisteredVoter {
        require(proposalIndex < proposalCount, "Invalid proposal index");
        require(proposals[proposalIndex].isActive == 1, "Proposal not active");
        require(block.timestamp >= proposals[proposalIndex].startTime, "Voting not started");
        require(block.timestamp <= proposals[proposalIndex].endTime, "Voting period ended");
        require(voters[msg.sender].hasVoted == 0 ||
                voters[msg.sender].votedProposalIndex != proposalIndex, "Already voted on this proposal");


        if (voters[msg.sender].hasVoted == 1) {
            uint256 previousProposal = voters[msg.sender].votedProposalIndex;
            proposals[previousProposal].voteCount -= voters[msg.sender].votingPower;
            proposalVotes[previousProposal][msg.sender] = uint256(0);
        }


        voters[msg.sender].hasVoted = uint256(1);
        voters[msg.sender].votedProposalIndex = proposalIndex;

        proposals[proposalIndex].voteCount += voters[msg.sender].votingPower;
        proposalVotes[proposalIndex][msg.sender] = uint256(1);

        emit VoteCast(msg.sender, proposalIndex, voters[msg.sender].votingPower);
    }

    function endProposal(uint256 proposalIndex) external onlyAdmin {
        require(proposalIndex < proposalCount, "Invalid proposal index");
        require(proposals[proposalIndex].isActive == 1, "Proposal already ended");

        proposals[proposalIndex].isActive = uint256(0);
    }

    function getProposal(uint256 proposalIndex) external view returns (
        string memory proposalId,
        string memory title,
        string memory description,
        uint256 voteCount,
        uint256 startTime,
        uint256 endTime,
        uint256 isActive,
        address proposer
    ) {
        require(proposalIndex < proposalCount, "Invalid proposal index");

        Proposal memory proposal = proposals[proposalIndex];
        return (
            proposal.proposalId,
            proposal.title,
            proposal.description,
            proposal.voteCount,
            proposal.startTime,
            proposal.endTime,
            proposal.isActive,
            proposal.proposer
        );
    }

    function getVoterInfo(address voterAddress) external view returns (
        uint256 hasVoted,
        uint256 votedProposalIndex,
        uint256 votingPower,
        uint256 isRegistered
    ) {
        Voter memory voter = voters[voterAddress];
        return (
            voter.hasVoted,
            voter.votedProposalIndex,
            voter.votingPower,
            voter.isRegistered
        );
    }

    function hasVotedOnProposal(address voterAddress, uint256 proposalIndex) external view returns (uint256) {
        return proposalVotes[proposalIndex][voterAddress];
    }

    function updateGovernanceId(string memory newId) external onlyAdmin {
        governanceId = newId;
    }

    function updateProposalExtraData(uint256 proposalIndex, bytes memory newExtraData) external onlyAdmin {
        require(proposalIndex < proposalCount, "Invalid proposal index");
        proposals[proposalIndex].extraData = newExtraData;
    }
}
