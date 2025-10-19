
pragma solidity ^0.8.0;


contract VotingGovernanceContract {

    enum ProposalStatus {
        Pending,
        Active,
        Succeeded,
        Failed,
        Executed
    }


    struct Proposal {
        uint256 proposalId;
        address proposer;
        string title;
        string description;
        uint256 startTime;
        uint256 endTime;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        ProposalStatus status;
        bool executed;
        mapping(address => bool) hasVoted;
        mapping(address => uint8) voteChoice;
    }


    enum VoteChoice {
        Against,
        For,
        Abstain
    }


    address public owner;
    uint256 public proposalCount;
    uint256 public votingDuration;
    uint256 public minimumVotesToPass;
    uint256 public quorumPercentage;

    mapping(uint256 => Proposal) public proposals;
    mapping(address => bool) public isEligibleVoter;
    mapping(address => uint256) public voterWeight;
    address[] public eligibleVoters;


    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string title,
        string description,
        uint256 startTime,
        uint256 endTime
    );

    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        uint8 choice,
        uint256 weight
    );

    event ProposalExecuted(
        uint256 indexed proposalId,
        bool success
    );

    event VoterAdded(address indexed voter, uint256 weight);
    event VoterRemoved(address indexed voter);
    event VotingParametersUpdated(uint256 duration, uint256 minimumVotes, uint256 quorum);


    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyEligibleVoter() {
        require(isEligibleVoter[msg.sender], "Caller is not an eligible voter");
        _;
    }

    modifier validProposal(uint256 _proposalId) {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid proposal ID");
        _;
    }


    constructor(
        uint256 _votingDuration,
        uint256 _minimumVotesToPass,
        uint256 _quorumPercentage
    ) {
        require(_votingDuration > 0, "Voting duration must be greater than 0");
        require(_quorumPercentage <= 100, "Quorum percentage cannot exceed 100");

        owner = msg.sender;
        votingDuration = _votingDuration;
        minimumVotesToPass = _minimumVotesToPass;
        quorumPercentage = _quorumPercentage;


        isEligibleVoter[msg.sender] = true;
        voterWeight[msg.sender] = 1;
        eligibleVoters.push(msg.sender);
    }


    function addVoter(address _voter, uint256 _weight) external onlyOwner {
        require(_voter != address(0), "Invalid voter address");
        require(_weight > 0, "Weight must be greater than 0");
        require(!isEligibleVoter[_voter], "Voter already exists");

        isEligibleVoter[_voter] = true;
        voterWeight[_voter] = _weight;
        eligibleVoters.push(_voter);

        emit VoterAdded(_voter, _weight);
    }


    function removeVoter(address _voter) external onlyOwner {
        require(isEligibleVoter[_voter], "Voter does not exist");
        require(_voter != owner, "Cannot remove owner");

        isEligibleVoter[_voter] = false;
        voterWeight[_voter] = 0;


        for (uint256 i = 0; i < eligibleVoters.length; i++) {
            if (eligibleVoters[i] == _voter) {
                eligibleVoters[i] = eligibleVoters[eligibleVoters.length - 1];
                eligibleVoters.pop();
                break;
            }
        }

        emit VoterRemoved(_voter);
    }


    function createProposal(
        string memory _title,
        string memory _description
    ) external onlyEligibleVoter {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_description).length > 0, "Description cannot be empty");

        proposalCount++;
        uint256 proposalId = proposalCount;

        Proposal storage newProposal = proposals[proposalId];
        newProposal.proposalId = proposalId;
        newProposal.proposer = msg.sender;
        newProposal.title = _title;
        newProposal.description = _description;
        newProposal.startTime = block.timestamp;
        newProposal.endTime = block.timestamp + votingDuration;
        newProposal.status = ProposalStatus.Active;
        newProposal.executed = false;

        emit ProposalCreated(
            proposalId,
            msg.sender,
            _title,
            _description,
            newProposal.startTime,
            newProposal.endTime
        );
    }


    function vote(
        uint256 _proposalId,
        uint8 _choice
    ) external onlyEligibleVoter validProposal(_proposalId) {
        require(_choice <= 2, "Invalid vote choice");

        Proposal storage proposal = proposals[_proposalId];
        require(proposal.status == ProposalStatus.Active, "Proposal is not active");
        require(block.timestamp <= proposal.endTime, "Voting period has ended");
        require(!proposal.hasVoted[msg.sender], "Already voted on this proposal");

        uint256 weight = voterWeight[msg.sender];
        proposal.hasVoted[msg.sender] = true;
        proposal.voteChoice[msg.sender] = _choice;

        if (_choice == uint8(VoteChoice.For)) {
            proposal.forVotes += weight;
        } else if (_choice == uint8(VoteChoice.Against)) {
            proposal.againstVotes += weight;
        } else {
            proposal.abstainVotes += weight;
        }

        emit VoteCast(_proposalId, msg.sender, _choice, weight);
    }


    function finalizeProposal(uint256 _proposalId) external validProposal(_proposalId) {
        Proposal storage proposal = proposals[_proposalId];
        require(proposal.status == ProposalStatus.Active, "Proposal is not active");
        require(block.timestamp > proposal.endTime, "Voting period has not ended");

        uint256 totalVotes = proposal.forVotes + proposal.againstVotes + proposal.abstainVotes;
        uint256 totalEligibleVotes = getTotalEligibleVotes();
        uint256 requiredQuorum = (totalEligibleVotes * quorumPercentage) / 100;


        if (totalVotes >= requiredQuorum &&
            proposal.forVotes >= minimumVotesToPass &&
            proposal.forVotes > proposal.againstVotes) {
            proposal.status = ProposalStatus.Succeeded;
        } else {
            proposal.status = ProposalStatus.Failed;
        }
    }


    function executeProposal(uint256 _proposalId) external validProposal(_proposalId) {
        Proposal storage proposal = proposals[_proposalId];
        require(proposal.status == ProposalStatus.Succeeded, "Proposal has not succeeded");
        require(!proposal.executed, "Proposal already executed");

        proposal.executed = true;
        proposal.status = ProposalStatus.Executed;

        emit ProposalExecuted(_proposalId, true);
    }


    function getProposal(uint256 _proposalId) external view validProposal(_proposalId) returns (
        uint256 proposalId,
        address proposer,
        string memory title,
        string memory description,
        uint256 startTime,
        uint256 endTime,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 abstainVotes,
        ProposalStatus status,
        bool executed
    ) {
        Proposal storage proposal = proposals[_proposalId];
        return (
            proposal.proposalId,
            proposal.proposer,
            proposal.title,
            proposal.description,
            proposal.startTime,
            proposal.endTime,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.abstainVotes,
            proposal.status,
            proposal.executed
        );
    }


    function hasVotedOnProposal(uint256 _proposalId, address _voter)
        external
        view
        validProposal(_proposalId)
        returns (bool)
    {
        return proposals[_proposalId].hasVoted[_voter];
    }


    function getVoteChoice(uint256 _proposalId, address _voter)
        external
        view
        validProposal(_proposalId)
        returns (uint8)
    {
        require(proposals[_proposalId].hasVoted[_voter], "Voter has not voted on this proposal");
        return proposals[_proposalId].voteChoice[_voter];
    }


    function getTotalEligibleVotes() public view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < eligibleVoters.length; i++) {
            if (isEligibleVoter[eligibleVoters[i]]) {
                total += voterWeight[eligibleVoters[i]];
            }
        }
        return total;
    }


    function getEligibleVotersCount() external view returns (uint256) {
        return eligibleVoters.length;
    }


    function updateVotingParameters(
        uint256 _votingDuration,
        uint256 _minimumVotesToPass,
        uint256 _quorumPercentage
    ) external onlyOwner {
        require(_votingDuration > 0, "Voting duration must be greater than 0");
        require(_quorumPercentage <= 100, "Quorum percentage cannot exceed 100");

        votingDuration = _votingDuration;
        minimumVotesToPass = _minimumVotesToPass;
        quorumPercentage = _quorumPercentage;

        emit VotingParametersUpdated(_votingDuration, _minimumVotesToPass, _quorumPercentage);
    }


    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "New owner cannot be zero address");
        require(_newOwner != owner, "New owner must be different from current owner");


        if (!isEligibleVoter[_newOwner]) {
            isEligibleVoter[_newOwner] = true;
            voterWeight[_newOwner] = 1;
            eligibleVoters.push(_newOwner);
        }

        owner = _newOwner;
    }
}
