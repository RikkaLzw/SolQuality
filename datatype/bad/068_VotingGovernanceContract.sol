
pragma solidity ^0.8.0;

contract VotingGovernanceContract {

    uint256 public constant MAX_PROPOSALS = 10;
    uint256 public constant VOTING_DURATION = 7;
    uint256 public proposalCount;


    string public governanceId = "GOV001";


    bytes public contractMetadata;

    struct Proposal {
        uint256 id;
        string title;
        string description;
        address proposer;
        uint256 startTime;
        uint256 endTime;
        uint256 yesVotes;
        uint256 noVotes;

        uint256 executed;
        uint256 active;
        bytes proposalData;
    }

    struct Voter {
        uint256 weight;

        uint256 registered;
        mapping(uint256 => uint256) voted;
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(address => Voter) public voters;

    address public admin;
    uint256 public totalVoters;

    event ProposalCreated(uint256 indexed proposalId, string title, address proposer);
    event VoteCast(address indexed voter, uint256 indexed proposalId, uint256 support);
    event ProposalExecuted(uint256 indexed proposalId);
    event VoterRegistered(address indexed voter, uint256 weight);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }

    modifier onlyRegisteredVoter() {
        require(voters[msg.sender].registered == 1, "Voter not registered");
        _;
    }

    constructor() {
        admin = msg.sender;

        contractMetadata = "Voting Governance Contract v1.0";
        proposalCount = 0;
        totalVoters = 0;
    }

    function registerVoter(address voter, uint256 weight) external onlyAdmin {
        require(voters[voter].registered == 0, "Voter already registered");
        require(weight > 0, "Weight must be greater than 0");

        voters[voter].weight = weight;
        voters[voter].registered = 1;


        totalVoters = uint256(totalVoters + 1);

        emit VoterRegistered(voter, weight);
    }

    function createProposal(
        string memory title,
        string memory description,
        bytes memory proposalData
    ) external onlyRegisteredVoter returns (uint256) {
        require(bytes(title).length > 0, "Title cannot be empty");
        require(bytes(description).length > 0, "Description cannot be empty");
        require(proposalCount < MAX_PROPOSALS, "Maximum proposals reached");


        uint256 proposalId = uint256(proposalCount + 1);
        proposalCount = proposalId;

        uint256 startTime = block.timestamp;

        uint256 endTime = uint256(startTime + (VOTING_DURATION * 24 * 60 * 60));

        proposals[proposalId] = Proposal({
            id: proposalId,
            title: title,
            description: description,
            proposer: msg.sender,
            startTime: startTime,
            endTime: endTime,
            yesVotes: 0,
            noVotes: 0,
            executed: 0,
            active: 1,
            proposalData: proposalData
        });

        emit ProposalCreated(proposalId, title, msg.sender);
        return proposalId;
    }

    function vote(uint256 proposalId, uint256 support) external onlyRegisteredVoter {
        require(proposalId > 0 && proposalId <= proposalCount, "Invalid proposal ID");
        require(proposals[proposalId].active == 1, "Proposal not active");
        require(block.timestamp >= proposals[proposalId].startTime, "Voting not started");
        require(block.timestamp <= proposals[proposalId].endTime, "Voting ended");
        require(voters[msg.sender].voted[proposalId] == 0, "Already voted");
        require(support == 1 || support == 2, "Invalid vote: use 1 for yes, 2 for no");

        voters[msg.sender].voted[proposalId] = support;


        uint256 voterWeight = uint256(voters[msg.sender].weight);

        if (support == 1) {
            proposals[proposalId].yesVotes += voterWeight;
        } else {
            proposals[proposalId].noVotes += voterWeight;
        }

        emit VoteCast(msg.sender, proposalId, support);
    }

    function executeProposal(uint256 proposalId) external onlyAdmin {
        require(proposalId > 0 && proposalId <= proposalCount, "Invalid proposal ID");
        require(proposals[proposalId].active == 1, "Proposal not active");
        require(block.timestamp > proposals[proposalId].endTime, "Voting still ongoing");
        require(proposals[proposalId].executed == 0, "Proposal already executed");
        require(proposals[proposalId].yesVotes > proposals[proposalId].noVotes, "Proposal rejected");

        proposals[proposalId].executed = 1;
        proposals[proposalId].active = 0;

        emit ProposalExecuted(proposalId);
    }

    function getProposal(uint256 proposalId) external view returns (
        uint256 id,
        string memory title,
        string memory description,
        address proposer,
        uint256 startTime,
        uint256 endTime,
        uint256 yesVotes,
        uint256 noVotes,
        uint256 executed,
        uint256 active
    ) {
        require(proposalId > 0 && proposalId <= proposalCount, "Invalid proposal ID");

        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.id,
            proposal.title,
            proposal.description,
            proposal.proposer,
            proposal.startTime,
            proposal.endTime,
            proposal.yesVotes,
            proposal.noVotes,
            proposal.executed,
            proposal.active
        );
    }

    function getVoterInfo(address voter) external view returns (
        uint256 weight,
        uint256 registered
    ) {
        return (
            voters[voter].weight,
            voters[voter].registered
        );
    }

    function hasVoted(address voter, uint256 proposalId) external view returns (uint256) {
        return voters[voter].voted[proposalId];
    }

    function updateGovernanceId(string memory newId) external onlyAdmin {
        governanceId = newId;
    }

    function updateContractMetadata(bytes memory newMetadata) external onlyAdmin {
        contractMetadata = newMetadata;
    }


    function getTotalVoters() external view returns (uint256) {
        return uint256(totalVoters);
    }

    function getProposalCount() external view returns (uint256) {
        return uint256(proposalCount);
    }
}
