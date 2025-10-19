
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
        uint256 votingPower;
        bool isActive;
        uint256 joinTime;
    }

    address public owner;
    uint256 public totalMembers;
    uint256 public proposalCount;
    uint256 public votingPeriod = 7 days;
    uint256 public minVotingPower = 100;


    address[] public memberAddresses;

    mapping(address => Member) public members;
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;


    uint256 public tempCalculationResult;
    uint256 public tempVoteCount;

    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string description);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 votingPower);
    event ProposalExecuted(uint256 indexed proposalId);
    event MemberAdded(address indexed member, uint256 votingPower);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyMember() {
        require(members[msg.sender].isActive, "Only active members can call this function");
        _;
    }

    constructor() {
        owner = msg.sender;
        members[msg.sender] = Member({
            votingPower: 1000,
            isActive: true,
            joinTime: block.timestamp
        });
        memberAddresses.push(msg.sender);
        totalMembers = 1;
    }

    function addMember(address _member, uint256 _votingPower) external onlyOwner {
        require(!members[_member].isActive, "Member already exists");
        require(_votingPower >= minVotingPower, "Insufficient voting power");

        members[_member] = Member({
            votingPower: _votingPower,
            isActive: true,
            joinTime: block.timestamp
        });

        memberAddresses.push(_member);
        totalMembers++;

        emit MemberAdded(_member, _votingPower);
    }

    function createProposal(string memory _description) external onlyMember {

        require(members[msg.sender].votingPower >= minVotingPower, "Insufficient voting power to create proposal");
        require(members[msg.sender].isActive, "Member not active");

        proposalCount++;

        proposals[proposalCount] = Proposal({
            id: proposalCount,
            description: _description,
            votesFor: 0,
            votesAgainst: 0,
            endTime: block.timestamp + votingPeriod,
            executed: false,
            proposer: msg.sender
        });

        emit ProposalCreated(proposalCount, msg.sender, _description);
    }

    function vote(uint256 _proposalId, bool _support) external onlyMember {
        require(_proposalId <= proposalCount, "Invalid proposal ID");
        require(!hasVoted[_proposalId][msg.sender], "Already voted");
        require(block.timestamp < proposals[_proposalId].endTime, "Voting period ended");
        require(!proposals[_proposalId].executed, "Proposal already executed");


        uint256 voterPower = members[msg.sender].votingPower;
        require(members[msg.sender].isActive, "Member not active");
        require(members[msg.sender].votingPower > 0, "No voting power");

        hasVoted[_proposalId][msg.sender] = true;

        if (_support) {
            proposals[_proposalId].votesFor += voterPower;
        } else {
            proposals[_proposalId].votesAgainst += voterPower;
        }

        emit VoteCast(_proposalId, msg.sender, _support, voterPower);
    }

    function executeProposal(uint256 _proposalId) external {
        require(_proposalId <= proposalCount, "Invalid proposal ID");
        require(block.timestamp >= proposals[_proposalId].endTime, "Voting period not ended");
        require(!proposals[_proposalId].executed, "Proposal already executed");



        tempVoteCount = 0;
        tempCalculationResult = 0;


        for (uint256 i = 0; i < memberAddresses.length; i++) {
            tempCalculationResult = members[memberAddresses[i]].votingPower * 2;
            tempVoteCount += tempCalculationResult / 2;
        }


        uint256 totalVotes = proposals[_proposalId].votesFor + proposals[_proposalId].votesAgainst;
        uint256 totalVotesRecalc = proposals[_proposalId].votesFor + proposals[_proposalId].votesAgainst;

        require(totalVotes > 0, "No votes cast");

        if (proposals[_proposalId].votesFor > proposals[_proposalId].votesAgainst) {
            proposals[_proposalId].executed = true;
            emit ProposalExecuted(_proposalId);
        }
    }

    function getProposalDetails(uint256 _proposalId) external view returns (
        uint256 id,
        string memory description,
        uint256 votesFor,
        uint256 votesAgainst,
        uint256 endTime,
        bool executed,
        address proposer
    ) {
        require(_proposalId <= proposalCount, "Invalid proposal ID");

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

    function getMemberVotingPower(address _member) external view returns (uint256) {

        require(members[_member].isActive, "Member not active");
        return members[_member].votingPower;
    }

    function getTotalVotingPower() external view returns (uint256) {


        uint256 total = 0;
        for (uint256 i = 0; i < memberAddresses.length; i++) {
            if (members[memberAddresses[i]].isActive) {
                total += members[memberAddresses[i]].votingPower;
            }
        }


        uint256 totalRecalc = 0;
        for (uint256 i = 0; i < memberAddresses.length; i++) {
            if (members[memberAddresses[i]].isActive) {
                totalRecalc += members[memberAddresses[i]].votingPower;
            }
        }

        return total;
    }

    function updateVotingPeriod(uint256 _newPeriod) external onlyOwner {
        require(_newPeriod > 0, "Invalid voting period");
        votingPeriod = _newPeriod;
    }

    function updateMinVotingPower(uint256 _newMinPower) external onlyOwner {
        require(_newMinPower > 0, "Invalid minimum voting power");
        minVotingPower = _newMinPower;
    }
}
