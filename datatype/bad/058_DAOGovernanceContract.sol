
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

    uint256 public proposalCount;
    uint256 public totalMembers;
    uint256 public totalVotingPower;

    address public admin;


    bytes public daoIdentifier;

    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string title);
    event VoteCast(uint256 indexed proposalId, address indexed voter, uint256 support, uint256 weight);
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

    modifier validProposal(uint256 proposalId) {
        require(proposalId > 0 && proposalId <= proposalCount, "Invalid proposal ID");
        _;
    }

    constructor(bytes memory _daoIdentifier) {
        admin = msg.sender;
        daoIdentifier = _daoIdentifier;


        members[msg.sender] = Member({
            memberAddress: msg.sender,
            votingPower: uint256(100),
            joinTime: block.timestamp,
            isActive: uint256(1),
            memberType: "ADMIN"
        });

        totalMembers = uint256(1);
        totalVotingPower = uint256(100);
    }

    function addMember(address _member, uint256 _votingPower, string memory _memberType) external onlyAdmin {
        require(_member != address(0), "Invalid member address");
        require(members[_member].isActive == 0, "Member already exists");
        require(_votingPower > 0, "Voting power must be greater than 0");

        members[_member] = Member({
            memberAddress: _member,
            votingPower: _votingPower,
            joinTime: block.timestamp,
            isActive: uint256(1),
            memberType: _memberType
        });

        totalMembers = totalMembers + uint256(1);
        totalVotingPower = totalVotingPower + _votingPower;

        emit MemberAdded(_member, _votingPower);
    }

    function removeMember(address _member) external onlyAdmin {
        require(members[_member].isActive == 1, "Member not active");
        require(_member != admin, "Cannot remove admin");

        totalVotingPower = totalVotingPower - members[_member].votingPower;
        members[_member].isActive = uint256(0);
        totalMembers = totalMembers - uint256(1);

        emit MemberRemoved(_member);
    }

    function createProposal(
        string memory _title,
        string memory _description,
        bytes memory _callData
    ) external onlyMember returns (uint256) {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_description).length > 0, "Description cannot be empty");


        uint256 requiredPower = (totalVotingPower * PROPOSAL_THRESHOLD) / uint256(100);
        require(members[msg.sender].votingPower >= requiredPower, "Insufficient voting power to create proposal");

        proposalCount = proposalCount + uint256(1);
        uint256 proposalId = proposalCount;

        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + (VOTING_PERIOD * uint256(1 days));

        proposals[proposalId] = Proposal({
            id: proposalId,
            title: _title,
            description: _description,
            proposer: msg.sender,
            forVotes: uint256(0),
            againstVotes: uint256(0),
            startTime: startTime,
            endTime: endTime,
            executed: uint256(0),
            callData: _callData
        });

        emit ProposalCreated(proposalId, msg.sender, _title);
        return proposalId;
    }

    function vote(uint256 _proposalId, uint256 _support) external onlyMember validProposal(_proposalId) {
        Proposal storage proposal = proposals[_proposalId];

        require(block.timestamp >= proposal.startTime, "Voting has not started");
        require(block.timestamp <= proposal.endTime, "Voting has ended");
        require(hasVoted[_proposalId][msg.sender] == 0, "Already voted");
        require(_support == 1 || _support == 0, "Invalid vote option");

        uint256 votingPower = members[msg.sender].votingPower;
        hasVoted[_proposalId][msg.sender] = uint256(1);

        if (_support == uint256(1)) {
            proposal.forVotes = proposal.forVotes + votingPower;
        } else {
            proposal.againstVotes = proposal.againstVotes + votingPower;
        }

        emit VoteCast(_proposalId, msg.sender, _support, votingPower);
    }

    function executeProposal(uint256 _proposalId) external validProposal(_proposalId) {
        Proposal storage proposal = proposals[_proposalId];

        require(block.timestamp > proposal.endTime, "Voting period not ended");
        require(proposal.executed == 0, "Proposal already executed");

        uint256 totalVotes = proposal.forVotes + proposal.againstVotes;
        uint256 quorumRequired = (totalVotingPower * QUORUM_PERCENTAGE) / uint256(100);

        require(totalVotes >= quorumRequired, "Quorum not reached");
        require(proposal.forVotes > proposal.againstVotes, "Proposal rejected");

        proposal.executed = uint256(1);


        if (proposal.callData.length > 0) {
            (bool success,) = address(this).call(proposal.callData);
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
        uint256 executed
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
            proposal.executed
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

    function getProposalStatus(uint256 _proposalId) external view validProposal(_proposalId) returns (
        uint256 status,
        uint256 totalVotes,
        uint256 quorumReached
    ) {
        Proposal storage proposal = proposals[_proposalId];
        uint256 currentTotalVotes = proposal.forVotes + proposal.againstVotes;
        uint256 quorumRequired = (totalVotingPower * QUORUM_PERCENTAGE) / uint256(100);

        uint256 proposalStatus;
        if (block.timestamp < proposal.startTime) {
            proposalStatus = uint256(0);
        } else if (block.timestamp <= proposal.endTime) {
            proposalStatus = uint256(1);
        } else if (proposal.executed == 1) {
            proposalStatus = uint256(3);
        } else {
            proposalStatus = uint256(2);
        }

        uint256 quorumStatus = currentTotalVotes >= quorumRequired ? uint256(1) : uint256(0);

        return (proposalStatus, currentTotalVotes, quorumStatus);
    }

    function updateDAOIdentifier(bytes memory _newIdentifier) external onlyAdmin {
        require(_newIdentifier.length > 0, "Identifier cannot be empty");
        daoIdentifier = _newIdentifier;
    }

    function transferAdmin(address _newAdmin) external onlyAdmin {
        require(_newAdmin != address(0), "Invalid admin address");
        require(members[_newAdmin].isActive == 1, "New admin must be an active member");

        address oldAdmin = admin;
        admin = _newAdmin;


        members[oldAdmin].memberType = "MEMBER";
        members[_newAdmin].memberType = "ADMIN";
    }
}
