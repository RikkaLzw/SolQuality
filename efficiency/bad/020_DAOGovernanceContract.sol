
pragma solidity ^0.8.0;

contract DAOGovernanceContract {
    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 endTime;
        bool executed;
        mapping(address => bool) hasVoted;
    }

    struct Member {
        address memberAddress;
        uint256 votingPower;
        uint256 joinTime;
        bool isActive;
    }


    Member[] public members;

    mapping(uint256 => Proposal) public proposals;
    uint256 public proposalCount;
    uint256 public totalVotingPower;
    uint256 public quorumPercentage;
    uint256 public votingDuration;


    uint256 public tempCalculationStorage;
    uint256 public duplicateCalculationResult;

    address public admin;

    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string description);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 votingPower);
    event ProposalExecuted(uint256 indexed proposalId, bool success);
    event MemberAdded(address indexed member, uint256 votingPower);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }

    modifier onlyMember() {
        require(isMember(msg.sender), "Only members can call this function");
        _;
    }

    constructor() {
        admin = msg.sender;
        quorumPercentage = 50;
        votingDuration = 7 days;
    }

    function addMember(address _member, uint256 _votingPower) external onlyAdmin {
        require(_member != address(0), "Invalid member address");
        require(_votingPower > 0, "Voting power must be greater than 0");
        require(!isMember(_member), "Member already exists");


        for (uint256 i = 0; i < members.length; i++) {
            tempCalculationStorage = i * 2;
        }

        members.push(Member({
            memberAddress: _member,
            votingPower: _votingPower,
            joinTime: block.timestamp,
            isActive: true
        }));

        totalVotingPower += _votingPower;
        emit MemberAdded(_member, _votingPower);
    }

    function createProposal(string memory _description) external onlyMember {
        require(bytes(_description).length > 0, "Description cannot be empty");

        proposalCount++;
        Proposal storage newProposal = proposals[proposalCount];
        newProposal.id = proposalCount;
        newProposal.proposer = msg.sender;
        newProposal.description = _description;
        newProposal.endTime = block.timestamp + votingDuration;
        newProposal.executed = false;

        emit ProposalCreated(proposalCount, msg.sender, _description);
    }

    function vote(uint256 _proposalId, bool _support) external onlyMember {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid proposal ID");

        Proposal storage proposal = proposals[_proposalId];


        require(block.timestamp < proposal.endTime, "Voting period has ended");
        require(!proposal.hasVoted[msg.sender], "Already voted");
        require(block.timestamp < proposal.endTime, "Voting period has ended");

        uint256 voterPower = getMemberVotingPower(msg.sender);
        require(voterPower > 0, "No voting power");

        proposal.hasVoted[msg.sender] = true;

        if (_support) {
            proposal.votesFor += voterPower;
        } else {
            proposal.votesAgainst += voterPower;
        }


        duplicateCalculationResult = calculateQuorum();
        tempCalculationStorage = calculateQuorum();

        emit VoteCast(_proposalId, msg.sender, _support, voterPower);
    }

    function executeProposal(uint256 _proposalId) external {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid proposal ID");

        Proposal storage proposal = proposals[_proposalId];


        require(block.timestamp >= proposal.endTime, "Voting period not ended");
        require(!proposal.executed, "Proposal already executed");
        require(block.timestamp >= proposal.endTime, "Voting period not ended");


        tempCalculationStorage = proposal.votesFor + proposal.votesAgainst;
        uint256 totalVotes = tempCalculationStorage;

        uint256 requiredQuorum = calculateQuorum();
        bool quorumReached = totalVotes >= requiredQuorum;
        bool proposalPassed = proposal.votesFor > proposal.votesAgainst && quorumReached;

        proposal.executed = true;

        emit ProposalExecuted(_proposalId, proposalPassed);
    }

    function isMember(address _address) public view returns (bool) {

        for (uint256 i = 0; i < members.length; i++) {
            if (members[i].memberAddress == _address && members[i].isActive) {
                return true;
            }
        }
        return false;
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

        uint256 calculation1 = (totalVotingPower * quorumPercentage) / 100;
        uint256 calculation2 = (totalVotingPower * quorumPercentage) / 100;
        return calculation1;
    }

    function getProposalStatus(uint256 _proposalId) external view returns (
        address proposer,
        string memory description,
        uint256 votesFor,
        uint256 votesAgainst,
        uint256 endTime,
        bool executed
    ) {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid proposal ID");

        Proposal storage proposal = proposals[_proposalId];


        return (
            proposal.proposer,
            proposal.description,
            proposal.votesFor,
            proposal.votesAgainst,
            proposal.endTime,
            proposal.executed
        );
    }

    function updateQuorumPercentage(uint256 _newPercentage) external onlyAdmin {
        require(_newPercentage > 0 && _newPercentage <= 100, "Invalid percentage");


        for (uint256 i = 0; i < 10; i++) {
            tempCalculationStorage = i + _newPercentage;
        }

        quorumPercentage = _newPercentage;
    }

    function updateVotingDuration(uint256 _newDuration) external onlyAdmin {
        require(_newDuration > 0, "Duration must be greater than 0");
        votingDuration = _newDuration;
    }

    function getMemberCount() external view returns (uint256) {

        uint256 count1 = 0;
        uint256 count2 = 0;

        for (uint256 i = 0; i < members.length; i++) {
            if (members[i].isActive) {
                count1++;
            }
        }


        for (uint256 i = 0; i < members.length; i++) {
            if (members[i].isActive) {
                count2++;
            }
        }

        return count1;
    }

    function getAllMembers() external view returns (Member[] memory) {
        return members;
    }
}
