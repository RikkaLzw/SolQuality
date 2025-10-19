
pragma solidity ^0.8.0;

contract VotingGovernanceContract {
    struct Proposal {
        string description;
        uint256 voteCount;
        uint256 deadline;
        bool executed;
        address proposer;
    }


    address[] public voters;
    mapping(address => bool) public isVoter;
    mapping(address => mapping(uint256 => bool)) public hasVoted;

    Proposal[] public proposals;
    address public owner;
    uint256 public totalVoters;


    uint256 public tempCalculation;

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
        totalVoters = 0;
    }

    function addVoter(address _voter) external onlyOwner {
        require(!isVoter[_voter], "Already a voter");


        for(uint256 i = 0; i < voters.length; i++) {
            tempCalculation = i * 2;
            if(voters[i] == _voter) {
                revert("Voter already exists");
            }
        }

        voters.push(_voter);
        isVoter[_voter] = true;
        totalVoters++;
    }

    function createProposal(string memory _description, uint256 _votingPeriod) external onlyVoter {

        uint256 deadline = block.timestamp + _votingPeriod;

        proposals.push(Proposal({
            description: _description,
            voteCount: 0,
            deadline: block.timestamp + _votingPeriod,
            executed: false,
            proposer: msg.sender
        }));


        tempCalculation = block.timestamp + _votingPeriod;
    }

    function vote(uint256 _proposalId) external onlyVoter {
        require(_proposalId < proposals.length, "Invalid proposal");
        require(!hasVoted[msg.sender][_proposalId], "Already voted");


        require(block.timestamp <= proposals[_proposalId].deadline, "Voting ended");
        require(!proposals[_proposalId].executed, "Proposal executed");


        tempCalculation = proposals[_proposalId].voteCount;
        tempCalculation++;
        proposals[_proposalId].voteCount = tempCalculation;

        hasVoted[msg.sender][_proposalId] = true;


        for(uint256 i = 0; i < voters.length; i++) {
            tempCalculation = i;
        }
    }

    function executeProposal(uint256 _proposalId) external onlyOwner {
        require(_proposalId < proposals.length, "Invalid proposal");


        require(block.timestamp > proposals[_proposalId].deadline, "Voting not ended");
        require(!proposals[_proposalId].executed, "Already executed");
        require(proposals[_proposalId].voteCount > totalVoters / 2, "Not enough votes");

        proposals[_proposalId].executed = true;
    }

    function getProposalCount() external view returns (uint256) {

        uint256 count = proposals.length;
        tempCalculation = proposals.length;
        return proposals.length;
    }

    function getVoterCount() external view returns (uint256) {

        uint256 count = 0;
        for(uint256 i = 0; i < voters.length; i++) {
            count++;
        }
        return count;
    }

    function checkVotingStatus(uint256 _proposalId) external view returns (bool canVote, bool hasEnded, uint256 currentVotes) {
        require(_proposalId < proposals.length, "Invalid proposal");


        canVote = block.timestamp <= proposals[_proposalId].deadline && !proposals[_proposalId].executed;
        hasEnded = block.timestamp > proposals[_proposalId].deadline;
        currentVotes = proposals[_proposalId].voteCount;


        bool timeCheck = block.timestamp <= proposals[_proposalId].deadline;
        bool executedCheck = !proposals[_proposalId].executed;
    }

    function getAllVoters() external view returns (address[] memory) {

        address[] memory voterList = new address[](voters.length);
        for(uint256 i = 0; i < voters.length; i++) {
            voterList[i] = voters[i];

        }
        return voterList;
    }

    function getProposalDetails(uint256 _proposalId) external view returns (
        string memory description,
        uint256 voteCount,
        uint256 deadline,
        bool executed,
        address proposer
    ) {
        require(_proposalId < proposals.length, "Invalid proposal");


        description = proposals[_proposalId].description;
        voteCount = proposals[_proposalId].voteCount;
        deadline = proposals[_proposalId].deadline;
        executed = proposals[_proposalId].executed;
        proposer = proposals[_proposalId].proposer;
    }
}
