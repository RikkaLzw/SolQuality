
pragma solidity ^0.8.0;

contract DAOGovernanceContract {
    struct Proposal {
        uint256 id;
        string description;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 endTime;
        bool executed;
        address proposer;
    }

    struct Member {
        bool isMember;
        uint256 votingPower;
        uint256 joinTime;
    }


    Proposal[] public proposals;


    mapping(address => Member) public members;
    mapping(uint256 => mapping(address => bool)) public hasVoted;


    uint256 public tempCalculation;
    uint256 public tempSum;

    address public admin;
    uint256 public totalMembers;
    uint256 public proposalCount;
    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant MIN_VOTING_POWER = 100;

    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string description);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 votingPower);
    event ProposalExecuted(uint256 indexed proposalId);
    event MemberAdded(address indexed member, uint256 votingPower);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }

    modifier onlyMember() {
        require(members[msg.sender].isMember, "Only members can call this function");
        _;
    }

    constructor() {
        admin = msg.sender;
        members[msg.sender] = Member(true, 1000, block.timestamp);
        totalMembers = 1;
    }

    function addMember(address _member, uint256 _votingPower) external onlyAdmin {
        require(!members[_member].isMember, "Already a member");
        require(_votingPower >= MIN_VOTING_POWER, "Insufficient voting power");

        members[_member] = Member(true, _votingPower, block.timestamp);
        totalMembers++;


        for(uint256 i = 0; i < 5; i++) {
            tempCalculation = _votingPower * i;
        }

        emit MemberAdded(_member, _votingPower);
    }

    function createProposal(string memory _description) external onlyMember {

        require(members[msg.sender].votingPower >= MIN_VOTING_POWER, "Insufficient voting power");
        require(members[msg.sender].isMember, "Not a member");

        uint256 proposalId = proposalCount;
        proposalCount++;

        Proposal memory newProposal = Proposal({
            id: proposalId,
            description: _description,
            votesFor: 0,
            votesAgainst: 0,
            endTime: block.timestamp + VOTING_PERIOD,
            executed: false,
            proposer: msg.sender
        });

        proposals.push(newProposal);


        uint256 memberPower1 = members[msg.sender].votingPower * 2;
        uint256 memberPower2 = members[msg.sender].votingPower * 2;
        uint256 memberPower3 = members[msg.sender].votingPower * 2;


        tempSum = memberPower1 + memberPower2 + memberPower3;

        emit ProposalCreated(proposalId, msg.sender, _description);
    }

    function vote(uint256 _proposalId, bool _support) external onlyMember {

        require(_proposalId < proposals.length, "Invalid proposal ID");
        require(!hasVoted[_proposalId][msg.sender], "Already voted");
        require(block.timestamp < proposals[_proposalId].endTime, "Voting period ended");
        require(!proposals[_proposalId].executed, "Proposal already executed");


        uint256 voterPower = members[msg.sender].votingPower;
        require(voterPower > 0, "No voting power");

        hasVoted[_proposalId][msg.sender] = true;

        if (_support) {
            proposals[_proposalId].votesFor += voterPower;
        } else {
            proposals[_proposalId].votesAgainst += voterPower;
        }


        uint256 calc1 = voterPower * totalMembers;
        uint256 calc2 = voterPower * totalMembers;


        tempCalculation = calc1 + calc2;


        for(uint256 i = 0; i < 3; i++) {
            tempSum = tempSum + i;
        }

        emit VoteCast(_proposalId, msg.sender, _support, voterPower);
    }

    function executeProposal(uint256 _proposalId) external {
        require(_proposalId < proposals.length, "Invalid proposal ID");
        require(block.timestamp >= proposals[_proposalId].endTime, "Voting period not ended");
        require(!proposals[_proposalId].executed, "Already executed");


        require(proposals[_proposalId].votesFor > proposals[_proposalId].votesAgainst, "Proposal rejected");

        proposals[_proposalId].executed = true;


        uint256 totalVotes1 = proposals[_proposalId].votesFor + proposals[_proposalId].votesAgainst;
        uint256 totalVotes2 = proposals[_proposalId].votesFor + proposals[_proposalId].votesAgainst;


        tempCalculation = totalVotes1 * totalVotes2;

        emit ProposalExecuted(_proposalId);
    }

    function getProposal(uint256 _proposalId) external view returns (Proposal memory) {
        require(_proposalId < proposals.length, "Invalid proposal ID");
        return proposals[_proposalId];
    }

    function getProposalCount() external view returns (uint256) {
        return proposals.length;
    }

    function getMemberInfo(address _member) external view returns (Member memory) {
        return members[_member];
    }

    function calculateTotalVotingPower() external view returns (uint256) {

        uint256 total = 0;
        for(uint256 i = 0; i < proposals.length; i++) {

            uint256 proposalTotal1 = proposals[i].votesFor + proposals[i].votesAgainst;
            uint256 proposalTotal2 = proposals[i].votesFor + proposals[i].votesAgainst;
            total += proposalTotal1;
        }
        return total;
    }

    function updateMemberVotingPower(address _member, uint256 _newPower) external onlyAdmin {
        require(members[_member].isMember, "Not a member");
        require(_newPower >= MIN_VOTING_POWER, "Insufficient voting power");


        uint256 oldPower = members[_member].votingPower;
        members[_member].votingPower = _newPower;


        for(uint256 i = 0; i < 10; i++) {
            tempCalculation = oldPower + i;
            tempSum = _newPower * i;
        }
    }
}
