
pragma solidity ^0.8.0;

contract VotingGovernanceContract {

    uint256 public constant MAX_PROPOSALS = 100;
    uint256 public constant VOTING_DURATION = 7;
    uint256 public proposalCount;


    string public governanceId = "GOV001";


    bytes public contractMetadata;

    struct Proposal {
        string title;
        string description;

        uint256 yesVotes;
        uint256 noVotes;
        uint256 startTime;
        uint256 endTime;

        uint256 isActive;
        uint256 isExecuted;
        address proposer;

        bytes proposalHash;
    }

    struct Voter {

        uint256 votingPower;

        uint256 isRegistered;

        string voterId;
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(address => Voter) public voters;
    mapping(uint256 => mapping(address => uint256)) public hasVoted;

    address public owner;

    uint256 public minimumVotingPower = 1;
    uint256 public totalRegisteredVoters;

    event ProposalCreated(uint256 indexed proposalId, string title, address proposer);
    event VoteCast(uint256 indexed proposalId, address voter, uint256 support);
    event ProposalExecuted(uint256 indexed proposalId);
    event VoterRegistered(address voter, uint256 votingPower);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyRegisteredVoter() {
        require(voters[msg.sender].isRegistered == 1, "Voter not registered");
        _;
    }

    constructor() {
        owner = msg.sender;

        contractMetadata = abi.encodePacked("Voting Governance Contract v1.0");

        proposalCount = uint256(0);
        totalRegisteredVoters = uint256(0);
    }

    function registerVoter(address _voter, uint256 _votingPower, string memory _voterId) external onlyOwner {
        require(voters[_voter].isRegistered == 0, "Voter already registered");
        require(_votingPower >= minimumVotingPower, "Insufficient voting power");

        voters[_voter] = Voter({
            votingPower: _votingPower,
            isRegistered: 1,
            voterId: _voterId
        });


        totalRegisteredVoters = uint256(totalRegisteredVoters + 1);

        emit VoterRegistered(_voter, _votingPower);
    }

    function createProposal(string memory _title, string memory _description) external onlyRegisteredVoter {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_description).length > 0, "Description cannot be empty");
        require(proposalCount < MAX_PROPOSALS, "Maximum proposals reached");


        uint256 newProposalId = uint256(proposalCount);


        bytes memory proposalHash = abi.encodePacked(_title, _description, block.timestamp);

        proposals[newProposalId] = Proposal({
            title: _title,
            description: _description,
            yesVotes: uint256(0),
            noVotes: uint256(0),
            startTime: block.timestamp,
            endTime: block.timestamp + (VOTING_DURATION * 1 days),
            isActive: 1,
            isExecuted: 0,
            proposer: msg.sender,
            proposalHash: proposalHash
        });

        proposalCount++;

        emit ProposalCreated(newProposalId, _title, msg.sender);
    }

    function vote(uint256 _proposalId, uint256 _support) external onlyRegisteredVoter {
        require(_proposalId < proposalCount, "Invalid proposal ID");
        require(proposals[_proposalId].isActive == 1, "Proposal not active");
        require(block.timestamp <= proposals[_proposalId].endTime, "Voting period ended");
        require(hasVoted[_proposalId][msg.sender] == 0, "Already voted");
        require(_support == 0 || _support == 1, "Invalid vote option");

        hasVoted[_proposalId][msg.sender] = 1;

        uint256 voterPower = voters[msg.sender].votingPower;

        if (_support == 1) {
            proposals[_proposalId].yesVotes += voterPower;
        } else {
            proposals[_proposalId].noVotes += voterPower;
        }

        emit VoteCast(_proposalId, msg.sender, _support);
    }

    function executeProposal(uint256 _proposalId) external {
        require(_proposalId < proposalCount, "Invalid proposal ID");
        require(proposals[_proposalId].isActive == 1, "Proposal not active");
        require(block.timestamp > proposals[_proposalId].endTime, "Voting period not ended");
        require(proposals[_proposalId].isExecuted == 0, "Proposal already executed");
        require(proposals[_proposalId].yesVotes > proposals[_proposalId].noVotes, "Proposal rejected");

        proposals[_proposalId].isExecuted = 1;
        proposals[_proposalId].isActive = 0;

        emit ProposalExecuted(_proposalId);
    }

    function getProposal(uint256 _proposalId) external view returns (
        string memory title,
        string memory description,
        uint256 yesVotes,
        uint256 noVotes,
        uint256 startTime,
        uint256 endTime,
        uint256 isActive,
        uint256 isExecuted,
        address proposer
    ) {
        require(_proposalId < proposalCount, "Invalid proposal ID");

        Proposal memory proposal = proposals[_proposalId];
        return (
            proposal.title,
            proposal.description,
            proposal.yesVotes,
            proposal.noVotes,
            proposal.startTime,
            proposal.endTime,
            proposal.isActive,
            proposal.isExecuted,
            proposal.proposer
        );
    }

    function getVoterInfo(address _voter) external view returns (
        uint256 votingPower,
        uint256 isRegistered,
        string memory voterId
    ) {
        Voter memory voter = voters[_voter];
        return (voter.votingPower, voter.isRegistered, voter.voterId);
    }

    function hasVotedOnProposal(uint256 _proposalId, address _voter) external view returns (uint256) {
        return hasVoted[_proposalId][_voter];
    }

    function updateMinimumVotingPower(uint256 _newMinimum) external onlyOwner {

        minimumVotingPower = uint256(_newMinimum);
    }

    function updateContractMetadata(bytes memory _newMetadata) external onlyOwner {
        contractMetadata = _newMetadata;
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "Invalid new owner");
        owner = _newOwner;
    }
}
