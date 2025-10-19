
pragma solidity ^0.8.0;

contract DAOGovernanceContract {

    uint256 public constant VOTING_PERIOD = 7;
    uint256 public constant QUORUM_PERCENTAGE = 51;
    uint256 public constant PROPOSAL_THRESHOLD = 1;


    string public constant DAO_TYPE = "GOVERNANCE";
    string public constant VERSION = "1.0.0";

    struct Proposal {
        uint256 id;
        string title;
        string description;
        address proposer;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 startTime;
        uint256 endTime;
        uint256 executed;
        bytes callData;
        address target;
    }

    struct Member {
        address memberAddress;
        uint256 votingPower;
        uint256 joinTime;
        uint256 isActive;
        string memberType;
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(address => Member) public members;
    mapping(uint256 => mapping(address => uint256)) public hasVoted;
    mapping(address => uint256) public membershipStatus;

    uint256 public proposalCount;
    uint256 public totalMembers;
    uint256 public totalVotingPower;
    address public admin;


    bytes public daoIdentifier;

    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string title);
    event VoteCast(uint256 indexed proposalId, address indexed voter, uint256 support, uint256 votingPower);
    event ProposalExecuted(uint256 indexed proposalId);
    event MemberAdded(address indexed member, uint256 votingPower);
    event MemberRemoved(address indexed member);

    modifier onlyMember() {
        require(membershipStatus[msg.sender] == 1, "Not a member");
        require(members[msg.sender].isActive == 1, "Member not active");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }

    modifier validProposal(uint256 _proposalId) {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid proposal ID");
        _;
    }

    constructor(string memory _daoName, bytes memory _identifier) {
        admin = msg.sender;
        daoIdentifier = _identifier;


        members[msg.sender] = Member({
            memberAddress: msg.sender,
            votingPower: uint256(100),
            joinTime: block.timestamp,
            isActive: uint256(1),
            memberType: "ADMIN"
        });

        membershipStatus[msg.sender] = uint256(1);
        totalMembers = uint256(1);
        totalVotingPower = uint256(100);
    }

    function addMember(address _member, uint256 _votingPower, string memory _memberType) external onlyAdmin {
        require(membershipStatus[_member] == 0, "Already a member");
        require(_votingPower > 0, "Voting power must be positive");

        members[_member] = Member({
            memberAddress: _member,
            votingPower: _votingPower,
            joinTime: block.timestamp,
            isActive: uint256(1),
            memberType: _memberType
        });

        membershipStatus[_member] = uint256(1);
        totalMembers += uint256(1);
        totalVotingPower += _votingPower;

        emit MemberAdded(_member, _votingPower);
    }

    function removeMember(address _member) external onlyAdmin {
        require(membershipStatus[_member] == 1, "Not a member");
        require(_member != admin, "Cannot remove admin");

        totalVotingPower -= members[_member].votingPower;
        totalMembers -= uint256(1);

        members[_member].isActive = uint256(0);
        membershipStatus[_member] = uint256(0);

        emit MemberRemoved(_member);
    }

    function createProposal(
        string memory _title,
        string memory _description,
        address _target,
        bytes memory _callData
    ) external onlyMember returns (uint256) {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(_target != address(0), "Invalid target address");


        uint256 requiredPower = (totalVotingPower * PROPOSAL_THRESHOLD) / uint256(100);
        require(members[msg.sender].votingPower >= requiredPower, "Insufficient voting power");

        proposalCount += uint256(1);

        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + (VOTING_PERIOD * uint256(1 days));

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
            callData: _callData,
            target: _target
        });

        emit ProposalCreated(proposalCount, msg.sender, _title);
        return proposalCount;
    }

    function vote(uint256 _proposalId, uint256 _support) external onlyMember validProposal(_proposalId) {
        Proposal storage proposal = proposals[_proposalId];
        require(block.timestamp >= proposal.startTime, "Voting not started");
        require(block.timestamp <= proposal.endTime, "Voting ended");
        require(hasVoted[_proposalId][msg.sender] == 0, "Already voted");
        require(proposal.executed == 0, "Proposal already executed");
        require(_support <= uint256(1), "Invalid vote option");

        uint256 votingPower = members[msg.sender].votingPower;
        hasVoted[_proposalId][msg.sender] = uint256(1);

        if (_support == uint256(1)) {
            proposal.forVotes += votingPower;
        } else {
            proposal.againstVotes += votingPower;
        }

        emit VoteCast(_proposalId, msg.sender, _support, votingPower);
    }

    function executeProposal(uint256 _proposalId) external validProposal(_proposalId) {
        Proposal storage proposal = proposals[_proposalId];
        require(block.timestamp > proposal.endTime, "Voting still active");
        require(proposal.executed == 0, "Already executed");

        uint256 totalVotes = proposal.forVotes + proposal.againstVotes;
        uint256 requiredQuorum = (totalVotingPower * QUORUM_PERCENTAGE) / uint256(100);

        require(totalVotes >= requiredQuorum, "Quorum not reached");
        require(proposal.forVotes > proposal.againstVotes, "Proposal rejected");

        proposal.executed = uint256(1);


        if (proposal.target != address(0) && proposal.callData.length > 0) {
            (bool success,) = proposal.target.call(proposal.callData);
            require(success, "Proposal execution failed");
        }

        emit ProposalExecuted(_proposalId);
    }

    function getProposal(uint256 _proposalId) external view validProposal(_proposalId) returns (
        uint256 id,
        string memory title,
        string memory description,
        address proposer,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 startTime,
        uint256 endTime,
        uint256 executed,
        address target
    ) {
        Proposal storage proposal = proposals[_proposalId];
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
            proposal.target
        );
    }

    function getMember(address _member) external view returns (
        address memberAddress,
        uint256 votingPower,
        uint256 joinTime,
        uint256 isActive,
        string memory memberType
    ) {
        Member storage member = members[_member];
        return (
            member.memberAddress,
            member.votingPower,
            member.joinTime,
            member.isActive,
            member.memberType
        );
    }

    function getVotingStatus(uint256 _proposalId, address _voter) external view validProposal(_proposalId) returns (uint256) {
        return hasVoted[_proposalId][_voter];
    }

    function updateDaoIdentifier(bytes memory _newIdentifier) external onlyAdmin {
        daoIdentifier = _newIdentifier;
    }

    function transferAdmin(address _newAdmin) external onlyAdmin {
        require(_newAdmin != address(0), "Invalid address");
        require(membershipStatus[_newAdmin] == 1, "New admin must be a member");

        admin = _newAdmin;
        members[_newAdmin].memberType = "ADMIN";
    }
}
