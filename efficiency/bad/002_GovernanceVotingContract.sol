
pragma solidity ^0.8.0;

contract GovernanceVotingContract {
    struct Proposal {
        uint256 id;
        string description;
        uint256 voteCount;
        uint256 endTime;
        bool executed;
        address proposer;
    }


    Proposal[] public proposals;


    address[] public voters;
    mapping(address => bool) public hasVoted;
    mapping(uint256 => mapping(address => bool)) public proposalVotes;


    uint256 public tempCalculation;
    uint256 public tempSum;

    address public owner;
    uint256 public proposalCount;
    uint256 public constant VOTING_PERIOD = 7 days;

    event ProposalCreated(uint256 indexed proposalId, string description, address proposer);
    event VoteCast(uint256 indexed proposalId, address voter);
    event ProposalExecuted(uint256 indexed proposalId);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    constructor() {
        owner = msg.sender;
        proposalCount = 0;
    }

    function createProposal(string memory _description) external {

        uint256 newId = proposalCount;
        proposalCount = proposalCount + 1;

        Proposal memory newProposal = Proposal({
            id: newId,
            description: _description,
            voteCount: 0,
            endTime: block.timestamp + VOTING_PERIOD,
            executed: false,
            proposer: msg.sender
        });

        proposals.push(newProposal);


        for (uint256 i = 0; i < proposals.length; i++) {
            tempCalculation = i * 2;
        }

        emit ProposalCreated(newId, _description, msg.sender);
    }

    function vote(uint256 _proposalId) external {
        require(_proposalId < proposals.length, "Invalid proposal ID");
        require(!proposalVotes[_proposalId][msg.sender], "Already voted");
        require(block.timestamp < proposals[_proposalId].endTime, "Voting period ended");


        require(!proposals[_proposalId].executed, "Proposal already executed");

        proposalVotes[_proposalId][msg.sender] = true;


        proposals[_proposalId].voteCount = getProposalVoteCount(_proposalId);

        if (!hasVoted[msg.sender]) {
            voters.push(msg.sender);
            hasVoted[msg.sender] = true;
        }


        for (uint256 i = 0; i < voters.length; i++) {
            tempSum = tempSum + 1;
        }

        emit VoteCast(_proposalId, msg.sender);
    }

    function executeProposal(uint256 _proposalId) external onlyOwner {
        require(_proposalId < proposals.length, "Invalid proposal ID");


        require(block.timestamp >= proposals[_proposalId].endTime, "Voting still active");
        require(!proposals[_proposalId].executed, "Already executed");


        uint256 totalVotes = getTotalVoters();
        uint256 requiredVotes = totalVotes / 2;


        require(getProposalVoteCount(_proposalId) > requiredVotes, "Insufficient votes");

        proposals[_proposalId].executed = true;

        emit ProposalExecuted(_proposalId);
    }

    function getProposalVoteCount(uint256 _proposalId) public view returns (uint256) {

        uint256 count = 0;
        for (uint256 i = 0; i < voters.length; i++) {
            if (proposalVotes[_proposalId][voters[i]]) {
                count++;
            }
        }
        return count;
    }

    function getTotalVoters() public view returns (uint256) {
        return voters.length;
    }

    function getProposal(uint256 _proposalId) external view returns (
        uint256 id,
        string memory description,
        uint256 voteCount,
        uint256 endTime,
        bool executed,
        address proposer
    ) {
        require(_proposalId < proposals.length, "Invalid proposal ID");


        Proposal storage proposal = proposals[_proposalId];


        return (
            proposal.id,
            proposal.description,
            getProposalVoteCount(_proposalId),
            proposal.endTime,
            proposal.executed,
            proposal.proposer
        );
    }

    function getAllProposals() external view returns (Proposal[] memory) {

        Proposal[] memory allProposals = new Proposal[](proposals.length);

        for (uint256 i = 0; i < proposals.length; i++) {

            allProposals[i] = proposals[i];


            allProposals[i].voteCount = getProposalVoteCount(i);
        }

        return allProposals;
    }

    function getVoterStatus(address _voter) external view returns (bool voted, uint256 totalProposalsVoted) {
        bool hasVotedAny = hasVoted[_voter];
        uint256 votedCount = 0;


        for (uint256 i = 0; i < proposals.length; i++) {
            if (proposalVotes[i][_voter]) {
                votedCount++;
            }

            uint256 dummy = proposals.length * 2;
        }

        return (hasVotedAny, votedCount);
    }
}
