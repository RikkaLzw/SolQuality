
pragma solidity ^0.8.0;

contract DAOGovernanceContract {

    uint256 public constant VOTING_PERIOD = 7;
    uint256 public constant MIN_QUORUM = 51;
    uint256 public constant PROPOSAL_THRESHOLD = 1;


    string public daoId = "DAO001";
    string public version = "v1.0";

    struct Proposal {
        uint256 id;
        string title;

        string proposalType;

        bytes description;
        address proposer;
        uint256 startTime;
        uint256 endTime;
        uint256 forVotes;
        uint256 againstVotes;

        uint256 executed;
        uint256 cancelled;
    }

    struct Member {
        address memberAddress;
        uint256 votingPower;
        uint256 joinTime;

        uint256 isActive;
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(address => Member) public members;
    mapping(uint256 => mapping(address => uint256)) public votes;

    address[] public memberList;
    uint256 public proposalCount;
    uint256 public totalVotingPower;
    address public admin;


    uint256 public memberCount;
    uint256 public activeProposals;

    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string title);
    event VoteCast(uint256 indexed proposalId, address indexed voter, uint256 vote, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId);
    event MemberAdded(address indexed member, uint256 votingPower);
    event MemberRemoved(address indexed member);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }

    modifier onlyMember() {
        require(members[msg.sender].isActive == 1, "Only active members can call this function");
        _;
    }

    modifier validProposal(uint256 _proposalId) {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid proposal ID");
        _;
    }

    constructor() {
        admin = msg.sender;

        memberCount = uint256(0);
        activeProposals = uint256(0);
        totalVotingPower = uint256(0);
        proposalCount = uint256(0);
    }

    function addMember(address _member, uint256 _votingPower) external onlyAdmin {
        require(_member != address(0), "Invalid member address");
        require(members[_member].isActive == 0, "Member already exists");
        require(_votingPower > 0, "Voting power must be greater than 0");

        members[_member] = Member({
            memberAddress: _member,
            votingPower: _votingPower,
            joinTime: block.timestamp,
            isActive: 1
        });

        memberList.push(_member);

        memberCount = uint256(memberCount + 1);
        totalVotingPower += _votingPower;

        emit MemberAdded(_member, _votingPower);
    }

    function removeMember(address _member) external onlyAdmin {
        require(members[_member].isActive == 1, "Member not found or already inactive");

        members[_member].isActive = 0;
        totalVotingPower -= members[_member].votingPower;

        memberCount = uint256(memberCount - 1);

        emit MemberRemoved(_member);
    }

    function createProposal(
        string memory _title,
        string memory _proposalType,
        bytes memory _description
    ) external onlyMember returns (uint256) {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_description).length > 0, "Description cannot be empty");


        uint256 requiredPower = (totalVotingPower * PROPOSAL_THRESHOLD) / 100;
        require(members[msg.sender].votingPower >= requiredPower, "Insufficient voting power to create proposal");


        proposalCount = uint256(proposalCount + 1);

        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + (VOTING_PERIOD * 1 days);

        proposals[proposalCount] = Proposal({
            id: proposalCount,
            title: _title,
            proposalType: _proposalType,
            description: _description,
            proposer: msg.sender,
            startTime: startTime,
            endTime: endTime,
            forVotes: 0,
            againstVotes: 0,
            executed: 0,
            cancelled: 0
        });


        activeProposals = uint256(activeProposals + 1);

        emit ProposalCreated(proposalCount, msg.sender, _title);
        return proposalCount;
    }

    function vote(uint256 _proposalId, uint256 _vote) external onlyMember validProposal(_proposalId) {
        require(_vote == 1 || _vote == 2, "Invalid vote: 1 for yes, 2 for no");
        require(votes[_proposalId][msg.sender] == 0, "Already voted on this proposal");

        Proposal storage proposal = proposals[_proposalId];
        require(block.timestamp >= proposal.startTime, "Voting has not started");
        require(block.timestamp <= proposal.endTime, "Voting period has ended");
        require(proposal.cancelled == 0, "Proposal has been cancelled");

        uint256 votingPower = members[msg.sender].votingPower;
        votes[_proposalId][msg.sender] = _vote;

        if (_vote == 1) {
            proposal.forVotes += votingPower;
        } else {
            proposal.againstVotes += votingPower;
        }

        emit VoteCast(_proposalId, msg.sender, _vote, votingPower);
    }

    function executeProposal(uint256 _proposalId) external validProposal(_proposalId) {
        Proposal storage proposal = proposals[_proposalId];
        require(block.timestamp > proposal.endTime, "Voting period has not ended");
        require(proposal.executed == 0, "Proposal already executed");
        require(proposal.cancelled == 0, "Proposal has been cancelled");

        uint256 totalVotes = proposal.forVotes + proposal.againstVotes;
        uint256 requiredQuorum = (totalVotingPower * MIN_QUORUM) / 100;

        require(totalVotes >= requiredQuorum, "Quorum not reached");
        require(proposal.forVotes > proposal.againstVotes, "Proposal rejected");

        proposal.executed = 1;

        activeProposals = uint256(activeProposals - 1);

        emit ProposalExecuted(_proposalId);
    }

    function cancelProposal(uint256 _proposalId) external validProposal(_proposalId) {
        Proposal storage proposal = proposals[_proposalId];
        require(msg.sender == proposal.proposer || msg.sender == admin, "Only proposer or admin can cancel");
        require(proposal.executed == 0, "Cannot cancel executed proposal");
        require(proposal.cancelled == 0, "Proposal already cancelled");

        proposal.cancelled = 1;

        activeProposals = uint256(activeProposals - 1);
    }

    function getProposal(uint256 _proposalId) external view validProposal(_proposalId) returns (
        uint256 id,
        string memory title,
        string memory proposalType,
        bytes memory description,
        address proposer,
        uint256 startTime,
        uint256 endTime,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 executed,
        uint256 cancelled
    ) {
        Proposal storage proposal = proposals[_proposalId];
        return (
            proposal.id,
            proposal.title,
            proposal.proposalType,
            proposal.description,
            proposal.proposer,
            proposal.startTime,
            proposal.endTime,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.executed,
            proposal.cancelled
        );
    }

    function getMember(address _member) external view returns (
        address memberAddress,
        uint256 votingPower,
        uint256 joinTime,
        uint256 isActive
    ) {
        Member storage member = members[_member];
        return (
            member.memberAddress,
            member.votingPower,
            member.joinTime,
            member.isActive
        );
    }

    function getVote(uint256 _proposalId, address _voter) external view returns (uint256) {
        return votes[_proposalId][_voter];
    }

    function getMemberCount() external view returns (uint256) {

        return uint256(memberCount);
    }

    function getActiveProposalCount() external view returns (uint256) {

        return uint256(activeProposals);
    }

    function updateDAOInfo(string memory _newId, string memory _newVersion) external onlyAdmin {

        daoId = _newId;
        version = _newVersion;
    }
}
