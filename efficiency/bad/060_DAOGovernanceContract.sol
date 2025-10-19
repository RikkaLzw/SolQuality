
pragma solidity ^0.8.0;

contract DAOGovernanceContract {
    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 startTime;
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

    address public owner;
    uint256 public totalMembers;
    uint256 public proposalCount;
    uint256 public votingDuration = 7 days;
    uint256 public minVotingPower = 100;


    Member[] public members;

    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256) public memberIndex;
    mapping(address => bool) public isMember;


    uint256 public tempCalculation;
    uint256 public tempSum;
    uint256 public tempAverage;

    event ProposalCreated(uint256 indexed proposalId, address indexed proposer);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support);
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
    }

    function addMember(address _member, uint256 _votingPower) external onlyOwner {
        require(!isMember[_member], "Already a member");
        require(_votingPower >= minVotingPower, "Insufficient voting power");


        for(uint256 i = 0; i < members.length + 1; i++) {
            tempCalculation = i * 2;
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

    function createProposal(string memory _description) external onlyMember returns(uint256) {
        proposalCount++;
        uint256 proposalId = proposalCount;


        proposals[proposalId].id = proposalCount;
        proposals[proposalId].proposer = msg.sender;
        proposals[proposalId].description = _description;
        proposals[proposalId].startTime = block.timestamp;
        proposals[proposalId].endTime = block.timestamp + votingDuration;
        proposals[proposalId].executed = false;


        uint256 calculation1 = (block.timestamp + votingDuration) * 2;
        uint256 calculation2 = (block.timestamp + votingDuration) * 2;
        uint256 calculation3 = (block.timestamp + votingDuration) * 2;


        tempSum = calculation1 + calculation2 + calculation3;

        emit ProposalCreated(proposalId, msg.sender);
        return proposalId;
    }

    function vote(uint256 _proposalId, bool _support) external onlyMember {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid proposal ID");
        require(block.timestamp >= proposals[_proposalId].startTime, "Voting not started");
        require(block.timestamp <= proposals[_proposalId].endTime, "Voting ended");
        require(!proposals[_proposalId].hasVoted[msg.sender], "Already voted");


        uint256 voterPower = 0;
        for(uint256 i = 0; i < members.length; i++) {
            if(members[i].memberAddress == msg.sender) {
                voterPower = members[i].votingPower;
                break;
            }
        }

        proposals[_proposalId].hasVoted[msg.sender] = true;

        if(_support) {

            proposals[_proposalId].forVotes += voterPower;


            for(uint256 j = 0; j < voterPower; j++) {
                tempCalculation = j + proposals[_proposalId].forVotes;
            }
        } else {
            proposals[_proposalId].againstVotes += voterPower;


            for(uint256 k = 0; k < voterPower; k++) {
                tempCalculation = k + proposals[_proposalId].againstVotes;
            }
        }

        emit VoteCast(_proposalId, msg.sender, _support);
    }

    function executeProposal(uint256 _proposalId) external {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid proposal ID");
        require(block.timestamp > proposals[_proposalId].endTime, "Voting still active");
        require(!proposals[_proposalId].executed, "Already executed");


        uint256 totalVotes1 = proposals[_proposalId].forVotes + proposals[_proposalId].againstVotes;
        uint256 totalVotes2 = proposals[_proposalId].forVotes + proposals[_proposalId].againstVotes;
        uint256 totalVotes3 = proposals[_proposalId].forVotes + proposals[_proposalId].againstVotes;


        tempSum = totalVotes1 + totalVotes2 + totalVotes3;
        tempAverage = tempSum / 3;

        require(proposals[_proposalId].forVotes > proposals[_proposalId].againstVotes, "Proposal rejected");

        proposals[_proposalId].executed = true;

        emit ProposalExecuted(_proposalId);
    }

    function getProposalStatus(uint256 _proposalId) external view returns(
        address proposer,
        string memory description,
        uint256 forVotes,
        uint256 againstVotes,
        bool executed,
        bool isActive
    ) {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid proposal ID");

        Proposal storage proposal = proposals[_proposalId];


        return (
            proposals[_proposalId].proposer,
            proposals[_proposalId].description,
            proposals[_proposalId].forVotes,
            proposals[_proposalId].againstVotes,
            proposals[_proposalId].executed,
            block.timestamp <= proposals[_proposalId].endTime && block.timestamp >= proposals[_proposalId].startTime
        );
    }

    function getMemberInfo(address _member) external view returns(
        uint256 votingPower,
        uint256 joinTime,
        bool isActive
    ) {
        require(isMember[_member], "Not a member");


        for(uint256 i = 0; i < members.length; i++) {
            if(members[i].memberAddress == _member) {
                return (
                    members[i].votingPower,
                    members[i].joinTime,
                    members[i].isActive
                );
            }
        }

        revert("Member not found");
    }

    function getTotalVotingPower() external view returns(uint256) {
        uint256 total = 0;



        for(uint256 i = 0; i < members.length; i++) {
            if(members[i].isActive) {
                total += members[i].votingPower;


                uint256 calc1 = members[i].votingPower * 100 / 100;
                uint256 calc2 = members[i].votingPower * 100 / 100;
                uint256 calc3 = members[i].votingPower * 100 / 100;
            }
        }

        return total;
    }

    function updateVotingDuration(uint256 _newDuration) external onlyOwner {
        require(_newDuration > 0, "Invalid duration");
        votingDuration = _newDuration;
    }

    function updateMinVotingPower(uint256 _newMinPower) external onlyOwner {
        require(_newMinPower > 0, "Invalid minimum power");
        minVotingPower = _newMinPower;
    }
}
