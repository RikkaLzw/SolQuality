
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DAOGovernanceContract is ReentrancyGuard, Ownable {
    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        mapping(address => bool) hasVoted;
        mapping(address => uint256) voterWeight;
    }

    struct Member {
        bool isActive;
        uint256 votingPower;
        uint256 joinTime;
        uint256 lastActivityTime;
    }

    IERC20 public immutable governanceToken;


    uint256 public proposalCount;
    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant MIN_VOTING_POWER = 1000 * 10**18;
    uint256 public constant QUORUM_PERCENTAGE = 20;


    struct ProposalCore {
        address proposer;
        uint32 startTime;
        uint32 endTime;
        bool executed;
        uint8 status;
    }

    mapping(uint256 => ProposalCore) public proposals;
    mapping(uint256 => string) public proposalDescriptions;
    mapping(uint256 => uint256) public proposalVotesFor;
    mapping(uint256 => uint256) public proposalVotesAgainst;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(uint256 => mapping(address => uint256)) public voterWeights;

    mapping(address => Member) public members;
    address[] public memberList;


    uint256 private totalVotingPower;
    uint256 private activeMemberCount;

    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string description);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId, bool passed);
    event MemberAdded(address indexed member, uint256 votingPower);
    event MemberRemoved(address indexed member);

    modifier onlyMember() {
        require(members[msg.sender].isActive, "Not an active member");
        _;
    }

    modifier validProposal(uint256 proposalId) {
        require(proposalId > 0 && proposalId <= proposalCount, "Invalid proposal ID");
        _;
    }

    constructor(address _governanceToken) {
        governanceToken = IERC20(_governanceToken);
        totalVotingPower = 0;
        activeMemberCount = 0;
    }

    function addMember(address member, uint256 votingPower) external onlyOwner {
        require(!members[member].isActive, "Already a member");
        require(votingPower >= MIN_VOTING_POWER, "Insufficient voting power");

        members[member] = Member({
            isActive: true,
            votingPower: votingPower,
            joinTime: block.timestamp,
            lastActivityTime: block.timestamp
        });

        memberList.push(member);


        totalVotingPower += votingPower;
        activeMemberCount++;

        emit MemberAdded(member, votingPower);
    }

    function removeMember(address member) external onlyOwner {
        require(members[member].isActive, "Not an active member");


        totalVotingPower -= members[member].votingPower;
        activeMemberCount--;

        members[member].isActive = false;


        uint256 length = memberList.length;
        for (uint256 i = 0; i < length;) {
            if (memberList[i] == member) {
                memberList[i] = memberList[length - 1];
                memberList.pop();
                break;
            }
            unchecked { ++i; }
        }

        emit MemberRemoved(member);
    }

    function createProposal(string calldata description) external onlyMember returns (uint256) {
        require(bytes(description).length > 0, "Empty description");


        members[msg.sender].lastActivityTime = block.timestamp;

        uint256 proposalId = ++proposalCount;
        uint32 startTime = uint32(block.timestamp);
        uint32 endTime = uint32(block.timestamp + VOTING_PERIOD);

        proposals[proposalId] = ProposalCore({
            proposer: msg.sender,
            startTime: startTime,
            endTime: endTime,
            executed: false,
            status: 1
        });

        proposalDescriptions[proposalId] = description;

        emit ProposalCreated(proposalId, msg.sender, description);
        return proposalId;
    }

    function vote(uint256 proposalId, bool support) external onlyMember validProposal(proposalId) nonReentrant {
        ProposalCore memory proposal = proposals[proposalId];

        require(block.timestamp >= proposal.startTime, "Voting not started");
        require(block.timestamp <= proposal.endTime, "Voting ended");
        require(!hasVoted[proposalId][msg.sender], "Already voted");
        require(proposal.status == 1, "Proposal not active");

        Member memory member = members[msg.sender];
        uint256 weight = member.votingPower;

        hasVoted[proposalId][msg.sender] = true;
        voterWeights[proposalId][msg.sender] = weight;

        if (support) {
            proposalVotesFor[proposalId] += weight;
        } else {
            proposalVotesAgainst[proposalId] += weight;
        }


        members[msg.sender].lastActivityTime = block.timestamp;

        emit VoteCast(proposalId, msg.sender, support, weight);
    }

    function executeProposal(uint256 proposalId) external validProposal(proposalId) nonReentrant {
        ProposalCore storage proposal = proposals[proposalId];

        require(block.timestamp > proposal.endTime, "Voting still active");
        require(!proposal.executed, "Already executed");

        uint256 votesFor = proposalVotesFor[proposalId];
        uint256 votesAgainst = proposalVotesAgainst[proposalId];
        uint256 totalVotes = votesFor + votesAgainst;
        uint256 quorum = (totalVotingPower * QUORUM_PERCENTAGE) / 100;

        bool passed = totalVotes >= quorum && votesFor > votesAgainst;

        proposal.executed = true;
        proposal.status = passed ? 2 : 3;

        emit ProposalExecuted(proposalId, passed);
    }

    function getProposalDetails(uint256 proposalId) external view validProposal(proposalId)
        returns (
            address proposer,
            string memory description,
            uint256 votesFor,
            uint256 votesAgainst,
            uint256 startTime,
            uint256 endTime,
            bool executed,
            uint8 status
        )
    {
        ProposalCore memory proposal = proposals[proposalId];

        return (
            proposal.proposer,
            proposalDescriptions[proposalId],
            proposalVotesFor[proposalId],
            proposalVotesAgainst[proposalId],
            proposal.startTime,
            proposal.endTime,
            proposal.executed,
            proposal.status
        );
    }

    function getMemberInfo(address member) external view
        returns (bool isActive, uint256 votingPower, uint256 joinTime, uint256 lastActivityTime)
    {
        Member memory memberInfo = members[member];
        return (memberInfo.isActive, memberInfo.votingPower, memberInfo.joinTime, memberInfo.lastActivityTime);
    }

    function getDAOStats() external view
        returns (uint256 totalMembers, uint256 totalVoting, uint256 activeProposals)
    {
        uint256 activeCount = 0;
        uint256 currentTime = block.timestamp;


        for (uint256 i = 1; i <= proposalCount;) {
            ProposalCore memory proposal = proposals[i];
            if (proposal.status == 1 && currentTime <= proposal.endTime) {
                activeCount++;
            }
            unchecked { ++i; }
        }

        return (activeMemberCount, totalVotingPower, activeCount);
    }

    function getMemberList() external view returns (address[] memory) {
        return memberList;
    }

    function hasUserVoted(uint256 proposalId, address user) external view returns (bool) {
        return hasVoted[proposalId][user];
    }

    function getUserVoteWeight(uint256 proposalId, address user) external view returns (uint256) {
        return voterWeights[proposalId][user];
    }


    function emergencyPause() external onlyOwner {

    }

    function updateVotingPeriod(uint256 newPeriod) external onlyOwner {
        require(newPeriod >= 1 days && newPeriod <= 30 days, "Invalid voting period");

    }
}
