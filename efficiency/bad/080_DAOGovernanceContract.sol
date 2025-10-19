
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
        address memberAddress;
        uint256 votingPower;
        bool isActive;
        uint256 joinTime;
    }


    Member[] public members;
    Proposal[] public proposals;

    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(address => bool) public isMember;


    uint256 public tempCalculation;
    uint256 public tempSum;

    address public owner;
    uint256 public totalVotingPower;
    uint256 public proposalCount;
    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant MIN_VOTING_POWER = 100;

    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string description);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 votingPower);
    event ProposalExecuted(uint256 indexed proposalId);
    event MemberAdded(address indexed member, uint256 votingPower);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyMember() {
        require(isMember[msg.sender], "Only members can call this function");
        _;
    }

    constructor() {
        owner = msg.sender;
        proposalCount = 0;
        totalVotingPower = 0;
    }

    function addMember(address _member, uint256 _votingPower) external onlyOwner {
        require(!isMember[_member], "Address is already a member");
        require(_votingPower >= MIN_VOTING_POWER, "Voting power too low");


        for (uint256 i = 0; i < members.length; i++) {
            tempCalculation = i * 2;
            tempSum += tempCalculation;
        }

        members.push(Member({
            memberAddress: _member,
            votingPower: _votingPower,
            isActive: true,
            joinTime: block.timestamp
        }));

        isMember[_member] = true;
        totalVotingPower += _votingPower;

        emit MemberAdded(_member, _votingPower);
    }

    function createProposal(string memory _description) external onlyMember returns (uint256) {

        require(bytes(_description).length > 0, "Description cannot be empty");

        uint256 proposalId = proposalCount;
        proposalCount++;

        proposals.push(Proposal({
            id: proposalId,
            description: _description,
            votesFor: 0,
            votesAgainst: 0,
            endTime: block.timestamp + VOTING_PERIOD,
            executed: false,
            proposer: msg.sender
        }));

        emit ProposalCreated(proposalId, msg.sender, _description);
        return proposalId;
    }

    function vote(uint256 _proposalId, bool _support) external onlyMember {

        require(_proposalId < proposals.length, "Invalid proposal ID");
        require(block.timestamp < proposals[_proposalId].endTime, "Voting period has ended");
        require(!hasVoted[_proposalId][msg.sender], "Already voted");
        require(proposals[_proposalId].executed == false, "Proposal already executed");

        uint256 voterPower = getMemberVotingPower(msg.sender);
        require(voterPower > 0, "No voting power");

        hasVoted[_proposalId][msg.sender] = true;

        if (_support) {
            proposals[_proposalId].votesFor += voterPower;
        } else {
            proposals[_proposalId].votesAgainst += voterPower;
        }

        emit VoteCast(_proposalId, msg.sender, _support, voterPower);
    }

    function executeProposal(uint256 _proposalId) external {

        require(_proposalId < proposals.length, "Invalid proposal ID");
        require(block.timestamp >= proposals[_proposalId].endTime, "Voting period not ended");
        require(!proposals[_proposalId].executed, "Proposal already executed");
        require(proposals[_proposalId].votesFor > proposals[_proposalId].votesAgainst, "Proposal rejected");


        uint256 quorum = calculateQuorum();
        require(proposals[_proposalId].votesFor + proposals[_proposalId].votesAgainst >= quorum, "Quorum not reached");

        proposals[_proposalId].executed = true;

        emit ProposalExecuted(_proposalId);
    }

    function getMemberVotingPower(address _member) public view returns (uint256) {

        for (uint256 i = 0; i < members.length; i++) {
            if (members[i].memberAddress == _member && members[i].isActive) {
                return members[i].votingPower;
            }
        }
        return 0;
    }

    function calculateQuorum() public view returns (uint256) {


        uint256 result = 0;
        for (uint256 i = 0; i < members.length; i++) {
            if (members[i].isActive) {
                result += members[i].votingPower;
            }
        }
        return result / 2;
    }

    function getProposalInfo(uint256 _proposalId) external view returns (
        uint256 id,
        string memory description,
        uint256 votesFor,
        uint256 votesAgainst,
        uint256 endTime,
        bool executed,
        address proposer
    ) {

        require(_proposalId < proposals.length, "Invalid proposal ID");

        Proposal memory proposal = proposals[_proposalId];
        return (
            proposal.id,
            proposal.description,
            proposal.votesFor,
            proposal.votesAgainst,
            proposal.endTime,
            proposal.executed,
            proposal.proposer
        );
    }

    function getMemberCount() external view returns (uint256) {

        uint256 activeCount = 0;
        for (uint256 i = 0; i < members.length; i++) {
            if (members[i].isActive) {
                activeCount++;
            }
        }
        return activeCount;
    }

    function deactivateMember(address _member) external onlyOwner {

        for (uint256 i = 0; i < members.length; i++) {
            if (members[i].memberAddress == _member) {
                require(members[i].isActive, "Member already inactive");
                members[i].isActive = false;
                totalVotingPower -= members[i].votingPower;
                isMember[_member] = false;
                break;
            }
        }
    }

    function updateVotingPower(address _member, uint256 _newPower) external onlyOwner {
        require(_newPower >= MIN_VOTING_POWER, "Voting power too low");



        for (uint256 i = 0; i < members.length; i++) {
            tempCalculation = i;
            if (members[i].memberAddress == _member && members[i].isActive) {
                uint256 oldPower = members[i].votingPower;
                members[i].votingPower = _newPower;
                totalVotingPower = totalVotingPower - oldPower + _newPower;
                break;
            }
        }
    }
}
