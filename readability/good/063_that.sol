
pragma solidity ^0.8.19;


contract DAOGovernanceContract {

    enum ProposalStatus {
        Pending,
        Active,
        Succeeded,
        Defeated,
        Executed
    }


    struct Proposal {
        uint256 proposalId;
        address proposer;
        string title;
        string description;
        uint256 votingStartTime;
        uint256 votingEndTime;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        ProposalStatus status;
        bool executed;
        mapping(address => bool) hasVoted;
        mapping(address => uint8) voteChoice;
    }


    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256) public tokenBalances;
    mapping(address => bool) public isGovernanceMember;

    uint256 public totalSupply;
    uint256 public proposalCount;
    uint256 public votingPeriod;
    uint256 public proposalThreshold;
    uint256 public quorumPercentage;

    address public admin;
    string public daoName;


    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string title,
        string description,
        uint256 votingStartTime,
        uint256 votingEndTime
    );

    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        uint8 choice,
        uint256 weight
    );

    event ProposalExecuted(uint256 indexed proposalId);

    event TokensDistributed(address indexed recipient, uint256 amount);

    event MembershipGranted(address indexed member);

    event MembershipRevoked(address indexed member);


    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    modifier onlyGovernanceMember() {
        require(isGovernanceMember[msg.sender], "Only governance members can perform this action");
        _;
    }

    modifier validProposal(uint256 _proposalId) {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid proposal ID");
        _;
    }


    constructor(
        string memory _daoName,
        uint256 _votingPeriod,
        uint256 _proposalThreshold,
        uint256 _quorumPercentage
    ) {
        require(_votingPeriod > 0, "Voting period must be greater than 0");
        require(_quorumPercentage > 0 && _quorumPercentage <= 100, "Invalid quorum percentage");

        admin = msg.sender;
        daoName = _daoName;
        votingPeriod = _votingPeriod;
        proposalThreshold = _proposalThreshold;
        quorumPercentage = _quorumPercentage;


        isGovernanceMember[msg.sender] = true;
        emit MembershipGranted(msg.sender);
    }


    function distributeTokens(address _recipient, uint256 _amount) external onlyAdmin {
        require(_recipient != address(0), "Invalid recipient address");
        require(_amount > 0, "Amount must be greater than 0");

        tokenBalances[_recipient] += _amount;
        totalSupply += _amount;

        emit TokensDistributed(_recipient, _amount);
    }


    function grantMembership(address _member) external onlyAdmin {
        require(_member != address(0), "Invalid member address");
        require(!isGovernanceMember[_member], "Already a governance member");

        isGovernanceMember[_member] = true;
        emit MembershipGranted(_member);
    }


    function revokeMembership(address _member) external onlyAdmin {
        require(_member != address(0), "Invalid member address");
        require(isGovernanceMember[_member], "Not a governance member");
        require(_member != admin, "Cannot revoke admin membership");

        isGovernanceMember[_member] = false;
        emit MembershipRevoked(_member);
    }


    function createProposal(
        string memory _title,
        string memory _description
    ) external onlyGovernanceMember returns (uint256) {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_description).length > 0, "Description cannot be empty");
        require(tokenBalances[msg.sender] >= proposalThreshold, "Insufficient tokens to create proposal");

        proposalCount++;
        uint256 newProposalId = proposalCount;

        Proposal storage newProposal = proposals[newProposalId];
        newProposal.proposalId = newProposalId;
        newProposal.proposer = msg.sender;
        newProposal.title = _title;
        newProposal.description = _description;
        newProposal.votingStartTime = block.timestamp;
        newProposal.votingEndTime = block.timestamp + votingPeriod;
        newProposal.status = ProposalStatus.Active;
        newProposal.executed = false;

        emit ProposalCreated(
            newProposalId,
            msg.sender,
            _title,
            _description,
            newProposal.votingStartTime,
            newProposal.votingEndTime
        );

        return newProposalId;
    }


    function vote(uint256 _proposalId, uint8 _choice) external validProposal(_proposalId) onlyGovernanceMember {
        require(_choice <= 2, "Invalid vote choice");

        Proposal storage proposal = proposals[_proposalId];
        require(block.timestamp >= proposal.votingStartTime, "Voting has not started");
        require(block.timestamp <= proposal.votingEndTime, "Voting has ended");
        require(!proposal.hasVoted[msg.sender], "Already voted on this proposal");
        require(proposal.status == ProposalStatus.Active, "Proposal is not active");

        uint256 voterWeight = tokenBalances[msg.sender];
        require(voterWeight > 0, "No voting power");

        proposal.hasVoted[msg.sender] = true;
        proposal.voteChoice[msg.sender] = _choice;

        if (_choice == 0) {
            proposal.againstVotes += voterWeight;
        } else if (_choice == 1) {
            proposal.forVotes += voterWeight;
        } else {
            proposal.abstainVotes += voterWeight;
        }

        emit VoteCast(_proposalId, msg.sender, _choice, voterWeight);
    }


    function finalizeProposal(uint256 _proposalId) external validProposal(_proposalId) {
        Proposal storage proposal = proposals[_proposalId];
        require(block.timestamp > proposal.votingEndTime, "Voting period has not ended");
        require(proposal.status == ProposalStatus.Active, "Proposal is not active");

        uint256 totalVotes = proposal.forVotes + proposal.againstVotes + proposal.abstainVotes;
        uint256 requiredQuorum = (totalSupply * quorumPercentage) / 100;

        if (totalVotes >= requiredQuorum && proposal.forVotes > proposal.againstVotes) {
            proposal.status = ProposalStatus.Succeeded;
        } else {
            proposal.status = ProposalStatus.Defeated;
        }
    }


    function executeProposal(uint256 _proposalId) external validProposal(_proposalId) onlyAdmin {
        Proposal storage proposal = proposals[_proposalId];
        require(proposal.status == ProposalStatus.Succeeded, "Proposal has not succeeded");
        require(!proposal.executed, "Proposal already executed");

        proposal.executed = true;
        proposal.status = ProposalStatus.Executed;

        emit ProposalExecuted(_proposalId);
    }


    function getProposalDetails(uint256 _proposalId) external view validProposal(_proposalId) returns (
        address proposer,
        string memory title,
        string memory description,
        uint256 votingStartTime,
        uint256 votingEndTime,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 abstainVotes,
        ProposalStatus status,
        bool executed
    ) {
        Proposal storage proposal = proposals[_proposalId];
        return (
            proposal.proposer,
            proposal.title,
            proposal.description,
            proposal.votingStartTime,
            proposal.votingEndTime,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.abstainVotes,
            proposal.status,
            proposal.executed
        );
    }


    function hasVotedOnProposal(uint256 _proposalId, address _voter) external view validProposal(_proposalId) returns (bool) {
        return proposals[_proposalId].hasVoted[_voter];
    }


    function getVotingPower(address _voter) external view returns (uint256) {
        return tokenBalances[_voter];
    }


    function updateVotingPeriod(uint256 _newVotingPeriod) external onlyAdmin {
        require(_newVotingPeriod > 0, "Voting period must be greater than 0");
        votingPeriod = _newVotingPeriod;
    }


    function updateProposalThreshold(uint256 _newThreshold) external onlyAdmin {
        proposalThreshold = _newThreshold;
    }


    function updateQuorumPercentage(uint256 _newQuorumPercentage) external onlyAdmin {
        require(_newQuorumPercentage > 0 && _newQuorumPercentage <= 100, "Invalid quorum percentage");
        quorumPercentage = _newQuorumPercentage;
    }


    function transferAdminRole(address _newAdmin) external onlyAdmin {
        require(_newAdmin != address(0), "Invalid new admin address");
        require(_newAdmin != admin, "New admin is the same as current admin");

        admin = _newAdmin;
        isGovernanceMember[_newAdmin] = true;
        emit MembershipGranted(_newAdmin);
    }
}
