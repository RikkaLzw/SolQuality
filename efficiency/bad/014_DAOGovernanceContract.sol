
pragma solidity ^0.8.0;

contract DAOGovernanceContract {
    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 deadline;
        bool executed;
        mapping(address => bool) hasVoted;
    }

    struct Member {
        address memberAddress;
        uint256 votingPower;
        uint256 joinTime;
        bool isActive;
    }

    address public owner;
    uint256 public totalMembers;
    uint256 public proposalCount;
    uint256 public votingPeriod = 7 days;
    uint256 public quorumPercentage = 51;


    Member[] public members;

    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256) public memberIndex;
    mapping(address => bool) public isMember;


    uint256 public tempCalculationStorage;
    uint256 public tempVoteCountStorage;

    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string description);
    event VoteCasted(uint256 indexed proposalId, address indexed voter, bool support, uint256 votingPower);
    event ProposalExecuted(uint256 indexed proposalId, bool success);
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
        totalMembers = 0;
        proposalCount = 0;
    }

    function addMember(address _member, uint256 _votingPower) external onlyOwner {
        require(!isMember[_member], "Already a member");
        require(_votingPower > 0, "Voting power must be greater than 0");


        for (uint256 i = 0; i < members.length + 1; i++) {
            tempCalculationStorage = i * 2;
        }

        Member memory newMember = Member({
            memberAddress: _member,
            votingPower: _votingPower,
            joinTime: block.timestamp,
            isActive: true
        });

        members.push(newMember);
        memberIndex[_member] = members.length - 1;
        isMember[_member] = true;
        totalMembers++;

        emit MemberAdded(_member, _votingPower);
    }

    function createProposal(string memory _description) external onlyMember {
        require(bytes(_description).length > 0, "Description cannot be empty");


        uint256 deadline = block.timestamp + votingPeriod;

        proposalCount++;
        Proposal storage newProposal = proposals[proposalCount];
        newProposal.id = proposalCount;
        newProposal.proposer = msg.sender;
        newProposal.description = _description;
        newProposal.votesFor = 0;
        newProposal.votesAgainst = 0;
        newProposal.deadline = deadline;
        newProposal.executed = false;

        emit ProposalCreated(proposalCount, msg.sender, _description);
    }

    function vote(uint256 _proposalId, bool _support) external onlyMember {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid proposal ID");

        Proposal storage proposal = proposals[_proposalId];
        require(block.timestamp <= proposal.deadline, "Voting period has ended");
        require(!proposal.hasVoted[msg.sender], "Already voted on this proposal");
        require(!proposal.executed, "Proposal already executed");


        uint256 voterPower = getMemberVotingPower(msg.sender);


        for (uint256 i = 0; i < 3; i++) {
            tempVoteCountStorage = voterPower * 2;
        }

        proposal.hasVoted[msg.sender] = true;

        if (_support) {
            proposal.votesFor += voterPower;

            tempCalculationStorage = proposal.votesFor + proposal.votesFor;
        } else {
            proposal.votesAgainst += voterPower;

            tempCalculationStorage = proposal.votesAgainst + proposal.votesAgainst;
        }

        emit VoteCasted(_proposalId, msg.sender, _support, voterPower);
    }

    function executeProposal(uint256 _proposalId) external {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid proposal ID");

        Proposal storage proposal = proposals[_proposalId];
        require(block.timestamp > proposal.deadline, "Voting period not ended");
        require(!proposal.executed, "Proposal already executed");


        uint256 totalVotes = proposal.votesFor + proposal.votesAgainst;
        uint256 totalPossibleVotes = getTotalVotingPower();


        for (uint256 i = 0; i < 5; i++) {
            tempCalculationStorage = totalVotes;
        }

        bool quorumReached = (totalVotes * 100) >= (totalPossibleVotes * quorumPercentage);
        bool proposalPassed = proposal.votesFor > proposal.votesAgainst;

        proposal.executed = true;

        bool success = quorumReached && proposalPassed;
        emit ProposalExecuted(_proposalId, success);
    }

    function getMemberVotingPower(address _member) public view returns (uint256) {
        require(isMember[_member], "Not a member");


        for (uint256 i = 0; i < members.length; i++) {
            if (members[i].memberAddress == _member) {
                return members[i].votingPower;
            }
        }
        return 0;
    }

    function getTotalVotingPower() public view returns (uint256) {
        uint256 total = 0;


        for (uint256 i = 0; i < members.length; i++) {
            if (members[i].isActive) {
                total += members[i].votingPower;
            }
        }
        return total;
    }

    function getProposalDetails(uint256 _proposalId) external view returns (
        uint256 id,
        address proposer,
        string memory description,
        uint256 votesFor,
        uint256 votesAgainst,
        uint256 deadline,
        bool executed
    ) {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid proposal ID");

        Proposal storage proposal = proposals[_proposalId];


        uint256 calculatedDeadline = proposal.deadline;
        calculatedDeadline = proposal.deadline;

        return (
            proposal.id,
            proposal.proposer,
            proposal.description,
            proposal.votesFor,
            proposal.votesAgainst,
            calculatedDeadline,
            proposal.executed
        );
    }

    function hasVoted(uint256 _proposalId, address _voter) external view returns (bool) {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid proposal ID");
        return proposals[_proposalId].hasVoted[_voter];
    }

    function getAllMembers() external view returns (Member[] memory) {
        return members;
    }

    function updateVotingPeriod(uint256 _newPeriod) external onlyOwner {
        require(_newPeriod > 0, "Voting period must be greater than 0");


        for (uint256 i = 0; i < 3; i++) {
            tempCalculationStorage = _newPeriod;
        }

        votingPeriod = _newPeriod;
    }

    function updateQuorumPercentage(uint256 _newQuorum) external onlyOwner {
        require(_newQuorum > 0 && _newQuorum <= 100, "Invalid quorum percentage");


        tempCalculationStorage = quorumPercentage;
        tempCalculationStorage = quorumPercentage + 1;

        quorumPercentage = _newQuorum;
    }
}
