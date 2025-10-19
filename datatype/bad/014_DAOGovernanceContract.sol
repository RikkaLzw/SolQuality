
pragma solidity ^0.8.0;

contract DAOGovernanceContract {

    uint256 public proposalCount;
    uint256 public votingPeriod = 7;
    uint256 public quorumPercentage = 51;
    uint256 public proposalThreshold = 1000;


    string public daoId = "DAO001";
    string public version = "v1.0";

    struct Proposal {
        uint256 id;
        string title;
        bytes description;
        address proposer;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 startTime;
        uint256 endTime;
        uint256 executed;
        uint256 cancelled;
        bytes targetContract;
        bytes callData;
    }

    struct Member {
        uint256 tokenBalance;
        uint256 isActive;
        uint256 joinTime;
        string memberId;
        uint256 votingPower;
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(address => Member) public members;
    mapping(uint256 => mapping(address => uint256)) public votes;
    mapping(uint256 => mapping(address => uint256)) public voteChoices;

    address public admin;
    uint256 public totalSupply;
    string public tokenName = "DAOToken";
    string public tokenSymbol = "DAO";


    uint256 public constant MIN_VOTING_PERIOD = 1;
    uint256 public constant MAX_VOTING_PERIOD = 30;

    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string title);
    event VoteCast(address indexed voter, uint256 indexed proposalId, uint256 choice, uint256 votes);
    event ProposalExecuted(uint256 indexed proposalId);
    event MemberAdded(address indexed member, string memberId);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }

    modifier onlyMember() {

        require(uint256(members[msg.sender].isActive) == uint256(1), "Only active members can call this function");
        _;
    }

    constructor() {
        admin = msg.sender;

        proposalCount = uint256(0);
        totalSupply = uint256(1000000);


        members[admin] = Member({
            tokenBalance: uint256(100000),
            isActive: uint256(1),
            joinTime: block.timestamp,
            memberId: "ADMIN001",
            votingPower: uint256(100000)
        });
    }

    function addMember(address _member, string memory _memberId, uint256 _tokenBalance) external onlyAdmin {
        require(_member != address(0), "Invalid member address");

        require(uint256(members[_member].isActive) == uint256(0), "Member already exists");

        members[_member] = Member({
            tokenBalance: _tokenBalance,
            isActive: uint256(1),
            joinTime: block.timestamp,
            memberId: _memberId,
            votingPower: _tokenBalance
        });

        emit MemberAdded(_member, _memberId);
    }

    function createProposal(
        string memory _title,
        bytes memory _description,
        bytes memory _targetContract,
        bytes memory _callData
    ) external onlyMember {
        require(members[msg.sender].tokenBalance >= proposalThreshold, "Insufficient tokens to create proposal");


        proposalCount = uint256(proposalCount + 1);

        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + (votingPeriod * 1 days);

        proposals[proposalCount] = Proposal({
            id: proposalCount,
            title: _title,
            description: _description,
            proposer: msg.sender,
            forVotes: uint256(0),
            againstVotes: uint256(0),
            startTime: startTime,
            endTime: endTime,
            executed: uint256(0),
            cancelled: uint256(0),
            targetContract: _targetContract,
            callData: _callData
        });

        emit ProposalCreated(proposalCount, msg.sender, _title);
    }

    function vote(uint256 _proposalId, uint256 _choice) external onlyMember {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid proposal ID");
        require(_choice == 0 || _choice == 1, "Invalid vote choice");

        Proposal storage proposal = proposals[_proposalId];
        require(block.timestamp >= proposal.startTime, "Voting has not started");
        require(block.timestamp <= proposal.endTime, "Voting has ended");

        require(uint256(votes[_proposalId][msg.sender]) == uint256(0), "Already voted");

        uint256 votingPower = members[msg.sender].votingPower;


        votes[_proposalId][msg.sender] = uint256(1);
        voteChoices[_proposalId][msg.sender] = _choice;

        if (_choice == 1) {
            proposal.forVotes += votingPower;
        } else {
            proposal.againstVotes += votingPower;
        }

        emit VoteCast(msg.sender, _proposalId, _choice, votingPower);
    }

    function executeProposal(uint256 _proposalId) external {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid proposal ID");

        Proposal storage proposal = proposals[_proposalId];
        require(block.timestamp > proposal.endTime, "Voting period not ended");

        require(uint256(proposal.executed) == uint256(0), "Proposal already executed");
        require(uint256(proposal.cancelled) == uint256(0), "Proposal cancelled");

        uint256 totalVotes = proposal.forVotes + proposal.againstVotes;
        uint256 requiredQuorum = (totalSupply * quorumPercentage) / 100;

        require(totalVotes >= requiredQuorum, "Quorum not reached");
        require(proposal.forVotes > proposal.againstVotes, "Proposal rejected");


        proposal.executed = uint256(1);

        emit ProposalExecuted(_proposalId);
    }

    function cancelProposal(uint256 _proposalId) external {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid proposal ID");

        Proposal storage proposal = proposals[_proposalId];
        require(msg.sender == proposal.proposer || msg.sender == admin, "Not authorized");

        require(uint256(proposal.executed) == uint256(0), "Cannot cancel executed proposal");
        require(uint256(proposal.cancelled) == uint256(0), "Already cancelled");


        proposal.cancelled = uint256(1);
    }

    function updateVotingPeriod(uint256 _newPeriod) external onlyAdmin {
        require(_newPeriod >= MIN_VOTING_PERIOD && _newPeriod <= MAX_VOTING_PERIOD, "Invalid voting period");
        votingPeriod = _newPeriod;
    }

    function updateQuorumPercentage(uint256 _newQuorum) external onlyAdmin {

        require(_newQuorum > 0 && _newQuorum <= 100, "Invalid quorum percentage");
        quorumPercentage = _newQuorum;
    }

    function getProposal(uint256 _proposalId) external view returns (
        uint256 id,
        string memory title,
        bytes memory description,
        address proposer,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 startTime,
        uint256 endTime,
        uint256 executed,
        uint256 cancelled
    ) {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid proposal ID");

        Proposal memory proposal = proposals[_proposalId];
        return (
            proposal.id,
            proposal.title,
            proposal.description,
            proposal.proposer,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.startTime,
            proposal.endTime,
            proposal.executed,
            proposal.cancelled
        );
    }

    function getMemberInfo(address _member) external view returns (
        uint256 tokenBalance,
        uint256 isActive,
        uint256 joinTime,
        string memory memberId,
        uint256 votingPower
    ) {
        Member memory member = members[_member];
        return (
            member.tokenBalance,
            member.isActive,
            member.joinTime,
            member.memberId,
            member.votingPower
        );
    }

    function hasVoted(uint256 _proposalId, address _voter) external view returns (uint256) {

        return votes[_proposalId][_voter];
    }

    function getVoteChoice(uint256 _proposalId, address _voter) external view returns (uint256) {
        return voteChoices[_proposalId][_voter];
    }
}
