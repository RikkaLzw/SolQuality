
pragma solidity ^0.8.0;

contract VotingGovernanceContract {


    mapping(address => bool) public hasVoted;
    mapping(uint256 => uint256) public proposalVotes;
    mapping(uint256 => bool) public proposalExecuted;
    mapping(address => uint256) public voterWeight;
    address[] public allVoters;
    uint256 public totalProposals;
    uint256 public totalVoters;
    address public owner;
    bool public votingActive;

    struct Proposal {
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 deadline;
        bool executed;
        address proposer;
    }


    mapping(uint256 => Proposal) public proposals;

    constructor() {
        owner = msg.sender;
        votingActive = true;
        totalProposals = 0;
        totalVoters = 0;
    }

    function createProposal(string memory _description) public {

        require(bytes(_description).length > 0, "Description cannot be empty");
        require(bytes(_description).length <= 500, "Description too long");


        if (msg.sender != owner) {
            require(voterWeight[msg.sender] > 0, "Only registered voters can create proposals");
        }

        totalProposals++;
        proposals[totalProposals] = Proposal({
            description: _description,
            forVotes: 0,
            againstVotes: 0,
            deadline: block.timestamp + 604800,
            executed: false,
            proposer: msg.sender
        });
    }

    function registerVoter(address _voter) public {

        require(msg.sender == owner, "Only owner can register voters");
        require(_voter != address(0), "Invalid address");


        if (voterWeight[_voter] == 0) {
            voterWeight[_voter] = 1;
            allVoters.push(_voter);
            totalVoters++;
        }
    }

    function registerMultipleVoters(address[] memory _voters) public {

        require(msg.sender == owner, "Only owner can register voters");

        for (uint256 i = 0; i < _voters.length; i++) {
            require(_voters[i] != address(0), "Invalid address");


            if (voterWeight[_voters[i]] == 0) {
                voterWeight[_voters[i]] = 1;
                allVoters.push(_voters[i]);
                totalVoters++;
            }
        }
    }

    function vote(uint256 _proposalId, bool _support) public {

        require(votingActive == true, "Voting is not active");
        require(_proposalId > 0 && _proposalId <= totalProposals, "Invalid proposal ID");
        require(voterWeight[msg.sender] > 0, "You are not registered to vote");
        require(block.timestamp <= proposals[_proposalId].deadline, "Voting period has ended");
        require(!hasVoted[msg.sender], "You have already voted");

        hasVoted[msg.sender] = true;

        if (_support) {
            proposals[_proposalId].forVotes += voterWeight[msg.sender];
        } else {
            proposals[_proposalId].againstVotes += voterWeight[msg.sender];
        }

        proposalVotes[_proposalId] += voterWeight[msg.sender];
    }

    function executeProposal(uint256 _proposalId) public {

        require(_proposalId > 0 && _proposalId <= totalProposals, "Invalid proposal ID");
        require(block.timestamp > proposals[_proposalId].deadline, "Voting period not ended");
        require(!proposals[_proposalId].executed, "Proposal already executed");


        uint256 quorum = (totalVoters * 30) / 100;
        uint256 totalVotesForProposal = proposals[_proposalId].forVotes + proposals[_proposalId].againstVotes;

        require(totalVotesForProposal >= quorum, "Quorum not reached");
        require(proposals[_proposalId].forVotes > proposals[_proposalId].againstVotes, "Proposal rejected");

        proposals[_proposalId].executed = true;
        proposalExecuted[_proposalId] = true;
    }

    function changeVoterWeight(address _voter, uint256 _newWeight) public {

        require(msg.sender == owner, "Only owner can change voter weight");
        require(_voter != address(0), "Invalid address");
        require(_newWeight > 0, "Weight must be greater than 0");

        voterWeight[_voter] = _newWeight;
    }

    function toggleVoting() public {

        require(msg.sender == owner, "Only owner can toggle voting");

        votingActive = !votingActive;
    }

    function getProposal(uint256 _proposalId) public view returns (
        string memory description,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 deadline,
        bool executed,
        address proposer
    ) {

        require(_proposalId > 0 && _proposalId <= totalProposals, "Invalid proposal ID");

        Proposal memory proposal = proposals[_proposalId];
        return (
            proposal.description,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.deadline,
            proposal.executed,
            proposal.proposer
        );
    }

    function getVoterInfo(address _voter) public view returns (uint256 weight, bool voted) {
        return (voterWeight[_voter], hasVoted[_voter]);
    }

    function resetVoting() public {

        require(msg.sender == owner, "Only owner can reset voting");


        for (uint256 i = 0; i < allVoters.length; i++) {
            hasVoted[allVoters[i]] = false;
        }
    }

    function extendProposalDeadline(uint256 _proposalId, uint256 _additionalTime) public {

        require(msg.sender == owner, "Only owner can extend deadline");

        require(_proposalId > 0 && _proposalId <= totalProposals, "Invalid proposal ID");
        require(!proposals[_proposalId].executed, "Cannot extend executed proposal");

        proposals[_proposalId].deadline += _additionalTime;
    }

    function emergencyStop() public {

        require(msg.sender == owner, "Only owner can emergency stop");

        votingActive = false;
    }

    function getProposalStatus(uint256 _proposalId) public view returns (
        bool isActive,
        bool hasQuorum,
        bool isPassing,
        uint256 timeLeft
    ) {

        require(_proposalId > 0 && _proposalId <= totalProposals, "Invalid proposal ID");

        Proposal memory proposal = proposals[_proposalId];


        uint256 quorum = (totalVoters * 30) / 100;
        uint256 totalVotesForProposal = proposal.forVotes + proposal.againstVotes;

        isActive = block.timestamp <= proposal.deadline && !proposal.executed;
        hasQuorum = totalVotesForProposal >= quorum;
        isPassing = proposal.forVotes > proposal.againstVotes;

        if (block.timestamp >= proposal.deadline) {
            timeLeft = 0;
        } else {
            timeLeft = proposal.deadline - block.timestamp;
        }
    }

    function transferOwnership(address _newOwner) public {

        require(msg.sender == owner, "Only owner can transfer ownership");
        require(_newOwner != address(0), "Invalid new owner address");

        owner = _newOwner;
    }
}
