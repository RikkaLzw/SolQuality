
pragma solidity ^0.8.0;

contract VotingGovernanceContract {


    mapping(address => uint256) public voterBalances;
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(uint256 => mapping(address => uint256)) public votes;
    address public owner;
    uint256 public proposalCount;
    uint256 public totalSupply;
    mapping(address => bool) public isRegistered;

    struct Proposal {
        string title;
        string description;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        address proposer;
        bool exists;
    }

    event ProposalCreated(uint256 proposalId, string title, address proposer);
    event VoteCast(uint256 proposalId, address voter, uint256 votes, bool support);
    event ProposalExecuted(uint256 proposalId);

    constructor() {
        owner = msg.sender;
        totalSupply = 1000000;
        voterBalances[msg.sender] = totalSupply;
        isRegistered[msg.sender] = true;
    }


    function createProposal(string memory _title, string memory _description) public {

        require(isRegistered[msg.sender], "Not registered");
        require(voterBalances[msg.sender] >= 1000, "Insufficient balance");

        proposalCount++;
        proposals[proposalCount] = Proposal({
            title: _title,
            description: _description,
            votesFor: 0,
            votesAgainst: 0,
            startTime: block.timestamp,
            endTime: block.timestamp + 604800,
            executed: false,
            proposer: msg.sender,
            exists: true
        });

        emit ProposalCreated(proposalCount, _title, msg.sender);
    }

    function vote(uint256 _proposalId, bool _support, uint256 _votes) public {

        require(isRegistered[msg.sender], "Not registered");
        require(voterBalances[msg.sender] >= 1000, "Insufficient balance");


        require(proposals[_proposalId].exists, "Proposal does not exist");
        require(block.timestamp >= proposals[_proposalId].startTime, "Voting not started");
        require(block.timestamp <= proposals[_proposalId].endTime, "Voting ended");
        require(!proposals[_proposalId].executed, "Proposal already executed");

        require(!hasVoted[_proposalId][msg.sender], "Already voted");
        require(_votes <= voterBalances[msg.sender], "Insufficient votes");
        require(_votes > 0, "Must vote with at least 1 token");

        hasVoted[_proposalId][msg.sender] = true;
        votes[_proposalId][msg.sender] = _votes;

        if (_support) {
            proposals[_proposalId].votesFor += _votes;
        } else {
            proposals[_proposalId].votesAgainst += _votes;
        }

        emit VoteCast(_proposalId, msg.sender, _votes, _support);
    }

    function executeProposal(uint256 _proposalId) public {

        require(isRegistered[msg.sender], "Not registered");
        require(voterBalances[msg.sender] >= 1000, "Insufficient balance");


        require(proposals[_proposalId].exists, "Proposal does not exist");
        require(block.timestamp >= proposals[_proposalId].startTime, "Voting not started");
        require(block.timestamp > proposals[_proposalId].endTime, "Voting still active");
        require(!proposals[_proposalId].executed, "Proposal already executed");

        require(proposals[_proposalId].votesFor > proposals[_proposalId].votesAgainst, "Proposal rejected");
        require(proposals[_proposalId].votesFor >= 100000, "Insufficient votes for execution");

        proposals[_proposalId].executed = true;
        emit ProposalExecuted(_proposalId);
    }

    function registerVoter(address _voter) public {

        require(msg.sender == owner, "Only owner can register voters");
        require(!isRegistered[_voter], "Already registered");

        isRegistered[_voter] = true;
        voterBalances[_voter] = 10000;
    }

    function transferTokens(address _to, uint256 _amount) public {

        require(isRegistered[msg.sender], "Not registered");
        require(voterBalances[msg.sender] >= 1000, "Insufficient balance");

        require(isRegistered[_to], "Recipient not registered");
        require(_amount > 0, "Amount must be positive");
        require(voterBalances[msg.sender] >= _amount, "Insufficient balance for transfer");

        voterBalances[msg.sender] -= _amount;
        voterBalances[_to] += _amount;
    }

    function delegateVotes(address _delegate, uint256 _proposalId) public {

        require(isRegistered[msg.sender], "Not registered");
        require(voterBalances[msg.sender] >= 1000, "Insufficient balance");


        require(proposals[_proposalId].exists, "Proposal does not exist");
        require(block.timestamp >= proposals[_proposalId].startTime, "Voting not started");
        require(block.timestamp <= proposals[_proposalId].endTime, "Voting ended");
        require(!proposals[_proposalId].executed, "Proposal already executed");

        require(isRegistered[_delegate], "Delegate not registered");
        require(!hasVoted[_proposalId][msg.sender], "Already voted");
        require(msg.sender != _delegate, "Cannot delegate to self");

        hasVoted[_proposalId][msg.sender] = true;
        voterBalances[_delegate] += voterBalances[msg.sender] / 2;
    }

    function getProposalInfo(uint256 _proposalId) public view returns (
        string memory title,
        string memory description,
        uint256 votesFor,
        uint256 votesAgainst,
        uint256 startTime,
        uint256 endTime,
        bool executed,
        address proposer
    ) {

        require(proposals[_proposalId].exists, "Proposal does not exist");

        Proposal memory proposal = proposals[_proposalId];
        return (
            proposal.title,
            proposal.description,
            proposal.votesFor,
            proposal.votesAgainst,
            proposal.startTime,
            proposal.endTime,
            proposal.executed,
            proposal.proposer
        );
    }

    function changeOwner(address _newOwner) public {

        require(msg.sender == owner, "Only owner can change owner");
        require(_newOwner != address(0), "Invalid address");
        require(isRegistered[_newOwner], "New owner must be registered");

        owner = _newOwner;
    }

    function mintTokens(address _to, uint256 _amount) public {

        require(msg.sender == owner, "Only owner can mint tokens");
        require(isRegistered[_to], "Recipient not registered");
        require(_amount > 0, "Amount must be positive");
        require(_amount <= 50000, "Cannot mint more than 50000 tokens");

        voterBalances[_to] += _amount;
        totalSupply += _amount;
    }

    function burnTokens(uint256 _amount) public {

        require(isRegistered[msg.sender], "Not registered");
        require(voterBalances[msg.sender] >= 1000, "Insufficient balance");

        require(_amount > 0, "Amount must be positive");
        require(voterBalances[msg.sender] >= _amount, "Insufficient balance to burn");
        require(voterBalances[msg.sender] - _amount >= 1000, "Cannot burn below minimum balance");

        voterBalances[msg.sender] -= _amount;
        totalSupply -= _amount;
    }

    function emergencyPause(uint256 _proposalId) public {

        require(msg.sender == owner, "Only owner can pause");


        require(proposals[_proposalId].exists, "Proposal does not exist");
        require(block.timestamp >= proposals[_proposalId].startTime, "Voting not started");
        require(block.timestamp <= proposals[_proposalId].endTime, "Voting ended");
        require(!proposals[_proposalId].executed, "Proposal already executed");

        proposals[_proposalId].endTime = block.timestamp;
    }

    function extendVotingPeriod(uint256 _proposalId) public {

        require(msg.sender == owner, "Only owner can extend voting");


        require(proposals[_proposalId].exists, "Proposal does not exist");
        require(block.timestamp >= proposals[_proposalId].startTime, "Voting not started");
        require(block.timestamp <= proposals[_proposalId].endTime, "Voting ended");
        require(!proposals[_proposalId].executed, "Proposal already executed");

        proposals[_proposalId].endTime += 86400;
    }

    function getVoterBalance(address _voter) public view returns (uint256) {

        require(isRegistered[_voter], "Voter not registered");

        return voterBalances[_voter];
    }

    function getTotalVotes(uint256 _proposalId) public view returns (uint256 totalVotes) {

        require(proposals[_proposalId].exists, "Proposal does not exist");

        return proposals[_proposalId].votesFor + proposals[_proposalId].votesAgainst;
    }

    function isVotingActive(uint256 _proposalId) public view returns (bool) {

        require(proposals[_proposalId].exists, "Proposal does not exist");

        return (block.timestamp >= proposals[_proposalId].startTime &&
                block.timestamp <= proposals[_proposalId].endTime &&
                !proposals[_proposalId].executed);
    }
}
