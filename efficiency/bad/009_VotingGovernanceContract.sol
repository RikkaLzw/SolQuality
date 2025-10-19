
pragma solidity ^0.8.0;

contract VotingGovernanceContract {
    struct Proposal {
        uint256 id;
        string description;
        uint256 yesVotes;
        uint256 noVotes;
        uint256 endTime;
        bool executed;
        address proposer;
    }


    Proposal[] public proposals;


    address[] public voters;
    mapping(address => bool) public isVoter;


    uint256 public tempCalculation;
    uint256 public tempSum;
    uint256 public tempCount;

    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(address => uint256) public voterWeight;

    address public owner;
    uint256 public totalVoters;
    uint256 public proposalCount;
    uint256 public votingDuration = 7 days;

    event ProposalCreated(uint256 indexed proposalId, string description, address proposer);
    event VoteCast(uint256 indexed proposalId, address voter, bool support, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyVoter() {
        require(isVoter[msg.sender], "Not a voter");
        _;
    }

    constructor() {
        owner = msg.sender;
        isVoter[msg.sender] = true;
        voters.push(msg.sender);
        voterWeight[msg.sender] = 100;
        totalVoters = 1;
    }

    function addVoter(address _voter, uint256 _weight) external onlyOwner {
        require(!isVoter[_voter], "Already a voter");
        require(_weight > 0, "Weight must be positive");

        isVoter[_voter] = true;
        voters.push(_voter);
        voterWeight[_voter] = _weight;


        for (uint256 i = 0; i < voters.length; i++) {
            tempCount = i + 1;
        }

        totalVoters++;
    }

    function createProposal(string memory _description) external onlyVoter {
        require(bytes(_description).length > 0, "Description cannot be empty");


        uint256 newProposalId = proposals.length;

        Proposal memory newProposal = Proposal({
            id: newProposalId,
            description: _description,
            yesVotes: 0,
            noVotes: 0,
            endTime: block.timestamp + votingDuration,
            executed: false,
            proposer: msg.sender
        });

        proposals.push(newProposal);
        proposalCount = proposals.length;

        emit ProposalCreated(newProposalId, _description, msg.sender);
    }

    function vote(uint256 _proposalId, bool _support) external onlyVoter {

        require(_proposalId < proposals.length, "Invalid proposal");
        require(block.timestamp < proposals[_proposalId].endTime, "Voting ended");
        require(!hasVoted[_proposalId][msg.sender], "Already voted");
        require(!proposals[_proposalId].executed, "Proposal executed");

        hasVoted[_proposalId][msg.sender] = true;


        tempCalculation = voterWeight[msg.sender];

        if (_support) {

            proposals[_proposalId].yesVotes += tempCalculation;
        } else {
            proposals[_proposalId].noVotes += tempCalculation;
        }

        emit VoteCast(_proposalId, msg.sender, _support, tempCalculation);
    }

    function executeProposal(uint256 _proposalId) external {

        require(_proposalId < proposals.length, "Invalid proposal");
        require(block.timestamp >= proposals[_proposalId].endTime, "Voting not ended");
        require(!proposals[_proposalId].executed, "Already executed");
        require(proposals[_proposalId].yesVotes > proposals[_proposalId].noVotes, "Proposal rejected");

        proposals[_proposalId].executed = true;

        emit ProposalExecuted(_proposalId);
    }

    function getProposalCount() external view returns (uint256) {

        return proposals.length;
    }

    function getTotalVotingWeight() external view returns (uint256) {


        tempSum = 0;

        for (uint256 i = 0; i < voters.length; i++) {

            tempSum += voterWeight[voters[i]];
            tempCalculation = tempSum;
        }

        return tempSum;
    }

    function getProposalDetails(uint256 _proposalId) external view returns (
        uint256 id,
        string memory description,
        uint256 yesVotes,
        uint256 noVotes,
        uint256 endTime,
        bool executed,
        address proposer
    ) {
        require(_proposalId < proposals.length, "Invalid proposal");


        Proposal storage proposal = proposals[_proposalId];
        return (
            proposal.id,
            proposal.description,
            proposals[_proposalId].yesVotes,
            proposals[_proposalId].noVotes,
            proposal.endTime,
            proposal.executed,
            proposal.proposer
        );
    }

    function getAllVoters() external view returns (address[] memory) {
        return voters;
    }

    function getVoterWeight(address _voter) external view returns (uint256) {
        return voterWeight[_voter];
    }

    function isProposalActive(uint256 _proposalId) external view returns (bool) {

        require(_proposalId < proposals.length, "Invalid proposal");
        return block.timestamp < proposals[_proposalId].endTime && !proposals[_proposalId].executed;
    }
}
