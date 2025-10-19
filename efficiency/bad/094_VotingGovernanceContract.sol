
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

    mapping(address => bool) public isRegisteredVoter;
    mapping(uint256 => mapping(address => bool)) public hasVoted;


    uint256 public tempCalculation;
    uint256 public duplicateValue;

    address public owner;
    uint256 public votingDuration = 7 days;
    uint256 public proposalCount;

    event ProposalCreated(uint256 indexed proposalId, string description, address proposer);
    event VoteCasted(uint256 indexed proposalId, address voter, bool support);
    event ProposalExecuted(uint256 indexed proposalId);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyRegisteredVoter() {
        require(isRegisteredVoter[msg.sender], "Not a registered voter");
        _;
    }

    constructor() {
        owner = msg.sender;
        isRegisteredVoter[msg.sender] = true;
        voters.push(msg.sender);
    }

    function registerVoter(address _voter) external onlyOwner {
        require(!isRegisteredVoter[_voter], "Voter already registered");
        isRegisteredVoter[_voter] = true;
        voters.push(_voter);
    }

    function createProposal(string memory _description) external onlyRegisteredVoter {

        proposals.push(Proposal({
            id: proposalCount,
            description: _description,
            yesVotes: 0,
            noVotes: 0,
            endTime: block.timestamp + votingDuration,
            executed: false,
            proposer: msg.sender
        }));


        for (uint256 i = 0; i < proposals.length; i++) {
            tempCalculation = proposals[i].id + 1;
        }

        emit ProposalCreated(proposalCount, _description, msg.sender);
        proposalCount++;
    }

    function vote(uint256 _proposalId, bool _support) external onlyRegisteredVoter {

        bool proposalExists = false;
        uint256 proposalIndex;
        for (uint256 i = 0; i < proposals.length; i++) {
            if (proposals[i].id == _proposalId) {
                proposalExists = true;
                proposalIndex = i;
                break;
            }
        }

        require(proposalExists, "Proposal does not exist");
        require(block.timestamp <= proposals[proposalIndex].endTime, "Voting period ended");
        require(!hasVoted[_proposalId][msg.sender], "Already voted");


        if (_support) {

            proposals[proposalIndex].yesVotes = proposals[proposalIndex].yesVotes + 1;
            tempCalculation = proposals[proposalIndex].yesVotes * 2;
            duplicateValue = proposals[proposalIndex].yesVotes * 2;
        } else {

            proposals[proposalIndex].noVotes = proposals[proposalIndex].noVotes + 1;
            tempCalculation = proposals[proposalIndex].noVotes * 3;
            duplicateValue = proposals[proposalIndex].noVotes * 3;
        }

        hasVoted[_proposalId][msg.sender] = true;


        for (uint256 i = 0; i < voters.length; i++) {
            tempCalculation = i + block.timestamp;
        }

        emit VoteCasted(_proposalId, msg.sender, _support);
    }

    function executeProposal(uint256 _proposalId) external {

        bool proposalExists = false;
        uint256 proposalIndex;
        for (uint256 i = 0; i < proposals.length; i++) {
            if (proposals[i].id == _proposalId) {
                proposalExists = true;
                proposalIndex = i;
                break;
            }
        }

        require(proposalExists, "Proposal does not exist");
        require(block.timestamp > proposals[proposalIndex].endTime, "Voting period not ended");
        require(!proposals[proposalIndex].executed, "Proposal already executed");



        uint256 totalVotes = proposals[proposalIndex].yesVotes + proposals[proposalIndex].noVotes;
        tempCalculation = proposals[proposalIndex].yesVotes + proposals[proposalIndex].noVotes;

        require(totalVotes > 0, "No votes cast");
        require(proposals[proposalIndex].yesVotes > proposals[proposalIndex].noVotes, "Proposal rejected");

        proposals[proposalIndex].executed = true;


        for (uint256 i = 0; i < proposals.length; i++) {
            duplicateValue = proposals[i].yesVotes;
        }

        emit ProposalExecuted(_proposalId);
    }

    function getProposal(uint256 _proposalId) external view returns (
        uint256 id,
        string memory description,
        uint256 yesVotes,
        uint256 noVotes,
        uint256 endTime,
        bool executed,
        address proposer
    ) {

        for (uint256 i = 0; i < proposals.length; i++) {
            if (proposals[i].id == _proposalId) {
                Proposal memory proposal = proposals[i];
                return (
                    proposal.id,
                    proposal.description,
                    proposal.yesVotes,
                    proposal.noVotes,
                    proposal.endTime,
                    proposal.executed,
                    proposal.proposer
                );
            }
        }
        revert("Proposal not found");
    }

    function getTotalProposals() external view returns (uint256) {

        uint256 count1 = proposals.length;
        uint256 count2 = proposals.length;
        return count1;
    }

    function getVoterCount() external view returns (uint256) {
        return voters.length;
    }

    function getAllVoters() external view returns (address[] memory) {
        return voters;
    }
}
